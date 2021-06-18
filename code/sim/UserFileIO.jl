module UserFileIO

export loadCSV, saveCSV!, saveJLD!, loadJLD, printLog!, collectMC
export printFixCostBounds
using TypeDef, Helper
using Printf, Dates, JLD, CSV, DataFrames, DelimitedFiles, Statistics

function loadCSV(
  mcPath,
  dim::dimType)

  fname = ["eq1d","eq2d","eq3d"]
  fullName = string(mcPath,b,"/",fname[1],".csv")
  DF = CSV.File(fullName; header=false) |> DataFrame!
  nBS = length(unique(DF[:,1]))
  eqArray = Array{Array{equilType,1},1}(undef,nBS)
  for n=1:size(DF,1)
    b = DF[n,1]
    q = DF[n,2]
    b0 = minimum(DF[:,1])
    eq = allocateEquil(dim)
    eq[q].csplus .= DF[n,2 .+ (1:dim.qtr)]
    eq[q].fail   .= DF[n,2+dim.qtr .+ (1:dim.qtr)]
    eqArray[b-b0+1] = deepcopy(eq)
  end
  return eqArray

end

function saveCSV!(
  b   ::Int64,
  eq  ::Array{equilType,1},
  dim ::dimType,
  env ::envType)

  io3d = open(string(env.pathOut,"eq3d.csv"),"a")
  for q in eachindex(eq)
    for k=1:2
      for i=1:dim.product
        @printf(io3d,"%3d, %2d, %1d, %2d",b,q,k,i)
        for t=1:dim.qtr
          @printf(io3d,", %15.2f",eq[q].profit[i,t,k])
        end
        for t=1:dim.qtr
          @printf(io3d,", %10.4f",eq[q].markup[i,t,k])
        end
        @printf(io3d,"\n")
      end
    end
  end
  close(io3d)

  io2d = open(string(env.pathOut,"eq2d.csv"),"a")
  for q in eachindex(eq)
    for i=1:dim.product
      @printf(io2d,"%3d, %2d, %2d",b,q,i)
      for t=1:dim.qtr
        @printf(io2d,", %10.0f",eq[q].demand[i,t])
      end
      for t=1:dim.qtr
        @printf(io2d,", %10.4f",eq[q].price[i,t])
      end
      for t=1:dim.qtr
        @printf(io2d,", %10.4f",eq[q].wprice[i,t])
      end
      for t=1:dim.qtr
        @printf(io2d,", %10.4f",eq[q].mcost[i,t])
      end
      @printf(io2d,"\n")
    end
  end
  close(io2d)

  io1d = open(string(env.pathOut,"eq1d.csv"),"a")
  for q in eachindex(eq)
    @printf(io1d,"%3d, %2d",b,q)
    for t=1:dim.qtr
      @printf(io1d,", %21.6f",eq[q].csplus[t])
    end
    for t=1:dim.qtr
      @printf(io1d,", %2d",Int(eq[q].fail[t]))
    end
    @printf(io1d,"\n")
  end
  close(io1d)

end

function saveJLD!(
  eqa::Array{Array{equilType,1},1},
  env::envType,
  filename::String,
  optFull::Bool=false)

  D = Dict([("eqa",eqa),("env",env)])

  if isfile(filename)==true
    rm(filename)
  end
  jldopen(filename,"w") do file
    addrequire(file,TypeDef)
    write(file,"D",D)
  end

end

function loadJLD(
  fileJLD::String,
  optFull::Bool=false)

  D = jldopen(fileJLD,"r") do file
    read(file,"D")
  end

  if optFull==true
    eqa = D["eqa"]
    dat = D["dat"]
    dim = D["dim"]
    env = D["env"]
    mat = D["mat"]
    par = D["par"]
    set = D["set"]
    sim = D["sim"]
    indx = D["indx"]
    mask = D["mask"]
    return eqa,dat,dim,env,mat,par,set,sim,indx,mask
  else
    eqa = D["eqa"]
    env = D["env"]
    return eqa,env
  end

end

function collectMC(
  listBoot::Vector{Int64},
  model   ::Int64,
  # vInt    ::Bool,
  # mc_mvno ::Int64,
  dim     ::dimType,
  env     ::envType,
  mat     ::matType,
  par0    ::parType)

  @printf("\n--------------- Collecting Bootstrap samples for Model %2d ",model)
  @printf("---------------\n")

  δ   = zeros(dim.obs)
  eqb = Array{Array{equilType,1},1}(undef,0)
  pab = Array{parType,1}(undef,0)
  imp    = readdlm(string(env.pathImp,"/paramDraws.csv"),',')

  for b in listBoot # Batch loading
    fileJLD = string(env.pathOut,"sim",env.ver,".jld")
    eqa,env = loadJLD(fileJLD)
    for i in eachindex(eqa) # each bootstrap
      fail = false
      for j in eachindex(eqa[i])
        fail = fail | any(eqa[i][j].fail)
      end

      par = sampleParam!(b+i-1,imp,dim,env,mat,par0)
      if fail==false
        eqb = [eqb; [eqa[i]]]
        pab = [pab; par]
      else
        @printf("Failed mc %3d: α = %.4f\n",b+i-1,par.θ₂[1])
      end
    end
  end
  @printf("\nSummary: %d bootstrap samples collected.\n",length(eqb))
  return eqb, pab
end

function printLog!(
  b,
  tic,
  eq     ::Array{equilType,1},
  fileLog::String)

  fail = false
  for i=1:16
    fail = (fail | any(eq[i].fail))
  end
  fid = open(fileLog,"a")
  if fail==false
    @printf(fid,"Monte Carlo %3d succeded in %.0f sec.\n",b,time()-tic)
  else
    @printf(fid,"Monte Carlo %3d failed in %.0f sec.\n",b,time()-tic)
  end
  close(fid)
end

function printFixCostBounds(
  tabfb,
  t  ::Int64,
  lab::labType)

  @printf("%10s  %10s  %10s  %10s\n","Mean","Lower","Upper","f̄̄")
  for i=1:3
    lb = mean(tabfb[i,1,t,:])
    ub = mean(tabfb[i,2,t,:])
    f̄̄  = mean(tabfb[i,3,t,:])
    ls = std(tabfb[i,1,t,:])
    us = std(tabfb[i,2,t,:])
    f̄̄s = std(tabfb[i,3,t,:])
    d1 = mean(tabfb[i,2,t,:]-tabfb[i,1,t,:])
    d2 = mean(tabfb[i,3,t,:]-tabfb[i,1,t,:])
    s1 = std(tabfb[i,2,t,:]-tabfb[i,1,t,:])
    s2 = std(tabfb[i,3,t,:]-tabfb[i,1,t,:])
    @printf("%10s  %10.0f  %10.0f  %10.0f  %10.0f  %10.0f\n",
            lab.network[i],lb,ub,f̄̄,d1,d2)
    @printf("%10s  %10.0f  %10.0f  %10.0f  %10.0f  %10.0f\n",
            "(se)",ls,us,f̄̄s,s1,s2)
  end

end


end # end of module
