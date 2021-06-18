module Estim

export fixPoint!, setupMu!, stdError, share!, jacobDelta!, linearIV!, linearIV
export gmmWeight, optimIV!, prediction!, updateGMMweight!
using TypeDef, Optim, Helper
using Printf, LinearAlgebra
using LoopVectorization

function fixPoint!(eδ::Vector{Vector{Float64}}, ∂δ∂θ::Vector{Matrix{Float64}},
  eμ::Vector{Matrix{Float64}}, dat::datType, dim::dimType, mat::matType,
  indx::indxType, pred::predType, diags::diagsType, θ₂::Vector{Float64})

  for t=1:dim.market
    if any(isnan,eδ[t])
      return
    end
    eδt  = eδ[t]
    eμt  = eμ[t]
    numProdt = dim.prodt[t]
    ms1 = pred.ms[t]  # ms1 = zeros(Float64,numProdt,)
    num = pred.num[t] # num = Array{Float64,1}(numProdt)
    eμ₀ = pred.eμ₀[t]
    ms0 = mat.ms[t] #view(mat.ms,mask)

    iter::Int64 = 0; dist::Float64 = 1.0
    while (dist>diags.tolBLP) & (iter<1e5)
      share!(ms1,num,eμ₀,eδt,eμt,numProdt,dim)
      dist = 0.0
      for j=1:numProdt
        Δ = ms0[j]/ms1[j]
        dist = max(dist, abs(log(Δ)))
        eδt[j] *= Δ
      end
      iter += 1
    end
    # if iter>=1e5
    #   eδt[:] = NaN
    #   println("Fixed point iteration exceeding the limit.")
    #   return
    # end
    jacobDelta!(∂δ∂θ[t],pred.∂S∂θ[t],mat.dμdL[t],eδt,eμt,num,eμ₀,
                pred.s[t],ms1,pred.mss[t],numProdt,dim,indx,θ₂)
    diags.iter += iter
    #@printf "Converged in %d iterations at markt %d\n" iter t
  end
  diags.iterBLP += 1
end

function jacobDelta!(
  ∂δ∂θ::Matrix{Float64},
  ∂S∂θ::Matrix{Float64},
  dμdL::Array{Float64,3},
  eδt::Array{Float64,1},
  eμt::Matrix{Float64},
  num::Vector{Float64},
  eμ₀::Vector{Float64},
  s::Vector{Float64},
  ms::Vector{Float64},
  mss::Matrix{Float64},
  numProdt::Int64,
  dim::dimType,
  indx::indxType,
  θ₂::Vector{Float64})

  fill!(mss,0.0)
  fill!(∂S∂θ,0.0)
  for i=1:dim.person
    den = eμ₀[i]
    for j=1:numProdt
      num[j] = eδt[j]*eμt[j,i]
      den += num[j]
    end
    for j=1:numProdt
      s[j] = num[j]/den
    end
    for j=1:numProdt
      for k=1:numProdt
        mss[k,j] += s[j]*s[k]
      end
    end
    for l=1:dim.θ₂
      dμdLᵢ = view(dμdL,:,l,i)
      ΣdμdLS = 0.0
      for k=1:numProdt
        ΣdμdLS += dμdLᵢ[k]*s[k]
      end
      for j=1:numProdt
        ∂S∂θ[j,l] += s[j]*(dμdLᵢ[j]-ΣdμdLS)
      end
    end
  end
  ∂S∂θ /= dim.person
  ∂S∂δ = diagm(0=>ms) - mss/dim.person
  # if θ₂[1]>0
  #   ∂S∂θ[:] /= 2*sqrt(θ₂)
  # end
  for l in indx.expθ
    ∂S∂θ[:,l] *= exp(θ₂[l])
  end
  ∂δ∂θ[:] = -inv(∂S∂δ)*∂S∂θ

end

function share!(ms::Vector{Float64}, num::Vector{Float64}, eμ₀::Vector{Float64},
  eδt::Array{Float64,1}, eμt::Matrix{Float64},
  numProdt::Int64, dim::dimType)

  fill!(ms,0.0)
  @inbounds for i=1:dim.person
    den = eμ₀[i]
    @avx for j=1:numProdt
      num[j] = eδt[j]*eμt[j,i]
      den += num[j]
    end
    for j=1:numProdt
      ms[j] += num[j]/den/dim.person
    end
  end
  # @inbounds for j=1:numProdt
  #   ms[j] /= dim.person
  # end
end

function setupMu!(eμ::Array{Matrix{Float64},1}, eμ₀::Array{Vector{Float64},1},
  adj::Array{Vector{Float64},1},
  θ₂::Vector{Float64}, dim::dimType, indx::indxType, L::Matrix{Float64},
  Lν::Matrix{Float64}, Xᵢ::Matrix{Float64}, ν::Matrix{Float64})

  for k=1:dim.θ₂
    i = indx.L[k,1]
    j = indx.L[k,2]
    L[i,j] = θ₂[k]
  end
  Lν[:] = L*ν

  for t=1:dim.market
    eμt = eμ[t]
    mask = view(indx.mkt,:,t)
    Xᵢt = view(Xᵢ,mask,:)
    for i=1:dim.person
      adj[t][i] = 0.0
      for j=1:dim.prodt[t]
        μ::Float64 = 0.0
        for k=1:dim.Xᵢ
          μ += Xᵢt[j,k]*Lν[k,i]
        end
        (μ > max(adj[t][i],6.91)) ? (adj[t][i]=μ) : nothing
        eμt[j,i] = μ
      end # end of j loop
      for j=1:dim.prodt[t]
        eμt[j,i] = exp(eμt[j,i]-adj[t][i])
      end
      eμ₀[t][i] = exp(-adj[t][i])
    end # end of i loop
  end
end
function setupMu!(
  eμ::Array{Matrix{Float64},1},
  eμ₀::Array{Vector{Float64},1},
  adj::Array{Vector{Float64},1},
  θ₂::Vector{Float64},
  Xᵢ,
  Dᵢ,
  νᵢ,
  dim::dimType,
  indx::indxType)

  θ̃₂ = copy(θ₂)
  for k in indx.expθ
    θ̃₂[k] = exp(θ₂[k])
  end
  for t=1:dim.market
    eμt = eμ[t]
    mask = view(indx.mkt,:,t)
    Xᵢt = view(Xᵢ,mask,:)
    for i=1:dim.person
      adj[t][i] = 0.0
      for j=1:dim.prodt[t]
        μ = 0.0
        for k=1:dim.Dᵢ
          μ += θ̃₂[k] * Xᵢt[j,k] * Dᵢ[t][k,j,i]
        end
        for k=(dim.Dᵢ+1):(dim.Dᵢ+dim.νᵢ)
          μ += θ̃₂[k] * Xᵢt[j,k] * νᵢ[k-dim.Dᵢ,i]
        end
        (μ < min(adj[t][i],0.0)) ? (adj[t][i]=μ) : nothing
        eμt[j,i] = μ
      end # end of j loop
      for j=1:dim.prodt[t]
        eμt[j,i] = exp(eμt[j,i]-adj[t][i])
      end
      eμ₀[t][i] = exp(-adj[t][i])
    end # end of i loop
  end
end

function stdError(
  θ₂     ::Vector{Float64},
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  nPerson::Int64,
  impF   ::String,
  update ::Bool,
  dat    ::datType,
  dim    ::dimType,
  fxp    ::fxpType,
  mat    ::matType,
  set    ::setType,
  indx   ::indxType,
  pred   ::predType,
  diags  ::diagsType,
  mcid1st::Int64=0)

  if iv=="opt"
    if (impF=="optIVtest") | (impF=="optIV1") | (impF=="optIV2")
      θ̂₂ = importθ̂₂(model,stage,mcid1st,iv,nPerson,impF,dim,update)
      setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ̂₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
      fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ̂₂)
      θ₁ = optimIV!(mat,θ̂₂,dat,dim,fxp,indx,pred,diags)
      println("θ₁: ",round.(θ₁,digits=4))
      setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
      fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
    else
      setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
      fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
      optimIV!(mat,θ₂,dat,dim,fxp,indx,pred,diags)
    end
  else
    setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
    fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
  end
  θ₁ = linearIV!(mat.ξ, fxp.eδ,fxp.eδ1d, dim,mat,indx;output=2)

  ∂δ∂θ = unpackStackedArray(fxp.∂δ∂θ,dim.obs,dim.θ₂,dim.market,indx.mkt)
  # ∂m∂θ = view(mat.Z,mat.mask,:)'*view([∂δ∂θ -mat.X],mat.mask,:)
  ∂m∂θ = mat.Z'*[∂δ∂θ -mat.X]
  invPhi = gmmWeight(mat,3,dat,dim,set,indx)
  covθ = inv(∂m∂θ'*invPhi*∂m∂θ)
  varθ = diag(covθ)
  seθ = try
    sqrt.(varθ)
  catch
    sqrt.(complex.(varθ))
  end
  for k=1:dim.θ₂
    if imag(seθ[k])!=0
      seθ[k] = NaN
    end
  end
  seθ = real(seθ)

  return seθ, θ₁, covθ
end

function linearIV!(ξ::Matrix{Float64},
  eδ::Vector{Vector{Float64}}, eδ1d::Vector{Float64},
  dim::dimType, mat::matType, indx::indxType; output::Int64=1)

  unpackStackedArray!(eδ1d, eδ, dim.market, indx.mkt)
  δ = log.(eδ1d)
  θ₁ = mat.XZPhiZXZ*δ
  if output==1
    return θ₁
  elseif output==2
    mat.ξ[:] = δ - mat.X*θ₁
    return θ₁
  elseif output==3
    mat.ξ[:] = δ - mat.X*θ₁
    return
  else
    error("Invalid output in linearIV()")
  end
end

function linearIV(
  eδ  ::Vector{Vector{Float64}},
  eδ1d::Vector{Float64},
  X   ::Matrix{Float64},
  Z   ::Matrix{Float64},
  dim ::dimType,
  indx::indxType)

  unpackStackedArray!(eδ1d, eδ, dim.market, indx.mkt)
  δ = log.(eδ1d)
  XZ = X'*Z
  invPhi = inv(Z'*Z)
  XZPhiZXZ = (XZ*invPhi*XZ')\(XZ*invPhi*Z')
  θ₁ = XZPhiZXZ*δ
  return θ₁
end

function gmmWeight(mat::matType, flag::Int64,
  dat::datType, dim::dimType, set::setType, indx::indxType)

  ξ = mat.ξ[:,1]
  nZ = size(mat.Z,2)
  if flag==1
    Phi = mat.Z'*diagm(0=>ξ.^2)*mat.Z
  elseif flag==3
    Phi = zeros(Float64,nZ,nZ)
    for gid=1:dim.region
      g = set.region[gid]
      for jid=1:dim.product
        b = set.product[jid,1]
        p = set.product[jid,2]
        mask = (dat.region.==g) .& (dat.brand.==b) .& (dat.prepost.==p)
        id   = findall(mask)
        for j=1:length(id)
          i   = id[j]
          z   = view(mat.Z,i,:)
          Phi = Phi + (z*z')*ξ[i]*ξ[i]
          iLag = findall(mask .& (dat.qtr.==dat.qtr[i]-1))
          if length(iLag)==1
            iL = iLag[1]
            zl = view(mat.Z,iL,:)
            z0zl = z*zl'
            Phi = Phi + 0.5*(z0zl + z0zl')*ξ[i]*ξ[iL]
          elseif length(iLag)>0
            error("Multiple lag obs at Region: %d, Brand: %d, Prepost: %d",g,b,p)
          end
        end # end of j
      end # end of jid
    end # end of gid
  end # end of if

  # Replace matrices
  return inv(Phi)
end

function optimIV!(
  mat::matType,
  θ̂₂::Vector{Float64},
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  indx::indxType,
  pred::predType,
  diags::diagsType)

  # θ̂₁ from regressing δ on Z = [p̂,Xexo]
  # predict ŝ from σ̂,p̂
  # Invert ŝ to obtain δ̂(ŝ)
  # Z = [∂δ̂∂σ̂,Xexo]
  # ξ = δ - δ̂(Z,θ̂), θ̂₁ from Z
  θ̂₁ = linearIV(fxp.eδ,fxp.eδ1d, mat.X,[-mat.p̂ mat.Xexo],dim,indx)
  setupMu!(fxp.eμ̂,pred.eμ₀,pred.adj, θ̂₂,mat.X̂ᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)

  # E[∂δ∂θ|Z]
  iter = 0
  dist = 1.0
  while (dist>diags.tolOptIV) & (iter<1e5)
    predictions!(fxp.∂δ̂∂θ,fxp.eδ̂, θ̂₁,θ̂₂,fxp.eμ̂, dim,mat,indx,pred;intNum=1)
    unpackStackedArray!(mat.∂δ̂∂θ,fxp.∂δ̂∂θ,dim.market,indx.mkt)
    updateIVmatrix!(mat)
    θ₁ = linearIV!(mat.ξ, fxp.eδ,fxp.eδ1d, dim,mat,indx;output=2)
    dist = maximum(abs.(θ̂₁-θ₁))
    #@printf("Iter: %4d alpha: %.4f Dist: %.15f\n",iter,θ₁[1],dist)
    iter += 1
    (rem(iter,1000)==0) ? @printf("Iter: %6d Dist: %.14f\n",iter,dist) : nothing
    # if rem(iter,100)==0
    #   @printf("Iter: %5d Dist: %.14f\n",iter,dist)
    # end
    θ̂₁[:] = copy(θ₁)
  end
  if iter>=1e5
    println("Routine optimIV() failed to converge.")
    fxp.eδ[1][:] = NaN
    return
  end
  return θ̂₁
end

function predictions!(
  ∂δ̂∂θ::Vector{Matrix{Float64}},
  eδ̂::Vector{Vector{Float64}},
  θ̂₁::Vector{Float64},
  θ̂₂::Vector{Float64},
  eμ̂::Vector{Matrix{Float64}},
  dim::dimType,
  mat::matType,
  indx::indxType,
  pred::predType;
  intNum::Int64=1)

  if intNum==1
    for t=1:dim.market
      eδ̂[t] .= exp.(mat.X̂[t]*θ̂₁)
      share!(pred.ms[t],pred.num[t],pred.eμ₀[t],eδ̂[t],eμ̂[t],dim.prodt[t],dim)
      jacobDelta!(∂δ̂∂θ[t],pred.∂S∂θ[t],mat.dμ̂dL[t],eδ̂[t],eμ̂[t],
        pred.num[t],pred.eμ₀[t],pred.s[t],pred.ms[t],pred.mss[t],
        dim.prodt[t],dim,indx,θ̂₂)
    end
  elseif intNum==2
    mat.Lξ .= mat.ξ[indx.idLag,1]
    x = view(mat.Lξ,mat.mask,1)
    y = view(mat.ξ,mat.mask,1)
    ρ = inv(x'*x)*(x'*y)
    @. mat.Eξ[mat.mask,1]  = x*ρ
    for i=1:dim.brand
      mask = view(mat.maskBrand,:,i)
      # mat.Eξ[mask,1] = mean(view(mat.ξ,mask,1))
      # mat.Eξ[mask,1] = mean(view(mat.ξ,.~(mat.mask),1))
      # println(mean(view(mat.ξ,mask,1)))
    end
    @. mat.Eξ[~(mat.mask),1] = mat.ξ[~(mat.mask),1]
    for t=1:dim.market
      mask = view(indx.mkt,:,t)
      eδ̂[t] .= exp.(mat.X̂[t]*θ̂₁ + view(mat.Eξ,mask,1))
      share!(pred.ms[t],pred.num[t],pred.eμ₀[t],eδ̂[t],eμ̂[t],dim.prodt[t],dim)
      jacobDelta!(∂δ̂∂θ[t],pred.∂S∂θ[t],mat.dμ̂dL[t],eδ̂[t],eμ̂[t],
        pred.num[t],pred.eμ₀[t],pred.s[t],pred.ms[t],pred.mss[t],
        dim.prodt[t],dim,indx,θ̂₂)
    end
  end
end

function updateGMMweight!(
  mat::matType,
  θ₂,
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  set::setType,
  indx::indxType,
  pred::predType,
  diags::diagsType)

  setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
  fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
  θ₁ = linearIV!(mat.ξ, fxp.eδ,fxp.eδ1d, dim,mat,indx;output=2)
  XZ = mat.X' * mat.Z
  mat.invPhi   .= gmmWeight(mat,3,dat,dim,set,indx)
  mat.XZPhiZXZ .= (XZ*mat.invPhi*XZ')\(XZ*mat.invPhi*mat.Z')
end

end # end of module
