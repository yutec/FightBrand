module TypeDef
export datType, dimType, fxpType, labType, matType, setType,
  indxType, predType, diagsType, paramType, fileNameType

struct datType
  region  ::Vector{Int64}
  qtr     ::Vector{Int64}
  network ::Vector{Int64}
  brand   ::Vector{Int64}
  pop     ::Vector{Float64}
  ms1d    ::Vector{Float64}
  msOO1d  ::Vector{Float64}
  price   ::Vector{Float64}
  # income  ::Vector{Float64}
  prepost ::Vector{Int64}
end

struct dimType
  region  ::Int64
  qtr     ::Int64
  network ::Int64
  brand   ::Int64
  prepost ::Int64
  product ::Int64
  person  ::Int64
  market  ::Int64
  obs     ::Int64
  obsIn   ::Int64
  prodt   ::Vector{Int64}
  θ₂ ::Int64
  θ₁ ::Int64
  θ  ::Int64
  Xᵢ ::Int64
  Dᵢ ::Int64
  νᵢ ::Int64
  Rᵢ ::Int64
end

struct fxpType
  eδ   ::Vector{Vector{Float64}}
  eδ̂   ::Vector{Vector{Float64}}
  eδ1d ::Vector{Float64}
  eδ̂1d ::Vector{Float64}
  eμ   ::Array{Matrix{Float64},1}
  eμ̂   ::Array{Matrix{Float64},1}
  ∂δ∂θ ::Array{Array{Float64,2},1}
  ∂δ̂∂θ ::Array{Array{Float64,2},1}
end

struct labType
  θ₁  ::Array{String,1}
  Σᵢᵢ ::Array{String,1} # diagonal elements of Σ
  L   ::Array{String,1} # Lower triangular Cholesky of Σ
end

struct matType
  X         ::Matrix{Float64}
  X̂         ::Vector{Matrix{Float64}}
  Xᵢ        ::Matrix{Float64}
  X̂ᵢ        ::Matrix{Float64}
  Xexo      ::Matrix{Float64}
  Z         ::Matrix{Float64}
  invPhi    ::Matrix{Float64}
  XZ        ::Matrix{Float64}
  XZPhiZXZ  ::Matrix{Float64}
  p̂         ::Vector{Float64}
  ξ         ::Matrix{Float64}
  Lξ        ::Matrix{Float64}
  Eξ        ::Matrix{Float64}
  νᵢ        ::Matrix{Float64}
  y         ::Matrix{Float64}
  dμdL      ::Vector{Array{Float64,3}}
  dμ̂dL      ::Vector{Array{Float64,3}}
  L         ::Matrix{Float64}
  Lν        ::Matrix{Float64}
  ∂δ̂∂θ      ::Matrix{Float64}
  mask      ::BitArray{1}
  maskBrand ::BitArray{2}
  income    ::Array{Vector{Float64},1}
  logIncome ::Array{Vector{Float64},1}
  Dᵢ        ::Array{Array{Float64,3},1}
  ms        ::Vector{Vector{Float64}}
end

struct setType
  region  ::Vector{Int64}
  qtr     ::Vector{Int64}
  network ::Vector{Int64}
  brand   ::Vector{Int64}
  prepost ::Vector{Int64}
  product ::Matrix{Int64}
end

mutable struct diagsType
  iter     ::Int64
  iterBLP  ::Int64
  tolBLP   ::Float64
  tolOptIV ::Float64
  gtolSimplex ::Float64
  gtolBFGS    ::Float64
end

struct indxType
  mkt   ::BitArray{2}
  diagL ::Vector{Int64}
  L     ::Matrix{Int64}
  idObs ::Vector{Int64}
  idLag ::Vector{Int64}
  expθ  ::Vector{Int64}
end

struct predType
  s   ::Array{Array{Float64,1},1}
  ms  ::Array{Array{Float64,1},1}
  mss ::Array{Array{Float64,2},1}
  num ::Array{Array{Float64,1},1}
  eμ₀ ::Array{Vector{Float64},1}
  adj ::Array{Vector{Float64},1}
  ∂S∂θ::Array{Array{Float64,2},1}
end

struct paramType
  θ₂    ::Vector{Float64}
  θ₁    ::Vector{Float64}
  seθ   ::Vector{Float64}
  Jstat ::Float64
end

struct fileNameType
  CSV1 ::String
  CSV2 ::String
  JLD1 ::String
  JLD2 ::String
  INT1 ::String
  INT2 ::String
end


end
