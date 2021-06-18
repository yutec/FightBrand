module Gmm

export gmmObj!, gmmObjOnly, gmmObjGradOnly!, gmmMoment
using TypeDef, Helper, Estim, UserFileIO
using LinearAlgebra

function gmmObj!(g::Vector{Float64}, θ₂::Vector{Float64},
  dat::datType, dim::dimType, fxp::fxpType, mat::matType,
  indx::indxType, pred::predType, diags::diagsType)

  m = gmmMoment(θ₂,dat,dim,fxp,mat,indx,pred,diags)
  gmmGrad!(g,m,dim,fxp,mat,indx,diags)
  return dot(m, mat.invPhi*m)
end

function gmmObjOnly(
  θ₂::Vector{Float64},
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  mat::matType,
  indx::indxType,
  pred::predType,
  diags::diagsType,
  update::Bool=false)

  m = gmmMoment(θ₂,dat,dim,fxp,mat,indx,pred,diags,update)
  return dot(m, mat.invPhi*m)
end
function gmmObjOnly(
  θ₂::Float64,
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  mat::matType,
  indx::indxType,
  pred::predType,
  diags::diagsType,
  update::Bool=false)

  m = gmmMoment([θ₂],dat,dim,fxp,mat,indx,pred,diags,update)
  return dot(m, mat.invPhi*m)
end

function gmmObjGradOnly!(g::Vector{Float64}, θ₂::Vector{Float64},
  dat::datType, dim::dimType, fxp::fxpType, mat::matType,
  indx::indxType, pred::predType, diags::diagsType)

  m = gmmMoment(θ₂,dat,dim,fxp,mat,indx,pred,diags)
  gmmGrad!(g,m,dim,fxp,mat,indx,diags)
end

function gmmGrad!(g::Vector{Float64}, m::Vector{Float64},
  dim::dimType, fxp::fxpType, mat::matType,
  indx::indxType, diags::diagsType)

  ∂δ∂θ = unpackStackedArray(fxp.∂δ∂θ, dim.obs,dim.θ₂,dim.market,indx.mkt)
  g[:] = 2*∂δ∂θ'*mat.Z*mat.invPhi*m
end

function gmmMoment(
  θ₂::Vector{Float64},
  dat::datType,
  dim::dimType,
  fxp::fxpType,
  mat::matType,
  indx::indxType,
  pred::predType,
  diags::diagsType,
  update::Bool=false)

  #setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,dim,indx,mat.L,mat.Lν,mat.Xᵢ,mat.νᵢ)
  setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
  fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
  #fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags)
  for t=1:dim.market
    if any(isnan.(fxp.eδ[t]))
      # println(" Error: fxp.eδ NaN")
      return NaN*ones(size(mat.Z,2),)
    end
  end
  if update==true
    optimIV!(mat,θ₂,dat,dim,fxp,indx,pred,diags)
  end
  linearIV!(mat.ξ, fxp.eδ,fxp.eδ1d, dim,mat,indx;output=3)
  m  = mat.Z'*mat.ξ
  # m  = view(mat.Z,mat.mask,:)'*view(mat.ξ,mat.mask,1)
  return m
end
# function gmmMoment(θ₂::Float64,
#   dat::datType, dim::dimType, fxp::fxpType, mat::matType,
#   indx::indxType, pred::predType, diags::diagsType, update::Bool=false)
#
#   setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,dim,mat,indx)
#   fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
#   if update==true
#     optimIV!(mat,θ₂,dat,dim,fxp,indx,pred,diags)
#   end
#   linearIV!(mat.ξ, fxp.eδ,fxp.eδ1d, dim,mat,indx;output=3)
#   m  = mat.Z'*mat.ξ
#   # m  = view(mat.Z,mat.mask,:)'*view(mat.ξ,mat.mask,1)
#   return m
# end

end # end of module
