module Compute

export demand!, demandD1only!, demandOnly
export setupIndex!, jacobS!, passThrough
using TypeDef, Helper, Tools
using Statistics, LinearAlgebra, LoopVectorization

function share!(
  s,
  p,
  num,
  μ̃,
  αᵢ::Vector{Float64},
  active::BitArray{1},
  dim::dimType)

  for i=1:dim.person
    den = 1.0;
    for j=1:dim.product
      num[j] = (active[j]==true) ? exp(μ̃[j,i]+αᵢ[i]*p[j]) : 0
      den += num[j]
    end
    for j=1:dim.product
      s[j] = num[j]/den
    end
  end
end

function demand!(
  sim::simType,
  p::Vector{Float64},
  dim::dimType,
  mat::matType,
  par::parType,
  indx::indxType)

  s,num,D,ms,∂s∂p,∂S∂p,∂²S∂p²,∂D∂p,∂²D∂p² = alias(dim,sim,true)

  @inbounds for r=1:dim.region
    for k=1:dim.product
      for j=1:dim.product
        ∂S∂p[j,k] = 0
        for i=1:dim.product
          ∂²S∂p²[i,j,k] = 0
        end
      end
    end
    αᵢ,μ̃,pop,active = aliasRegion!(num,indx,r,dim,mat,par,sim)

    for n=1:dim.person
      jacobS!(∂s∂p,∂S∂p,s,view(ms,:,r),view(μ̃,:,n),αᵢ[n],p,num,active,dim)

      # ∂²S∂p²[i,j,k] = ∂sᵢ / (∂p_j ∂p_k)
      @avx for ki in eachindex(active)
        k = active[ki]
        for ji in eachindex(active)
          j = active[ji]
          for ii in eachindex(active)
            i = active[ii]
            sp = αᵢ[n]*(∂s∂p[i,k]*(i==j)-s[j]*∂s∂p[i,k]-s[i]*∂s∂p[j,k])
            ∂²S∂p²[i,j,k] += sp
          end
        end
      end
    end # end of n loop

    for k in active
      ms[k,r] /= dim.person
      D[k]    += ms[k,r] * pop
      for j in active
        ∂S∂p[j,k] /= dim.person
        ∂D∂p[j,k] += pop * ∂S∂p[j,k]
        for i in active
          ∂²S∂p²[i,j,k] /= dim.person
          ∂²D∂p²[i,j,k] += pop * ∂²S∂p²[i,j,k]
        end
      end
    end
  end # end of r loop
end

function demandD1only!(
  sim::simType,
  p::Vector{Float64},
  dim::dimType,
  mat::matType,
  par::parType,
  indx::indxType)

  s,num,D,ms,∂s∂p,∂S∂p,∂D∂p = alias(dim,sim)

  @inbounds for r=1:dim.region
    fill!(∂S∂p,0)
    # fastFill!(∂S∂p,dim.product,dim.product)
    αᵢ,μ̃,pop,active = aliasRegion!(num,indx,r,dim,mat,par,sim)

    for n=1:dim.person
      jacobS!(∂s∂p,∂S∂p,s,view(ms,:,r),view(μ̃,:,n),αᵢ[n],p,num,active,dim)
    end # end of n loop

    for k in active
      ms[k,r] /= dim.person
      D[k]  += ms[k,r] * pop
      for j in active
        ∂S∂p[j,k] /= dim.person
        ∂D∂p[j,k] += pop * ∂S∂p[j,k]
      end
    end
  end # end of g loop
end

function demandOnly(
  sim::simType,
  p::Vector{Float64},
  dim::dimType,
  mat::matType,
  par::parType,
  indx::indxType)

  s,num,D,ms,∂s∂p,∂S∂p,∂D∂p = alias(dim,sim)

  csplusTotal = 0.0
  @inbounds for r=1:dim.region
    αᵢ,μ̃,pop,active = aliasRegion!(num,indx,r,dim,mat,par,sim)

    csplus = 0.0
    for n=1:dim.person
      den = 1.0
      @avx for ji in eachindex(active)
        j = active[ji]
        num[j] = exp(μ̃[j,n]+αᵢ[n]*p[j])
        den += num[j]
      end
      csplus += -3log(den) * pop / αᵢ[n]
      @avx for ji in eachindex(active)
        j = active[ji]
        s[j]     = num[j]/den
        ms[j,r] += s[j]
      end
    end # end of n loop
    csplus /= dim.person
    csplusTotal += csplus

    for k in active
      ms[k,r] /= dim.person
      D[k]    += ms[k,r] * pop
    end
  end # end of g loop

  return copy(D), csplusTotal
end

function jacobS!(
  ∂s∂p,
  ∂S∂p,
  s::Vector{Float64},
  ms,
  μ̃,
  αᵢ::Float64,
  p::Vector{Float64},
  num::Vector{Float64},
  active,
  dim::dimType)

  den = 1.0
  @avx for ji in eachindex(active)
    j = active[ji]
    num[j] = exp(μ̃[j]+αᵢ*p[j])
    den += num[j]
  end

  @avx for ji in eachindex(active)
    j = active[ji]
    s[j]   = num[j]/den
    ms[j] += s[j]
  end
  @avx for ji in eachindex(active)
    j = active[ji]
    for ii in eachindex(active)
      i = active[ii]
      ∂s∂p[i,j]  = αᵢ*(s[i]*(i==j) - s[i]*s[j])
      ∂S∂p[i,j] += ∂s∂p[i,j]
    end
  end

end

function passThrough(
  markupR,
  markupW,
  markupV,
  dim::dimType,
  mat::matType,
  sim::simType,
  indx::indxType,
  mask::maskType)

  A = zeros(dim.product,dim.product)
  B = zeros(dim.product,dim.mvno)
  Djpi = sim.∂D∂p' .* mask.Djpi
  any = indx.anyActive

  for f=1:4
    Lf = (mat.firm[:,2].==f) .& any
    Lfid = findall(Lf)
    a1 = sim.∂D∂p[Lf,:]
    for l in Lfid
      a1 = a1 + markupR[l] * sim.∂²D∂p²[Lf,:,l]
    end

    if f<=3
      L0 = mat.mvno[:,f] .& any
      L0id = findall(L0)

      a2 = sim.∂D∂p[L0,:]
      for l in L0id
        a1 = a1 + markupW[l] * sim.∂²D∂p²[Lf,:,l]
        a2 = a2 + markupV[l] * sim.∂²D∂p²[L0,:,l]
      end
      A[Lf.|L0,:] = A[Lf.|L0,:] + [a1;a2] + Djpi[Lf.|L0,:]
      B[Lf.|L0,indx.mvnp[:,f]] = [-sim.∂D∂p[L0,Lf]'; sim.∂D∂p[L0,L0]]
    else
      A[Lf,:] = A[Lf,:] + a1 + Djpi[Lf,:]
    end
  end
  x = zeros(dim.product,dim.mvno)
  # x[any,:] = inv(A[any,any]) * B[any,:]
  x[any,:] = A[any,any] \ B[any,:]

  return x
end

end # end of module
