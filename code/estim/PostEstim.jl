module PostEstim

export MonteCarloIncome
using TypeDef, Helper, Estim, Gmm, GMMInterface, Optim, UserFileIO
using Printf, DelimitedFiles, Random, Distributions, LinearAlgebra

function exportδ(
  θ₂,
  dat  ::datType,
  dim  ::dimType,
  fxp  ::fxpType,
  mat  ::matType,
  indx ::indxType,
  pred ::predType,
  diags::diagsType,
  fid  ::IOStream)

  setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
  fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
  unpackStackedArray!(fxp.eδ1d, fxp.eδ, dim.market, indx.mkt)
  for i=1:dim.obs
    @printf(fid,", %28.15f",fxp.eδ1d[i])
  end
  @printf(fid,"\n")

end

function MonteCarloIncome(
  model  ::Int64,
  mcid   ::Int64,
  nRep   ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  outp   ::Bool;
  lowB   ::Bool=true,
  simEmp ::Bool=false,
  nPerson::Int64=200,
  stage  ::Int64=0,
  mcid1st::Int64=0,
  update ::Bool=true,
  fileName="paramDraws.csv")

  # Import
  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp)

  pathName = string("out/",impF,"/m",model,"s",stage,iv,nPerson)
  imp = readdlm(string(pathName,"/gmmStage2.csv"),',')
  θ̂   = convert(Vector{Float64},imp[mcid,2:(end-2)])
  θ̂₁  = θ̂[dim.θ₂+1:end]
  θ̂₂  = θ̂[1:dim.θ₂]

  seθ̂,θ̂₁,covθ̂ = stdError(θ̂₂,model,stage,iv,nPerson,impF,update,
                         dat,dim,fxp,mat,set,indx,pred,diags,mcid1st)

  cholθ̂ = cholesky(Hermitian(covθ̂))

  # Import bounded income draws (for MC sim. Turn off for income prediction)
  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp;lowBound=lowB)

  # Monte Carlo
  rng = MersenneTwister(1234)
  inc = zeros(dim.brand,dim.prepost,nRep)
  fid = open(string(pathName,"/",fileName),"w")
  for r=1:nRep
    tic = time()
    θ₁,θ₂ = sampleθ(θ̂,cholθ̂,dat,dim,fxp,mat,indx,pred,diags,rng,fid,outp)
    y = simulateIncome(θ₁,θ₂,dat,dim,fxp,mat,indx,pred,rng)
    @. inc[:,:,r] = y
    @printf("Bootstrap %d complete in %.1f sec.\n",r,time()-tic)
  end
  close(fid)
  yAvg = mean(inc,dims=3)
  y025 = zeros(dim.brand,dim.prepost)
  y975 = zeros(dim.brand,dim.prepost)

  for k=1:dim.prepost
    for j=1:dim.brand
      y025[j,k] = quantile(inc[j,k,:],0.025)
      y975[j,k] = quantile(inc[j,k,:],0.975)
    end
  end
  @printf("Average Income by Subscribers of Product Lines\n")
  display("text/plain",yAvg)
  return yAvg, y025, y975
end

function sampleθ(
  θ̂::Vector{Float64},
  cholθ̂,
  dat  ::datType,
  dim  ::dimType,
  fxp  ::fxpType,
  mat  ::matType,
  indx ::indxType,
  pred ::predType,
  diags::diagsType,
  rng  ::MersenneTwister,
  fid  ::IOStream,
  outp ::Bool=false)

  θ  = θ̂ + cholθ̂.L * randn(rng,dim.θ)
  θ₁ = θ[dim.θ₂+1:end]
  θ₂ = θ[1:dim.θ₂]
  while (minimum(θ₂[1:2])<=0)
    θ  .= θ̂ + cholθ̂.L * randn(rng,dim.θ)
    θ₁ .= θ[dim.θ₂+1:end]
    θ₂ .= θ[1:dim.θ₂]
    σₐ  = θ₂[1]
    if (minimum(θ₂[1:2])<=0)
      @printf("\nMonte Carlo draw rejected: %14.4f %14.4f \n",θ₂[1],θ₂[2])
    end
  end
  # Export parameters to csv file
  if outp==true # export θ & δ to csv file
    @printf(fid,"%22.15f",θ₂[1])
    for k=2:dim.θ₂
      @printf(fid,", %22.15f",θ₂[k])
    end
    for k=1:dim.θ₁
      @printf(fid,", %22.15f",θ₁[k])
    end
    exportδ(θ₂,dat,dim,fxp,mat,indx,pred,diags,fid)
  end

  return θ₁,θ₂
end

function simulateIncome(
  θ₁::Vector{Float64},
  θ₂::Vector{Float64},
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  mat::matType,
  indx::indxType,
  pred::predType,
  rng::MersenneTwister)

  yMean  = zeros(dim.brand,dim.prepost)
  yCount = zeros(dim.brand,dim.prepost)

  μ = 0; σ = 1; ξ = 0;
  randϵ = GeneralizedExtremeValue(μ, σ, ξ)

  @inbounds for t=1:dim.market
    eδ = fxp.eδ[t]
    eμ = fxp.eμ[t]
    Dᵢ = view(mat.Dᵢ[t],1,1,:)
    num     = zeros(dim.prodt[t])
    mask    = view(indx.mkt,:,t)
    brand   = dat.brand[mask]
    prepost = dat.prepost[mask]
    util = zeros(dim.prodt[t],dim.person)
    for i=1:dim.person
      for j=1:dim.prodt[t]
        util[j,i] = log(eδ[j]*eμ[j,i])
      end
    end

    for i=1:dim.person
      μ₀ = log(pred.eμ₀[t][i])
      for r=1:100
        for j=1:dim.prodt[t]
          num[j] = util[j,i] + rand(randϵ)
        end
        jmax = argmax(num)
        if num[jmax] > μ₀
          yMean[brand[jmax],prepost[jmax]] += 100/Dᵢ[i]
          yCount[brand[jmax],prepost[jmax]] += 1
        end
      end
    end # end of i loop
  end # end of t loop
  yCount[yCount.==0] .= 1
  @. yMean = yMean / yCount
  return yMean
end

end
