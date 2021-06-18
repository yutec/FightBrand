module TypeDef
export datType, dimType, envType, labType, matType, setType, simType, tabType,
  equilType, indxType, maskType, parType

struct datType
  region  ::Vector{Int64}
  qtr     ::Vector{Int64}
  network ::Vector{Int64}
  brand   ::Vector{Int64}
  prepost ::Vector{Int64}
  product ::Vector{Int64}
  ms      ::Vector{Float64}
  price   ::Vector{Float64}
  δ       ::Vector{Float64}
  X       ::Matrix{Float64}
  Xᵢ      ::Matrix{Float64}
  ξ       ::Vector{Float64}
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
  prodt   ::Vector{Int64}
  mno     ::Int64
  mvno    ::Int64
  θ₂ ::Int64
  θ₁ ::Int64
  θ  ::Int64
  Xᵢ ::Int64
  Dᵢ ::Int64
  νᵢ ::Int64
  Rᵢ ::Int64
end

struct envType
  model     ::Int64
  mcid      ::Int64
  nSim      ::Int64
  ver       ::String
  pathOut   ::String
  pathImp   ::String
  fileOutp  ::String
  fileMcost ::String
  fileBase  ::String
  fileLog   ::String
  tol       ::Float64
  b1        ::Int64
  b2        ::Int64
  mc_mvno   ::Int64
end

struct labType
  network::Vector{String}
  prepost::Vector{String}
  product::Vector{String}
  prodIdx::Vector{Int64}
end

struct matType # input arrays for all markets
  y     ::Matrix{Float64}
  ν     ::Matrix{Float64}
  pop   ::Vector{Float64}
  ms    ::Matrix{Float64}
  p     ::Matrix{Float64}
  μ̃     ::Array{Float64,3}
  mvno  ::BitArray{2}
  mvnp  ::BitArray{2}
  own   ::BitArray{2}
  host  ::BitArray{2}
  active::BitArray{2}
  firm  ::Matrix{Int64}
end

struct parType
  θ₂     ::Vector{Float64}
  θ₁     ::Vector{Float64}
  αᵢ     ::Matrix{Float64}
  δ      ::Vector{Float64}
  indxeθ ::Vector{Int64}
end

struct setType
  region  ::Vector{Int64}
  qtr     ::Vector{Int64}
  product ::Matrix{Int64}
end

struct simType # minimal arrays for computation
  s      ::Vector{Float64}
  p      ::Vector{Float64}
  num    ::Vector{Float64}
  D      ::Vector{Float64}
  ms     ::Matrix{Float64}
  ∂s∂p   ::Array{Float64,2}
  ∂S∂p   ::Array{Float64,2}
  ∂D∂p   ::Array{Float64,2}
  μ̃      ::Array{Float64,3}
  ∂²S∂p² ::Array{Float64,3}
  ∂²D∂p² ::Array{Float64,3}
end

struct tabType
  retail   ::Array{Float64,2} # Retail price-markup table
  whsale   ::Array{Float64,2} # Wholesale price-markup table
  mcost    ::Array{Matrix{Float64},1}
  payoff   ::Array{Float64,3}
  Πperiod  ::Array{Float64,4} # Period profit under obs equil
  t9       ::Array{Float64,3}
  t9last   ::Array{Float64,4}
  t9ns     ::Array{Float64,4}
  fb       ::Array{Float64,3}
  fblast   ::Array{Float64,4}
  fbns     ::Array{Float64,4}
  bound    ::Array{Float64,3}
  divRatio ::Array{Float64,3}
  elasR    ::Array{Float64,3}
  elasW    ::Array{Float64,3}
  Πchannel ::Array{Float64,3}
  csplus   ::Array{Float64,2}
  tsplus   ::Array{Float64,3}
  Δprice   ::Array{Float64,3}
  lerner   ::Array{Float64,2}
  ebitda   ::Array{Float64,2}
end

struct equilType
  pdline ::BitArray{1}
  price  ::Matrix{Float64}
  mcost  ::Array{Matrix{Float64},1}
  wprice ::Array{Float64,2}
  markup ::Array{Float64,3}
  profit ::Array{Float64,3}
  csplus ::Array{Float64,1}
  demand ::Array{Float64,2}
  fail   ::BitArray{1}
end

struct indxType
  market   ::Vector{Int64}
  active   ::BitArray{2}
  anyActive::BitArray{1}
  mno      ::BitArray{1} # MNOs active in any of the markets
  mvno     ::BitArray{1} # MVNOs active in any of the markets
  mvnp     ::BitArray{2}
end

struct maskType
  mno  ::BitArray{1}
  mvno ::BitArray{1}
  free ::BitArray{1}
  Djpi ::BitArray{2}
end


end
