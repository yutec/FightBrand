module Tools

export alias, aliasRegion!, setupIndex!, getMarkup, mergeMcosts
export checkConvg, fastFill!, whsaleprice, collectΠ!
using TypeDef
using NLsolve, LoopVectorization

function fastFill!(
  A    ::Matrix{Float64},
  nRow ::Int64,
  nCol ::Int64)

  @avx for j=1:nCol
    for i=1:nRow
      A[i,j] = 0
    end
  end
end

function alias(
  dim::dimType,
  sim::simType,
  optD2::Bool=false)

  s      = sim.s
  num    = sim.num
  D      = sim.D
  ms     = sim.ms
  ∂s∂p   = sim.∂s∂p
  ∂S∂p   = sim.∂S∂p
  ∂D∂p   = sim.∂D∂p

  fill!(ms,0)

  if optD2==true
    ∂²S∂p² = sim.∂²S∂p²
    ∂²D∂p² = sim.∂²D∂p²
    @inbounds for j=1:dim.product
      D[j] = 0
      for i=1:dim.product
        ∂D∂p[i,j] = 0
        for k=1:dim.product
          ∂²D∂p²[k,i,j] = 0
        end
      end
    end
    return s,num,D,ms,∂s∂p,∂S∂p,∂²S∂p²,∂D∂p,∂²D∂p²
  else
    @inbounds for j=1:dim.product
      D[j] = 0
      for i=1:dim.product
        ∂D∂p[i,j] = 0
      end
    end
    return s,num,D,ms,∂s∂p,∂S∂p,∂D∂p
  end
end

function aliasRegion!(
  num   ::Vector{Float64},
  indx  ::indxType,
  r     ::Int64,
  dim   ::dimType,
  mat   ::matType,
  par   ::parType,
  sim   ::simType)

  fill!(num,0)
  # r   = g - minimum(indx.market) + 1 # region index
  g   = indx.market[r]
  αᵢ  = view(par.αᵢ,:,r)
  μ̃   = view(sim.μ̃,:,:,r)
  pop = mat.pop[r]
  # active = view(indx.active,:,r)
  active = findall(view(indx.active,:,r))

  return αᵢ,μ̃,pop,active
end

function setupIndex!(
  sim ::simType,
  indx::indxType,
  pdline::BitArray{1},
  dim ::dimType,
  mat ::matType,
  mask::maskType,
  t   ::Int64)

  indx.market .= dim.region*(t-1) .+ collect(1:dim.region)
  sim.μ̃       .= view(mat.μ̃,:,:,indx.market)
  sim.p       .= view(mat.p,:,t)

  anyActive = findmax(view(mat.active,:,indx.market), dims=2)[1]
  for j=1:dim.product
    indx.anyActive[j] = anyActive[j] & pdline[j]
    indx.mno[j]       = mask.mno[j]  & indx.anyActive[j]
    indx.mvno[j]      = mask.mvno[j] & indx.anyActive[j]
    for r=1:dim.region
      g = indx.market[r]
      indx.active[j,r] = mat.active[j,g] & pdline[j]
    end
  end
  for j=1:3
    for i=1:dim.mvno
      indx.mvnp[i,j] = mat.mvnp[i,j] & indx.anyActive[dim.mno+i]
    end
  end

end

function getMarkup(
  p     ::Vector{Float64},
  wprice::Vector{Float64},
  mcost ::Vector{Vector{Float64}})

  markupR = p - mcost[2]
  markupW = wprice - mcost[1]
  markupV = p - wprice - mcost[2]

  return markupR, markupW, markupV
end

function mergeMcosts(
  mcostinc,
  mcostfree,
  dim::dimType,
  indx::indxType,
  mask::maskType)

  # mcost = zeros(dim.product)
  # mcost[indx.anyActive .& .!mask.free] = mcostinc
  # mcost[indx.anyActive .& mask.free] .= mcostfree

  mcost = [zeros(dim.product) for t=1:2]
  idx = findall(indx.anyActive .& .!mask.free)
  for j in eachindex(idx)
    i = idx[j]
    if indx.mno[i]
      mcost[2][i] = mcostinc[j]
    elseif indx.mvno[i]
      mcost[2][i] = 0
      mcost[1][i] = mcostinc[j]
    end
  end
  mcost[2][mask.free] = mcostfree
  return mcost
end

function checkConvg(
  iter::Int64,
  Op  ::NLsolve.SolverResults,
  fail::Bool=false)

  exitflag = (converged(Op)==true) & (maximum(Op.zero)<100) & (fail==false)

  return exitflag
end

function whsaleprice(
  p,
  dim::dimType,
  mat::matType,
  sim::simType,
  indx::indxType)

  any    = indx.anyActive
  D1own  = sim.∂D∂p' .* mat.own
  markup = -D1own[any,any] \ sim.D[any]
  wprice = zeros(dim.product)
  wprice[any] = p[any] - markup

  return wprice
end

function collectΠ!( # Collect profits both retail & wholesale
  Π,
  eq  ::equilType,
  vInt::Bool,
  t   ::Int64,
  dim ::dimType,
  mat ::matType,
  indx::indxType,
  mask::maskType)

  # Incumbents' profit
  prodIdx = findall(indx.anyActive)
  for j in prodIdx
    if vInt==false
      i_retail = mat.firm[j,2]
      Π[i_retail] += eq.profit[j,t,2]
      if mask.mvno[j]
        i_whsale = mat.firm[j,3]
        Π[i_whsale] += eq.profit[j,t,1]
      end
    else
      i_whsale = mat.firm[j,3]
      Π[i_whsale] += eq.profit[j,t,2]
    end
  end # end of j loop

end

end
