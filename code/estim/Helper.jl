module Helper

export initialize, importData, config!, unpackStackedArray, allocMat!,
  unpackStackedArray!, collectResult, assignFilename, updateIVmatrix!,
  convert2share, initδ!, importθ̂₂
using TypeDef
using DelimitedFiles, Statistics, Printf, Random, StatsBase

function importData(
  model  ::Int64,   # ID for demand model to estimate
  iv     ::String,  # IV approach (opt,blp,diff-quad,diff-local)
  nPerson::Int64,   # Number of simulation draws for random coefficients
  ver    ::String,  # Version of estimation data (824 for final version)
  impFile::String;  # Type of import files (corresponding to model & IV)
  output ::Int64=1) # Type of function output

  workPath = "$(homedir())/work/kantar/brand/workfiles/"

  if (impFile=="base") | (impFile=="optIVtest") | (impFile=="optIV2")
    fileD = string(workPath,"demand",ver,".csv")
    fileX = string(workPath,"Xinput",ver,".csv")
    if iv=="blp"
      fileZ = string(workPath,"ZinputBlp",ver,".csv")
    else
      fileZ = string(workPath,"ZinputBlp",ver,"core.csv")
    end
    fileDIV  = string(workPath,"DiffIVinput",ver,"reduced.csv")
  elseif impFile=="extra"
    fileD = string(workPath,"demand",ver,"extra.csv")
    fileX = string(workPath,"Xinput",ver,"extra.csv")
    fileZ = string(workPath,"ZinputBlp",ver,"coreextra.csv")
    fileDIV  = string(workPath,"DiffIVinput",ver,"reduced2.csv")
  elseif impFile=="ms15"
    fileD = string(workPath,"demand",ver,"ms15.csv")
    fileX = string(workPath,"Xinput",ver,".csv")
    fileZ = string(workPath,"ZinputBlp",ver,"core.csv")
    fileDIV  = string(workPath,"DiffIVinput",ver,"reduced2.csv")
  elseif impFile=="noAllow"
    fileD = string(workPath,"demand",ver,"NoAllow.csv")
    fileX = string(workPath,"Xinput",ver,"NoAllow.csv")
    fileZ = string(workPath,"ZinputBlp",ver,"core.csv")
    fileDIV  = string(workPath,"DiffIVinput",ver,"reduced2.csv")
  end

  impD   = readdlm(fileD,',';header=true)
  impX   = readdlm(fileX,',';header=true)
  impZ   = readdlm(fileZ,',';header=true)
  impDIV = readdlm(fileDIV,',';header=true)

  qtr     = convert(Vector{Int64},impD[1][:,1])
  region  = convert(Vector{Int64},impD[1][:,2])
  network = convert(Vector{Int64},impD[1][:,3])
  brand   = convert(Vector{Int64},impD[1][:,4])
  pop     = convert(Vector{Float64},impD[1][:,5])
  ms1d    = convert(Vector{Float64},impD[1][:,6])
  msOO1d  = convert(Vector{Float64},impD[1][:,7])
  price   = convert(Vector{Float64},impD[1][:,8])
  # p̂       = convert(Vector{Float64},impD[1][:,9]) # Generated by setIV()
  rawInc  = convert(Vector{Float64},impD[1][:,10])
  sdrInc  = convert(Vector{Float64},impD[1][:,11])

  indata  = convert(BitArray{1},impD[1][:,12])
  prepost = convert(Vector{Int64},impD[1][:,13])
  idObs   = convert(Vector{Int64},impD[1][:,14])
  idLag   = convert(Vector{Int64},impD[1][:,15])

  logInc  = convert(Vector{Float64},impD[1][:,16])
  sdlInc  = convert(Vector{Float64},impD[1][:,17])

  Xinput  = impX[1]
  Zinput  = impZ[1]
  Dinput  = impDIV[1]
  product = sortslices(unique([brand prepost]; dims=1); dims=1)

  # ms = Vector{Vector{Float64}}(undef,0)
  dat = datType(region,qtr,network,brand,pop,ms1d,msOO1d,price,prepost)
  set = setType(unique(region),unique(qtr),unique(network),unique(brand),
                unique(prepost),product)

  # Model setup
  Xexo,Xᵢ,nXᵢ,nθ₂,nDᵢ,nνᵢ,nRᵢ,labΣᵢᵢ,labL,diagL,indxL,indxeθ,ixP =
    setModel(model,Xinput,dat)

  # Dimensions
  nMarket = size(unique([dat.region dat.qtr];dims=1),1)
  nθ₁ = size(Xexo,2) # Excludes price in X
  nProdt = Array{Float64,1}(undef,0)
  dim = dimType(length(set.region),length(set.qtr),length(set.network),
                length(set.brand),length(set.prepost),size(set.product,1),
                nPerson,nMarket,length(indata),count(indata.==true),
                nProdt,nθ₂,nθ₁,nθ₂+nθ₁,nXᵢ,nDᵢ,nνᵢ,nRᵢ)

  # Markt index
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
  indx = indxType(mkt,diagL,indxL,idObs,idLag,indxeθ)

  ξ    = Matrix{Float64}(undef,dim.obs,1)
  Lξ   = Matrix{Float64}(undef,dim.obs,1)
  Eξ   = Matrix{Float64}(undef,dim.obs,1)
  ν    = zeros(nνᵢ,nPerson)
  y    = zeros(dim.obs,dim.person)
  dμdL = [zeros(Float64,dim.prodt[t],dim.θ₂,dim.person) for t=1:dim.market]
  dμ̂dL = [zeros(Float64,dim.prodt[t],dim.θ₂,dim.person) for t=1:dim.market]
  L    = Array{Float64,2}(undef,nXᵢ,nXᵢ)
  Lν   = zeros(Float64,dim.Xᵢ,dim.person)
  ∂δ̂∂θ = zeros(Float64,dim.obs,dim.θ₂)
  maskBrand = BitArray{2}(undef,dim.obs,dim.brand)
  for i=1:dim.brand
    @. maskBrand[:,i] = (~indata) & (dat.brand==i)
  end
  inc  = [zeros(Float64,2) for t=1:dim.market]
  linc = [zeros(Float64,2) for t=1:dim.market]
  Dᵢ   = [zeros(Float64,dim.Dᵢ,dim.prodt[t],dim.person) for t=1:dim.market]

  Z, X̂ᵢ, p̂ = setIV(Xᵢ,Xexo,Zinput,Dinput,price,ixP,dim,indx,iv)
  X = Xexo; # excludes price in X
  XZ = X'*Z; invPhi = inv(Z'*Z)
  XZPhiZXZ = (XZ*invPhi*XZ')\(XZ*invPhi*Z')
  #X̂ = Vector{Matrix{Float64}}(undef,0);
  X̂  = [zeros(Float64,dim.prodt[t],dim.θ₁) for t=1:dim.market]
  ms = [zeros(Float64,dim.prodt[t],) for t=1:dim.market]
  mat = matType(X,X̂,Xᵢ,X̂ᵢ,Xexo,Z,invPhi,XZ,XZPhiZXZ,p̂,ξ,Lξ,Eξ,ν,y,
                dμdL,dμ̂dL,L,Lν,∂δ̂∂θ,indata,maskBrand,inc,linc,Dᵢ,ms)

  for t=1:dim.market
    id = findfirst(view(indx.mkt,:,t).==true)
    mat.income[t]    .= [rawInc[id], sdrInc[id]]
    mat.logIncome[t] .= [logInc[id], sdlInc[id]]
  end

  # Labels
  labθ₁ = []
  if dim.Dᵢ==0
    labθ₁  = ["Price/income"]
  end
  for k in eachindex(impX[2])
    labθ₁ = [labθ₁; String(impX[2][k])]
  end
  labθ₁ = [labθ₁; "Constant"]
  lab = labType(labθ₁,labΣᵢᵢ,labL)
  if output==1
    return dat, dim, lab, mat, set, indx
  elseif output==0
    return dim, lab, indx
  end
end

function config!(
  model     ::Int64,
  dat       ::datType,
  dim       ::dimType,
  mat       ::matType,
  set       ::setType,
  indx      ::indxType,
  simEmpiric::Bool=false,
  lowBoundOn::Bool=false,
  truncate  ::Bool=false)

  workPath = "$(homedir())/work/kantar/brand/workfiles/simdraws/"
  fileName = string("lhsnorm",dim.Rᵢ,"d",dim.person,".csv")
  csvname  = string(workPath*fileName)
  impRand  = readdlm(csvname,',';header=false)
  randDraw = impRand[1:dim.person,:]'
  lowBound = -Inf64
  if lowBoundOn==true
    lowBound = -1.5615
  end
  z = max.(randDraw[1:1,:],lowBound)
  ν = randDraw[2:end,:]
  if (dim.Rᵢ < (1 + dim.νᵢ))
    ν = vcat(ν, repeat(ν[end:end,:], 1+dim.νᵢ-dim.Rᵢ,1))
    display("text/plain",ν[:,1:5])
    # exit()
  end
  println("Sim. draws imported from: ",fileName)

  # Import random draws for truncated log normal
  if truncate==true
    rng = MersenneTwister(999)
  end

  if simEmpiric==true
    impEmp = readdlm(string(workPath*"incomeEMdraws.csv"),',';header=true)
    region = convert(Vector{Int64},impEmp[1][:,1])
    income = convert(Vector{Float64},impEmp[1][:,2])/100
    yInv   = convert(Vector{Float64},impEmp[1][:,3])
  end

  # Variables of heterogeneous taste
  if dim.Dᵢ>0
    Dᵢ = zero(mat.y)

    if simEmpiric==false
      for t=1:dim.market
        if (model>=100) # Log normal income
          ymean = mat.logIncome[t][1]
          ystd  = mat.logIncome[t][2]
          ysim  = ymean .+ ystd*z[1:1,:]
          yᵣ = max.(exp.(ysim),300)/100
          if truncate==true
            for j=1:size(yᵣ,2)
              while yᵣ[j]>80
                ysim = ymean + ystd*randn(rng)
                yᵣ[1,j] = max(exp(ysim),300)/100
              end
            end
          end
        else            # Normal income
          yᵣ = max.(mat.income[t][1] .+ mat.income[t][2]*z[1:1,:],300)/100
          ### Test of lower cutoff
          # for j=1:size(yᵣ,2)
          #   while yᵣ[j]==3
          #     yᵣ[1,j]=max.(mat.income[t][1].+mat.income[t][2]*randn(rng),300)/100
          #   end
          # end
          ### end of test
        end
        # println("Market: ", t, " Minimum income: ",minimum(yᵣ))
        mask = view(indx.mkt,:,t)
        mat.y[mask,:] = repeat(yᵣ,dim.prodt[t],1)
        if (model==101) | (model==116)  # Non-inverse
          Dᵢ[mask,:] = mat.y[mask,:]/100
        else                            # Inverse function
          Dᵢ[mask,:] = 1 ./ mat.y[mask,:]
        end
        for k=1:dim.Dᵢ
          @. mat.Dᵢ[t][k,:,:] = Dᵢ[mask,:]
        end
      end
    elseif simEmpiric==true
      for r in set.region
        maskObs = findall(dat.region.==r)
        maskInc = findall(region.==r)
        mat.y[maskObs,:] = repeat(income[maskInc]',length(maskObs),1)
        Dᵢ[maskObs,:] = 1 ./ mat.y[maskObs,:]
      end
      for t=1:dim.market
        mask = view(indx.mkt,:,t)
        for k=1:dim.Dᵢ
          @. mat.Dᵢ[t][k,:,:] = Dᵢ[mask,:]
        end
      end
    end
  end
  # println("Mean: ",round(mean(Dᵢ[:]),digits=6)," Median: ",median(Dᵢ[:]))
  # println("Min: ",minimum(Dᵢ[:])," Max: ",maximum(Dᵢ[:]))
  # println("Perc 95%: ",percentile(Dᵢ[:],95))
  # println("Perc 97.5%: ",percentile(Dᵢ[:],97.5))

  Xᵢ = mat.Xᵢ
  X̂ᵢ = mat.X̂ᵢ
  dμdL = Array{Float64,2}(undef,dim.obs,0)
  dμ̂dL = Array{Float64,2}(undef,dim.obs,0)

  for k=1:dim.Dᵢ
    dμdL = [dμdL Xᵢ[:,k:k].*Dᵢ]
    dμ̂dL = [dμ̂dL X̂ᵢ[:,k:k].*Dᵢ]
  end
  for k=1:dim.νᵢ
    l = dim.Dᵢ + k
    dμdL = [dμdL kron(Xᵢ[:,l:l],ν[k:k,:])]
    dμ̂dL = [dμ̂dL kron(X̂ᵢ[:,l:l],ν[k:k,:])]
  end

  # println([dim.Dᵢ,dim.θ₂,dim.νᵢ,dim.Rᵢ])
  dμdL = reshape(dμdL, (dim.obs,dim.person,dim.θ₂))
  dμ̂dL = reshape(dμ̂dL, (dim.obs,dim.person,dim.θ₂))

  @.mat.νᵢ = ν # Normal random draws
  dμdL3d   = permutedims(dμdL, [1,3,2])
  dμ̂dL3d   = permutedims(dμ̂dL, [1,3,2])

  # Predictions
  s    = [zeros(Float64,dim.prodt[t],) for t=1:dim.market]
  ms   = [zeros(Float64,dim.prodt[t],) for t=1:dim.market]
  mss  = [zeros(Float64,dim.prodt[t],dim.prodt[t]) for t=1:dim.market]
  num  = [zeros(Float64,dim.prodt[t],) for t=1:dim.market]
  den  = [zeros(Float64,dim.person,) for t=1:dim.market]
  adj  = [zeros(Float64,dim.person,) for t=1:dim.market]
  ∂S∂θ = [zeros(Float64,dim.prodt[t],dim.θ₂) for t=1:dim.market]
  pred = predType(s,ms,mss,num,den,adj,∂S∂θ)

  # Fixed point
  eδ1d = dat.ms1d./dat.msOO1d; eδ̂1d = copy(eδ1d)
  eδ = [zeros(Float64,dim.prodt[t],) for t=1:dim.market]

  for t=1:dim.market
    mask = view(indx.mkt,:,t)
    eδ[t] .= eδ1d[mask]
    mat.ms[t] .= dat.ms1d[mask]
    if dim.Dᵢ>0
      mat.X̂[t] .= mat.Xexo[mask,:]
    # else
      # mat.X̂[t] .= [-mat.p̂ʸ[mask] mat.Xexo[mask,:]]
    end
    mat.dμdL[t] .= dμdL3d[mask,:,:]
    mat.dμ̂dL[t] .= dμ̂dL3d[mask,:,:]
  end
  eδ̂ = deepcopy(eδ)
  eμ = [zeros(Float64,dim.prodt[t],dim.person) for t=1:dim.market]
  eμ̂ = [zeros(Float64,dim.prodt[t],dim.person) for t=1:dim.market]
  ∂δ∂θ = [zeros(Float64,dim.prodt[t],dim.θ₂) for t=1:dim.market]
  ∂δ̂∂θ = [zeros(Float64,dim.prodt[t],dim.θ₂) for t=1:dim.market]
  fxp = fxpType(eδ,eδ̂,eδ1d,eδ̂1d,eμ,eμ̂,∂δ∂θ,∂δ̂∂θ)

  # Diags type
  iter     ::Int64 = 0
  iterBLP  ::Int64 = 0
  tolBLP   ::Float64 = 1e-14
  tolOptIV ::Float64 = 1e-8
  gtolSimplex ::Float64 = 1e-6
  gtolBFGS    ::Float64 = 1e-8
  diags = diagsType(iter,iterBLP,tolBLP,tolOptIV,gtolSimplex,gtolBFGS)

  return fxp, pred, diags

end

function setModel(
  model ::Int64,
  Xinput::Matrix{Float64},
  dat   ::datType)

  free    = convert(Vector{Float64},dat.brand.==4)
  prepaid = convert(Vector{Float64},dat.prepost.==1)
  fightbr = convert(Vector{Float64},(dat.brand.>=5) .& (dat.brand.<=7))
  ant4gs  = sum(Xinput[:,5:6],dims=2)
  ant4g   = sum(Xinput[:,5:5],dims=2)
  lowcost = convert(Vector{Float64},(free.==1) .| (fightbr.==1))
  postpay = convert(Vector{Float64},(dat.prepost.==2))
  fbloque = convert(Vector{Float64},(dat.prepost.==3))
  price   = dat.price
  commitl = convert(Vector{Float64},(prepaid==1) .| (lowcost.==1))
  allcall = Xinput[:,9]
  alldata = Xinput[:,10]

  nDᵢ    = 0
  nνᵢ    = 0
  nRᵢ    = 0
  ixP    = [1]
  Xexo   = [Xinput ones(size(Xinput,1))]
  o1     = ones(length(price))
  indxeθ = Vector{Int64}(undef,0)

  if model==0
    Xᵢ = [-price fbloque*10 -ant4gs]
    labΣᵢᵢ = ["Price/y";"Fbloque/y";"Ant4G/y"]
    nDᵢ = 3; nRᵢ = 1
  elseif model==15
    Xᵢ = [-price -ant4gs o1 fbloque*10 prepaid*10]
    labΣᵢᵢ = ["Price/y";"Ant4G/y";"Intercept/y";"Fbloque/y";"Prepaid/y"]
    nDᵢ = 5; nRᵢ = 1
  elseif model==27
    Xᵢ = [-price -ant4gs fbloque    prepaid    o1]
    labΣᵢᵢ = ["Price/y";"Ant4G*ν";"Fbloque*ν";"Prepaid*ν";"Intercept*ν"]
    nDᵢ = 1; nνᵢ = 4; nRᵢ = 5
  else
    error("No model number matched.")
  end

  ### Setting dimensions
  nθ₁   = size(Xexo,2)
  nXᵢ   = size(Xᵢ,2)
  labL  = labΣᵢᵢ
  diagL = collect(1:nXᵢ)
  indxL = [diagL diagL]
  nθ₂   = length(labL)
  nObs  = size(Xᵢ,1)
  nθ    = nθ₁ + nθ₂

  return Xexo,Xᵢ,nXᵢ,nθ₂,nDᵢ,nνᵢ,nRᵢ,labΣᵢᵢ,labL,diagL,indxL,indxeθ,ixP
end

function initialize(
  model   ::Int64,
  iv      ::String,
  nPerson ::Int64,
  ver     ::String,
  impFile ::String,
  simEmp  ::Bool=false;
  lowBound::Bool=false,
  truncate::Bool=false)

  dat, dim, lab, mat, set, indx = importData(model,iv,nPerson,ver,impFile)
  fxp,pred,diags = config!(model,dat,dim,mat,set,indx,simEmp,lowBound,truncate)
  initδ!(fxp.eδ,dat,dim,mat,indx)
  for t=1:dim.market
    if any(isnan.(fxp.eδ[t])) | any(isinf.(fxp.eδ[t]))
      error(" Error: fxp.eδ NaN inside initialize()")
    end
  end
  # println("fxp.eδ initialized inside initialize()")
  return dat, dim, fxp, lab, mat, set, indx, pred, diags
end

function initδ!(
  eδ::Vector{Vector{Float64}},
  dat::datType,
  dim::dimType,
  mat::matType,
  indx::indxType)

  for t=1:dim.market
    mask = view(indx.mkt,:,t)
    @. eδ[t] = mat.ms[t]/dat.msOO1d[mask]
  end
end

function unpackStackedArray(stackedArray::Vector{Matrix{Float64}},
  nRow::Int64, nCol::Int64, nStack::Int64, mask::BitArray{2})

  arr2d = Array{Float64,2}(undef,nRow,nCol)
  for t=1:nStack
    arr2d[view(mask,:,t),:] = stackedArray[t]
  end
  return arr2d
end

function unpackStackedArray!(array2d::Matrix{Float64},
  stackedArray::Vector{Matrix{Float64}}, nStack::Int64, mask::BitArray{2})

  for t=1:nStack
    array2d[view(mask,:,t),:] = stackedArray[t]
  end
end

function unpackStackedArray!(array1d::Vector{Float64},
  stackedArray::Vector{Vector{Float64}}, nStack::Int64, mask::BitArray{2})

  for t=1:nStack
    array1d[view(mask,:,t)] = stackedArray[t]
  end
end

function allocMat!(mat::matType, dim::dimType)
  mat.Z        = Matrix{Float64}(undef,dim.obs,dim.θ)
  mat.XZ       = Matrix{Float64}(undef,dim.θ₁,dim.θ)
  mat.invPhi   = Matrix{Float64}(undef,dim.θ,dim.θ)
  mat.XZPhiZXZ = Matrix{Float64}(undef,dim.θ₁,dim.obs)
end

function updateIVmatrix!(mat::matType)
  mat.Z        .= [mat.∂δ̂∂θ mat.Xexo]
  mat.XZ       .= mat.X'*mat.Z
  mat.invPhi   .= inv(mat.Z'*mat.Z)
  mat.XZPhiZXZ .= (mat.XZ*mat.invPhi*mat.XZ')\(mat.XZ*mat.invPhi*mat.Z')
end

function collectResult(θ₂::Matrix{Float64}, θ₁::Matrix{Float64},
  seθ::Matrix{Float64}, fval::Vector{Float64}, exitflag::BitArray{1})

  # Jstat, idMin = findmin(fval .+ .!(exitflag)*Inf)
  # r = idMin[1]
  # param = paramType(θ₂[:,r],θ₁[:,r],seθ[:,r],Jstat)
  param = paramType(θ₂[:,end],θ₁[:,end],seθ[:,end],fval[end])
  return param
end

function assignFilename(
  fileName::fileNameType,
  model   ::Int64,
  stage   ::Int64,
  iv      ::String,
  nPerson ::Int64,
  impFile ::String)

  pathName = string("out/",impFile,"/m",model,"s",stage,iv,nPerson)
  if ispath(pathName)==true
    rm(pathName, recursive=true)
  end
  mkpath(pathName)

  if stage!=1
    fJLD = string(pathName,"/",fileName.JLD2)
    fCSV = string(pathName,"/",fileName.CSV2)
    fINT = string(pathName,"/",fileName.INT2)
  elseif stage==1
    fJLD = string(pathName,"/",fileName.JLD1)
    fCSV = string(pathName,"/",fileName.CSV1)
    fINT = string(pathName,"/",fileName.INT1)
  end
  fPAR = string(pathName,"/gmmParam.csv")

  return fJLD, fCSV, fINT, fPAR
end

function convert2share(A::Array{Vector{Float64},1}, N::Int64)
  B = Array{SharedArray,1}(N,)
  for n=1:N
    B[n] = convert(SharedArray,A[n])
  end
  return B
end
function convert2share(A::Array{Matrix{Float64},1}, N::Int64)
  B = Array{SharedArray,1}(N,)
  for n=1:N
    B[n] = convert(SharedArray,A[n])
  end
  return B
end

function setIV(
  Xᵢ    ::Matrix{Float64},
  Xexo  ::Matrix{Float64},
  Zinput::Matrix{Float64},
  Dinput::Matrix{Float64},
  price ::Vector{Float64},
  ixP   ::Vector{Int64},
  dim   ::dimType,
  indx  ::indxType,
  iv    ::String)

  z  = hcat(Xexo, Zinput)
  p̂  = z*inv(z'*z)*(z'*price)
  X̂ᵢ = copy(Xᵢ)
  for k in ixP
    X̂ᵢ[:,k] = -p̂ .* (Xᵢ[:,k]./(-price))
  end

  if iv=="opt"
    Z = hcat(randn(dim.obs,dim.θ₂), Xexo)
  elseif iv=="blp"
    Z = z
    @printf("Degrees of freedom: %d\n",size(Z,2)-dim.θ-1)
  elseif (iv=="diff-quad") | (iv=="diff-local")
    # Z = hcat(Xexo, p̂)
    V = hcat(Dinput, p̂)
    D = zero(V)
    for l=1:size(D,2)
      binary = (Set(V[:,l])==Set([0.0,1.0]))
      for t=1:dim.market
        M = view(indx.mkt,:,t)
        x = V[M,l]
        d = x .- x'
        if iv=="diff-quad"
          D[M,l] = sum(d.^2,dims=2)
        elseif iv=="diff-local"
          if binary==false
            dl = d .* (abs.(d) .< std(x))
          else
            dl = d .* (abs.(d) .< std(x))
          end
          D[M,l] = sum(dl,dims=2)
        end
      end
    end
    col0 = vec(sum(abs.(D),dims=1) .!= 0) # Drop zero columns from diff IV
    if iv=="diff-quad"
      Z = hcat(Xexo,D[:,col0])
    elseif iv=="diff-local"
      Z = hcat(Xexo,D[:,col0],p̂)
    end
    @printf("Degrees of freedom: %d\n",size(Z,2)-dim.θ)
    for i in findall(col0.==false)
      @printf("Column %d dropped from Dinput.\n",i)
    end
  end
  return Z, X̂ᵢ, p̂

end

function importθ̂₂(
  model  ::Int64,
  stage  ::Int64,
  mcid   ::Int64,
  iv     ::String,
  nPerson::Int64,
  impF   ::String,
  dim    ::dimType,
  update ::Bool=true)

  if (update==false) & (stage==2)
    pathName = string("out/",impF,"/m",model)
    if iv=="opt"
      if impF=="optIVtest"
        fnameStage1 = string(pathName,"s0opt",nPerson,"/gmmStage2.csv")
      elseif (impF=="optIV1") & (impF=="base")
        fnameStage1 = string(pathName,"s2opt",nPerson,"/gmmStage2.csv")
      elseif (impF=="optIV2") & (impF=="base")
        # fnameStage1 = string("./out/optIV1/m",model,"s2opt","/gmmStage2.csv")
        fnameStage1 = string(pathName,"s2opt",nPerson,"/gmmStage2.csv")
      else
        fnameStage1 = string(pathName,"s1blp",nPerson,"/gmmStage1.csv")
      end
    else
      fnameStage1 = string(pathName,"s1",iv,nPerson,"/gmmStage1.csv")
    end

    imp = readdlm(fnameStage1,',')
    θ̂  = convert(Vector{Float64},imp[mcid,2:(end-2)])
    θ̂₂ = θ̂[1:dim.θ₂]
    println("First stage θ̂₂: ",round.(θ̂₂,digits=4))
  else
    θ̂₂ = zeros(Float64,0)
  end
  return θ̂₂
end

end # end of module
