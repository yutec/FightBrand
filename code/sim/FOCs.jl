module FOCs

export foc_mcost, foc_retail, foc_whsale!, foc_retail!, foc_retailV!
export foc_retailPartial
using TypeDef, Helper, Tools, Compute
using NLsolve, Printf

function foc_whsale!(
  fx,
  wprice0,
  price,
  mcost,
  fail,
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  if any(fail)==true
    @printf("Aborting foc_whsale due to previous failure.\n")
    fx .= 0
    return
  end
  wprice = zeros(dim.product)
  wprice[indx.mvno] = wprice0
  p0 = view(price,indx.anyActive)

  # foc2(x) = foc_retail(x,mcost,wprice,dim,mat,par,sim,indx,mask)
  # Op = nlsolve(foc2,p0,show_trace=:true,autodiff=:finiteforward)

  foc3(f,x) = foc_retail!(f,x,mcost,wprice,dim,mat,par,sim,indx,mask)
  f0 = zeros(sum(indx.anyActive))
  df = OnceDifferentiable(foc3,p0,f0,autodiff=:finiteforward)
  Op = nlsolve(df,p0)
  iter = 1
  while (checkConvg(iter,Op)==false) & (iter<10)
    # @printf("Solving foc_retail failed %d times.\n",iter)
    Op = nlsolve(df,p0+2randn(length(p0)))
    iter += 1
  end
  while (checkConvg(iter,Op)==false) & (iter<15)
    @printf("Solving foc_retail failed %d times.\n",iter)
    Op = nlsolve(df,0.5p0 + 2randn(length(p0)))
    iter += 1
  end
  if checkConvg(iter,Op)==false
    @printf("Failed to solve foc_retail within foc_whsale %d times.\n",iter)
    fx .= 0
    fail .= true
    return
  end

  p = zeros(dim.product)
  p[indx.anyActive] = Op.zero

  markupR,markupW,markupV = getMarkup(p,wprice,mcost)
  demand!(sim,p,dim,mat,par,indx)
  x = passThrough(markupR,markupW,markupV,dim,mat,sim,indx,mask)

  f = zeros(dim.mvno)
  for n=1:3
    Ln = (mat.firm[:,2].==n)
    Lc = (mat.firm[:,2].!=n)
    L0 = mat.mvno[:,n]
    n0 = mat.mvnp[:,n]
    dΠdp = (markupR.*Ln)'*sim.∂D∂p + (markupW.*L0)'*sim.∂D∂p
    f[n0] = sim.D[L0] + (dΠdp[:,Lc]*x[Lc,n0])'
  end
  fx .= f[indx.anyActive[mask.mvno]]
end

function foc_mcost(
  mcostinc,
  mcostfree,
  p::Vector{Float64},
  wprice::Vector{Float64},
  dim::dimType,
  mat::matType,
  par::parType,
  sim::simType,
  indx::indxType,
  mask::maskType)

  mcost = mergeMcosts(mcostinc,mcostfree,dim,indx,mask)
  markupR,markupW,markupV = getMarkup(p,wprice,mcost)

  x  = passThrough(markupR,markupW,markupV,dim,mat,sim,indx,mask)
  f  = zeros(dim.product)
  p0 = view(p,indx.anyActive)
  f1 = foc_retail(p0,mcost,wprice,dim,mat,par,sim,indx,mask,"mcost")
  f[mask.mno .& indx.anyActive] = f1

  for n=1:3
    Ln = (mat.firm[:,2].==n)
    Lc = (mat.firm[:,2].!=n)
    L0 = mat.mvno[:,n]
    n0 = mat.mvnp[:,n]
    dΠdp = (markupR.*Ln)' * sim.∂D∂p + (markupW.*L0)' * sim.∂D∂p
    f[L0] = sim.D[L0] + (dΠdp[:,Lc]*x[Lc,n0])'
  end
  return f[indx.anyActive .& .!mask.free]

end

function foc_retail(
  p0,
  mc  ::Vector{Vector{Float64}},
  wp  ::Vector{Float64},
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  opt ::String="retail")

  p = zeros(dim.product)
  p[indx.anyActive] = p0

  demandD1only!(sim,p,dim,mat,par,indx)

  markup1 = p - mc[2]
  markup1[mask.mvno] = wp[mask.mvno] - mc[1][mask.mvno]
  markup2 = p - wp - mc[2]

  Dm1 = (sim.∂D∂p.*mat.host)'*(markup1.*indx.anyActive)
  Dm2 = (sim.∂D∂p.*mat.host)'*(markup2.*indx.anyActive)

  f = zeros(dim.product)
  f[mask.mno] = sim.D[mask.mno] + Dm1[mask.mno]
  if opt=="retail"
    f[mask.mvno] = sim.D[mask.mvno] + Dm2[mask.mvno]
    return f[indx.anyActive]
  elseif opt=="mcost"
    return f[mask.mno .& indx.anyActive]
  end
end

function foc_retail!(
  f   ::Vector{Float64},
  p0  ::Vector{Float64},
  mc  ::Vector{Vector{Float64}},
  wp  ::Vector{Float64},
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  p = zeros(dim.product)
  p[indx.anyActive] = p0

  demandD1only!(sim,p,dim,mat,par,indx)

  idx = findall(indx.anyActive)
  @inbounds for i=1:length(idx)
    j = idx[i]
    Dm1 = 0.0
    Dm2 = 0.0
    for k in idx
      markup1 = (mask.mno[k]) ? p[k]-mc[2][k] : wp[k]-mc[1][k]
      markup2 = p[k] - wp[k] - mc[2][k]
      Dm1 += sim.∂D∂p[k,j] * mat.host[k,j] * markup1
      Dm2 += sim.∂D∂p[k,j] * mat.host[k,j] * markup2
    end
    f[i] = sim.D[j] + Dm1*mask.mno[j] + Dm2*mask.mvno[j]
  end

end

function foc_retailV!(
  f   ::Vector{Float64},
  p0  ::Vector{Float64},
  mc  ::Vector{Vector{Float64}},
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  p = zeros(dim.product)
  p[indx.anyActive] = p0
  demandD1only!(sim,p,dim,mat,par,indx)
  markup1 = p - mc[2]

  Dm1 = (sim.∂D∂p.*mat.host)'*(markup1.*indx.anyActive)
  idx = findall(indx.anyActive)
  for i=1:length(idx)
    j = idx[i]
    f[i] = sim.D[j] + Dm1[j]
  end

  # idx = findall(indx.anyActive)
  # for i=1:length(idx)
  #   j = idx[i]
  #   Dm1 = 0.0
  #   for k=1:dim.product
  #     markup1 = p[k]-mc[k]
  #     Dm1 += sim.∂D∂p[k,j] * mat.host[k,j] * markup1
  #   end
  #   f[i] = sim.D[j] + Dm1
  # end

end

function foc_retailPartial(
  p0  ::Vector{Float64},
  pj  ::Vector{Float64},
  wp  ::Vector{Float64},
  mc  ::Vector{Vector{Float64}},
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  p = copy(pj)
  p[indx.anyActive] = p0

  demandD1only!(sim,p,dim,mat,par,indx)

  idx = findall(indx.anyActive)
  f = zeros(length(idx))
  @inbounds for i=1:length(idx)
    j = idx[i]
    Dm1 = 0.0
    Dm2 = 0.0
    for k in idx
      markup1 = (mask.mno[k]) ? p[k]-mc[2][k] : wp[k]-mc[1][k]
      markup2 = p[k] - wp[k] - mc[2][k]
      Dm1 += sim.∂D∂p[k,j] * mat.host[k,j] * markup1
      Dm2 += sim.∂D∂p[k,j] * mat.host[k,j] * markup2
    end
    f[i] = sim.D[j] + Dm1*mask.mno[j] + Dm2*mask.mvno[j]
  end
  return f
end

end
