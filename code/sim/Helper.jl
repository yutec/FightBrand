module Helper

export initialize!, readData, setModel, sampleParam!
export allocateSim, allocateEquil, allocEqArray, setupLab
using TypeDef
using DelimitedFiles, Statistics, Printf, Random

function readData(
  model ::Int64,       # ID for estimated model to import from input folder
  mcid  ::Int64,       # ID for Monte Carlo estimate to import
  b1    ::Int64,       # 1st bootstrap sample ID
  b2    ::Int64,       # last boostrap sample ID
  vInt  ::Bool=false,  # Vertical integrated market structure
  opt   ::Bool=true,   # Reset output folders
  ms15  ::Bool=false,  # MS expanded by 50%
  mvno  ::Int64=0;     # Retail marginal cost of MVNO
  ver   ::String="824",# Data version (final version by default)
  nSim  ::Int64=200)   # Number of simulation draws for random coefficients

  tol = 1e-14;
  if vInt==false
    sig  = "b"
  else
    sig  = "v"
  end
  pathRef   = "./"
  if ms15==false
    tagms15 = ""
  elseif ms15==true
    tagms15 = "ms15"
  end
  pathFile  = string("dat",ver,"/m",model,tagms15,"/mc",mvno,"/",sig,b1,"/")
  pathImpf  = string("dat",ver,"/m",model,tagms15,"/")
  pathOutp  = string(pathRef,"output/",pathFile)
  fileOutp  = string(pathOutp,"sim",ver,".jld")
  fileMcost = string(pathOutp,"mcost",ver,".jld")
  fileBase  = string(pathOutp,"base",ver,".jld")
  fileLog   = string(pathOutp,"log",ver,".txt")
  pathImp   = string(pathRef,"input/",pathImpf)
  env = envType(model,mcid,nSim,ver,pathOutp,pathImp,fileOutp,fileMcost,
                fileBase,fileLog,tol,b1,b2,mvno)

  if opt==true
    rm(env.pathOut,force=true,recursive=true)
    mkpath(env.pathOut)
  end
  workPath = "$(homedir())/work/kantar/brand/workfiles/"
  impData  = readdlm(workPath*string("demand",ver,tagms15,".csv"),',';header=true)
  impX     = readdlm(workPath*string("Xinput",ver,".csv"),',';header=true)
  impY     = readdlm(workPath*string("income.csv"),',';header=true)
  impParam = readdlm(string(pathImp,"gmmStage2.csv"),',')
  expDelta = readdlm(string(pathImp,"expDelta.csv"))[:,1]
  θ        = convert(Vector{Float64},impParam[mcid,2:(end-2)])

  qtr     = convert(Vector{Int64},impData[1][:,1])
  region  = convert(Vector{Int64},impData[1][:,2])
  network = convert(Vector{Int64},impData[1][:,3])
  brand   = convert(Vector{Int64},impData[1][:,4])
  pop     = convert(Vector{Float64},impData[1][:,5])
  ms      = convert(Vector{Float64},impData[1][:,6])
  ms0     = convert(Vector{Float64},impData[1][:,7])
  price   = convert(Vector{Float64},impData[1][:,8])
  prepost = convert(Vector{Int64},impData[1][:,13])
  idObs   = convert(Vector{Int64},impData[1][:,14])
  idLag   = convert(Vector{Int64},impData[1][:,15])

  Xinput  = impX[1]
  product = sortslices(unique([brand prepost]; dims=1); dims=1)
  set     = setType(unique(region),unique(qtr),product)

  nObs     = size(region,1)
  nProduct = size(product,1)
  prodindx = zeros(Int64,nObs)
  for i=1:nObs
    for j=1:nProduct
      if (brand[i]== set.product[j,1]) .& (prepost[i]==set.product[j,2])
        prodindx[i] = j
      end
    end
    if prodindx[i]==0
      @printf("Cannot find product index for brand %d prepost %d at obs %d\n",
              brand[i],prepost[i],i)
      error("Program stopped.\n")
    end
  end
  dat,dim,θ₂,θ₁,indxeθ = setModel(model,Xinput,region,qtr,network,brand,
    prepost,product,prodindx,ms,price,log.(expDelta),θ,env,set)

  # Set up indx
  mkt = BitArray(undef,dim.obs,0)
  for g in eachindex(set.region)
    for t in eachindex(set.qtr)
      mask = (dat.region.==set.region[g]).&(dat.qtr.==set.qtr[t])
      mkt = [mkt mask]
      push!(dim.prodt, sum(mask))
    end
  end
  if size(mkt,2)!=dim.market
    error("Mask dimension not matching unique markets.")
  end
  market    = zeros(Int64,dim.region)
  active    = falses(dim.product,dim.region)
  anyActive = falses(dim.product)
  mno       = falses(dim.product)
  mvno      = falses(dim.product)
  mvnp      = falses(dim.mvno,3)
  indx = indxType(market,active,anyActive,mno,mvno,mvnp)

  # mat
  mat,mask = allocateMat(impY,model,pop,dat,dim,set,vInt)

  # par0
  αᵢ = -θ₂[1] ./ mat.y
  if (env.model==104) | (env.model==105)
    αᵢ *= 5
  end
  par0 = parType(θ₂,θ₁,αᵢ,copy(dat.δ),indxeθ)

  # sim
  sim = allocateSim(dim)

  return dat, dim, env, mat, par0, set, sim, indx, mask
end

function setModel(
  model   ::Int64,
  Xinput  ::Matrix{Float64},
  region  ::Vector{Int64},
  qtr     ::Vector{Int64},
  network ::Vector{Int64},
  brand   ::Vector{Int64},
  prepost ::Vector{Int64},
  product ::Matrix{Int64},
  prodindx::Vector{Int64},
  ms      ::Vector{Float64},
  price   ::Vector{Float64},
  δ       ::Vector{Float64},
  θ       ::Vector{Float64},
  env     ::envType,
  set     ::setType)

  X       = [Xinput ones(size(Xinput,1))]
  prepaid = convert(Vector{Float64},prepost.==1)
  fbloque = convert(Vector{Float64},(prepost.==3))
  free    = convert(Vector{Float64},brand.==4)
  fightbr = convert(Vector{Float64},(brand.>=5) .& (brand.<=7))
  lowcost = convert(Vector{Float64},(free.==1) .| (fightbr.==1))
  ant4gs  = sum(Xinput[:,5:6],dims=2)
  o1      = ones(length(price))

  nDᵢ = 0
  nνᵢ = 0
  nRᵢ = 0
  indxeθ = Vector{Int64}(undef,0)

  if model==0      # RC logit I in the manuscript
    Xᵢ = [-price fbloque*10 -ant4gs]
    labΣᵢᵢ = ["Price/y";"Fbloque/y";"Ant4G/y"]
    nDᵢ = 3; nRᵢ = 1
  elseif model==15 # RC logit II in the manuscript
    Xᵢ = [-price -ant4gs o1 fbloque*10 prepaid*10]
    labΣᵢᵢ = ["Price/y";"Ant4G/y";"Intercept/y";"Fbloque/y";"Prepaid/y"]
    nDᵢ = 5; nRᵢ = 1
  else
    error("No model number matched.")
  end

  nXᵢ = size(Xᵢ,2)
  θ₂  = θ[1:nXᵢ]
  θ₁  = θ[(nXᵢ+1):end]
  neθ = length(indxeθ)
  θ₂[indxeθ] = exp.(θ₂[indxeθ])
  ξ = δ - X * θ₁
  nθ₂ = length(θ₂)
  nθ₁ = size(X,2)
  nθ  = length(θ)

  nPerson  = env.nSim
  nObs     = size(X,1)
  nTime    = length(set.qtr)
  nRegion  = length(set.region)
  nMarket  = size(unique([region qtr]; dims=1),1)
  nNetwork = length(unique(network))
  nBrand   = length(unique(brand))
  nPrepost = length(unique(prepost))
  nProduct = size(product,1)
  nHost    = 3
  nMno     = 13 # num of MNO products
  nMvno    = 9  # num of MVNO products
  nProdt = Array{Int64,1}(undef,0)

  dat = datType(region,qtr,network,brand,prepost,prodindx,ms,price,δ,X,Xᵢ,ξ)
  dim = dimType(nRegion,nTime,nNetwork,nBrand,nPrepost,nProduct,nPerson,
                nMarket,nObs,nProdt,nMno,nMvno,nθ₂,nθ₁,nθ,nXᵢ,nDᵢ,nνᵢ,nRᵢ)

  return dat,dim,θ₂,θ₁,indxeθ
end

function allocateSim(
  dim::dimType)

  # Sim allocate
  s   = zeros(dim.product)
  p   = zeros(dim.product)
  num = zeros(dim.product)
  D   = zeros(dim.product)
  ms  = zeros(dim.product,dim.region)
  ∂s∂p   = zeros(dim.product,dim.product)
  ∂S∂p   = zeros(dim.product,dim.product)
  ∂D∂p   = zeros(dim.product,dim.product)
  μ̃      = zeros(dim.product,dim.person,dim.region)
  ∂²S∂p² = zeros(dim.product,dim.product,dim.product)
  ∂²D∂p² = zeros(dim.product,dim.product,dim.product)

  sim = simType(s,p,num,D,ms,∂s∂p,∂S∂p,∂D∂p,μ̃,∂²S∂p²,∂²D∂p²)

  return sim
end

function allocateMat(
  impY,
  model::Int64,
  pop  ::Vector{Float64},
  dat  ::datType,
  dim  ::dimType,
  set  ::setType,
  vInt ::Bool=false)

  workPath = "$(homedir())/work/kantar/brand/workfiles/simdraws/"
  csvname  = string(workPath,"lhsnorm",dim.Rᵢ,"d",dim.person,".csv")
  if isfile(csvname)
    impRand = readdlm(csvname,',';header=false)
  else
    # Random.seed!(1234)
    # impRand = randn(dim.person,dim.Rᵢ)
    csvname  = string(workPath,"lhsnorm",dim.Rᵢ,"d200.csv")
    impRand = readdlm(csvname,',';header=false)[1:dim.person,:]
    @printf("Warning: Using user-specified random numbers instead.\n")
  end
  randDraw = impRand[1:dim.person,:]'
  z = randDraw[1,:]
  ν = randDraw[2:end,:]
  y = zeros(dim.person,dim.region)
  ȳ = impY[1]
  if model<100
    for i=1:dim.person
      z[i] = max(z[i], -1.5615)
    end
    for r=1:dim.region
      for i=1:dim.person
        y[i,r] = max(ȳ[r,2] + ȳ[r,3]*z[i], 300)/100
      end
    end
  elseif model>=100
    for r=1:dim.region
      for i=1:dim.person
        y[i,r] = max(exp(ȳ[r,4] + ȳ[r,5]*z[i]), 300)/100
      end
    end
  end

  mat_pop = zeros(dim.region);
  for r=1:dim.region
    g = set.region[r]
    mat_pop[r] = pop[findfirst(dat.region.==g)]
  end
  ms = zeros(dim.product,dim.market)
  p  = zeros(dim.product,dim.qtr)
  μ̃  = zeros(dim.product,dim.person,dim.market)

  active = falses(dim.product,dim.market)
  for n=1:dim.obs
    t = dat.qtr[n]-3
    g = dat.region[n]
    i = dat.product[n]
    r = findfirst(set.region.==g)
    j = dim.region*(t-1) + r
    # @printf("n:%d t:%d r:%d j:%d\n",n,t,r,j)
    active[i,j] = true
  end

  host = [1,1,1,2,2,2,3,3,3,4,1,3,2,1,1,1,2,2,2,3,3,3]
  firm = [sortslices(unique([dat.product dat.network]; dims=1); dims=1) host]

  mno  = (firm[:,2].<=4)
  mvno = .!(mno)
  free = falses(dim.product)
  @. free[firm[:,2]==4] = true
  ∂D∂p = falses(dim.product,dim.product)
  own  = falses(dim.product,dim.product)
  host = falses(dim.product,dim.product)
  if vInt==false # Wholesale-retail
    for j in firm[mno,1]
      @. ∂D∂p[:,j] = (firm[:,2]==firm[j,2])
      @. host[:,j] = (firm[:,3]==firm[j,3])
    end
    for j in firm[mvno,1]
      @. ∂D∂p[:,j] = (firm[:,2]==firm[j,2])
      @. host[:,j] = (firm[:,2]==firm[j,2])
    end
  else # Vertical integration
    for j in firm[mno,1]
      @. ∂D∂p[:,j] = (firm[:,3]==firm[j,3])
      @. host[:,j] = (firm[:,3]==firm[j,3])
    end
    for j in firm[mvno,1]
      @. host[:,j] = (firm[:,3]==firm[j,3])
    end
  end
  user = trues(dim.product)
  mask = maskType(mno,mvno,free,∂D∂p)

  for j=1:dim.product
    @. own[:,j] = (firm[:,2]==firm[j,2])
  end
  mvno = falses(size(firm,1),3)
  mvnp = falses(dim.mvno,3)
  for i=1:3
    @. mvno[:,i] = (firm[:,3]==i) & mask.mvno
    @. mvnp[:,i] = (firm[mask.mvno,3]==i)
  end
  mat = matType(y,ν,mat_pop,ms,p,μ̃,mvno,mvnp,own,host,active,firm)

  return mat, mask
end

function initialize!(
  mat::matType,
  dat::datType,
  dim::dimType,
  par::parType,
  set::setType)

  for n=1:dim.obs
    t = dat.qtr[n]-3
    r = findfirst(set.region.==dat.region[n])
    i = dat.product[n]
    j = dim.region*(t-1)+r
    mat.ms[i,j] = dat.ms[n]
    mutil = par.δ[n]
    for k=1:dim.person
      μ = 0.0
      for l=2:dim.Dᵢ # Heterogeneity net of price
        μ += dat.Xᵢ[n,l] * par.θ₂[l] / mat.y[k,r]
      end
      for l=(dim.Dᵢ+1):(dim.Dᵢ+dim.νᵢ)
        μ += dat.Xᵢ[n,l] * par.θ₂[l] * mat.ν[l-dim.Dᵢ,k]
      end
      mat.μ̃[i,k,j] = mutil + μ
    end
    mat.p[i,t] = dat.price[n]
  end

end

function allocateEquil(
  dim::dimType)

  pdline = trues(dim.product)
  price  = zeros(dim.product,dim.qtr)
  mcost  = [zeros(dim.product,dim.qtr) for t=1:2]
  wprice = zeros(dim.product,dim.qtr)
  markup = zeros(dim.product,dim.qtr,2)
  profit = zeros(dim.product,dim.qtr,2)
  csplus = zeros(dim.qtr)
  demand = zeros(dim.product,dim.qtr)
  fail   = falses(dim.qtr)

  equil = equilType(pdline,price,mcost,wprice,markup,profit,csplus,demand,fail)
  eq    = Array{equilType,1}(undef,16)
  for i=1:16
    eq[i] = deepcopy(equil)
  end
  # Set up pdline corresponding to each scenario
  # Free:  10
  # Sosh:  11
  # Red:   13
  # B&You: 12
  eq[2].pdline[12] = false;
  eq[3].pdline[10] = false;
  @. eq[4].pdline[[10,12]] = false;

  eq[5].pdline[11] = false;
  @. eq[6].pdline[[11,12]] = false;
  @. eq[7].pdline[[10,11]] = false;
  @. eq[8].pdline[[10,11,12]] = false;

  eq[9].pdline[13] = false;
  @. eq[10].pdline[[12,13]] = false;
  @. eq[11].pdline[[10,13]] = false;
  @. eq[12].pdline[[10,12,13]] = false;

  @. eq[13].pdline[[11,13]] = false;
  @. eq[14].pdline[[11,12,13]] = false;
  @. eq[15].pdline[[10,11,13]] = false;
  @. eq[16].pdline[[10,11,12,13]] = false;

  return eq
end

function allocEqArray(
  b1 ::Int64,
  b2 ::Int64,
  dim::dimType)

  nBoot = b2-b1+1
  eqArray = Array{Array{equilType,1},1}(undef,nBoot)
  for i=1:(b2-b1+1)
    eqArray[i] = allocateEquil(dim)
  end
  return eqArray

end

function sampleParam!(
  b   ::Int64,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType)

  imp = readdlm(string(env.pathImp,"paramDraws.csv"),',')
  θ = imp[b,1:dim.θ]
  δ = log.(imp[b,(dim.θ+1):end])
  if length(δ)!=dim.obs
    @printf("Length of δ ≂̸ dim.obs at paramDraws.csv.\n")
  end
  α = θ[1]
  θ[par0.indxeθ] = exp.(θ[par0.indxeθ])

  θ₂ = θ[1:dim.θ₂]
  θ₁ = θ[(dim.θ₂+1):end]
  αᵢ = -θ₂[1] ./ mat.y
  if (env.model==104) | (env.model==105)
    αᵢ *= 5
  end
  par = parType(θ₂,θ₁,αᵢ,δ,par0.indxeθ)

  return par
end

function sampleParam!(
  b   ::Int64,
  imp ::Array{Float64,2},
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType)

  θ = imp[b,1:dim.θ]
  δ = log.(imp[b,(dim.θ+1):end])
  if length(δ)!=dim.obs
    @printf("Length of δ ≂̸ dim.obs at paramDraws.csv.\n")
  end
  α = θ[1]
  θ[par0.indxeθ] = exp.(θ[par0.indxeθ])

  θ₂ = θ[1:dim.θ₂]
  θ₁ = θ[(dim.θ₂+1):end]
  αᵢ = -θ₂[1] ./ mat.y

  par = parType(θ₂,θ₁,αᵢ,δ,par0.indxeθ)

  return par
end

function setupLab()

  network = ["Orange","SFR","Bouygues","Free","MVNO:O","MVNO:S","MVNO:B"]
  plab    = ["Prepaid","Postpaid","F.bloqué"]
  prepost = [repeat(plab,3);repeat(["Postpaid"],4);repeat(plab,3)]
  product = ["Orange","Orange","Orange","SFR","SFR","SFR",
             "Bouygues","Bouygues","Bouygues","Free","Sosh","B&You","Red",
             "MVNO:O","MVNO:O","MVNO:O","MVNO:S","MVNO:S","MVNO:S",
             "MVNO:B","MVNO:B","MVNO:B"]
  prodIdx = [1,2,3,11,4,5,6,13,7,8,9,12,10,14,15,16,17,18,19,20,21,22]
  lab = labType(network,prepost,product,prodIdx)

  return lab

end

end # end of module
