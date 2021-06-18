module GMMInterface

export gmmOptim!, gmmOptim1D!, initOptim, gmmOptimMulti!
using TypeDef, Optim, Helper, Estim, UserFileIO, Gmm #Ipopt
using Printf, Random, DelimitedFiles, Distributed
export setupGmmOptim # for debug

function gmmOptimMulti!(
  fName  ::fileNameType, # Names of output files
  model  ::Int64,      # ID for demand model to estimate
  stage  ::Int64,      # Estimation stage (0 if continuous updating)
  iv     ::String,     # IV approach (opt,blp,diff-quad,diff-local)
  ver    ::String,     # Version of estimation data (824 for final version)
  impF   ::String,     # Type of import files
  simEmp ::Bool=false; # Simulation draws from empirical distribution
  update ::Bool=true,  # Continuous updating of optimal instruments
  seed   ::Int64=20,   # Number of Monte Carlo estimation runs
  nPerson::Int64=200,  # Number of simulation draws for random coefficients
  nIter  ::Int64=1000, # Number of iterations for optimization
  mcid   ::Int64=0)    # ID for estimate to import from previous stage (optional)

  θ̂₂,θ₂,θ₁,seθ,fval,exitflag,θ₂seed,dim,lab,indx,fJLD,fCSV,fINT,fPAR =
    setupGmmOptim(fName,model,stage,iv,ver,impF,update,seed,nPerson,nIter,mcid)

  f =
  let
    n->runOptimMulti(n,θ₂seed[:,n],model,stage,iv,update,nPerson,nIter,ver,
                     impF,simEmp,fJLD,fCSV,fINT,mcid,θ̂₂)
  end

  out = pmap(f, 1:seed)
  for r=1:seed
    param = out[r][1]
    flag  = out[r][2]
    timeR = out[r][3]
    csvTable!(fCSV,param.θ₂,param.θ₁,param.Jstat,flag,r,dim)
    saveResult!(fINT,r,param.θ₂,param.Jstat,flag,dim,timeR)
    saveEstim!(fPAR,param,model,timeR,dim,lab,true)
  end
end

function gmmOptim!(
  fName  ::fileNameType,
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool=false;
  update ::Bool=true,
  seed   ::Int64=20,
  nPerson::Int64=200,
  nIter  ::Int64=1000,
  mcid   ::Int64=0)

  θ̂₂,θ₂,θ₁,seθ,fval,exitflag,θ₂seed,dim,lab,indx,fJLD,fCSV,fINT,fPAR =
    setupGmmOptim(fName,model,stage,iv,ver,impF,update,seed,nPerson,nIter,mcid)

  tInit::Float64 = time()
  for r=1:seed
    # Reload fresh data
    param,flag = runOptim(r,θ₂seed[:,r],model,stage,iv,update,nPerson,nIter,
                          ver,impF,simEmp,fJLD,fCSV,fINT,mcid,θ̂₂)
    fval     = [fval; param.Jstat]
    θ₂       = [θ₂ param.θ₂]
    θ₁       = [θ₁ param.θ₁]
    seθ      = [seθ param.seθ]
    exitflag = [exitflag; flag]
    param₀ = collectResult(θ₂,θ₁,seθ,fval,exitflag)
    saveEstim!(fPAR,param₀,model,tInit,dim,lab)
  end
  println("-----------------------------------------------------------------")
  @printf("\nStage %d estimation complete in %.2f sec.\n",stage,time()-tInit)
end

function gmmOptim1D!(
  fName  ::fileNameType,
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool=false;
  update ::Bool=true,
  seed   ::Int64=1,
  nPerson::Int64=200,
  nIter  ::Int64=1000,
  mcid   ::Int64=0)

  θ̂₂,θ₂,θ₁,seθ,fval,exitflag,θ₂seed,dim,lab,indx,fJLD,fCSV,fINT,fPAR =
    setupGmmOptim(fName,model,stage,iv,ver,impF,update,seed,nPerson,nIter,mcid)

  tInit::Float64 = time()
  for r=1:seed
    # Reload fresh data
    param,flag = runOptim(r,model,stage,iv,update,nPerson,nIter,ver,impF,simEmp,
                          fJLD,fCSV,fINT,mcid,θ̂₂)
    fval     = [fval; param.Jstat]
    θ₂       = [θ₂ param.θ₂]
    θ₁       = [θ₁ param.θ₁]
    seθ      = [seθ param.seθ]
    exitflag = [exitflag; flag]
    param₀ = collectResult(θ₂,θ₁,seθ,fval,exitflag)
    saveEstim!(fPAR,param₀,model,tInit,dim,lab)
  end
  println("-----------------------------------------------------------------")
  @printf("\nStage %d estimation completed in %.2f seconds.\n",stage,
          time()-tInit)
end

function initOptim(
  rngSeed::Int64,
  dim::dimType,
  seed::Int64,
  alg::Int64,
  indx::indxType;
  θ̂::Vector{Float64}=zeros(0,))

  θ₂       = Array{Float64,2}(undef,dim.θ₂,0)
  θ₁       = Array{Float64,2}(undef,dim.θ₁,0)
  seθ      = Array{Float64,2}(undef,dim.θ,0)
  fval     = Vector{Float64}(undef,0)
  exitflag = BitArray(undef,0)

  x_L = -5*ones(Float64,dim.θ₂,)
  x_U =  5*ones(Float64,dim.θ₂,)
  for k in indx.diagL
    x_L[k] = 0.0
  end
  # Limit upper bound for price random coefficient
  # if modelType==1
  #   x_U[1] = 5
  # end

  if alg==1 #Ipopt
    m::Int64 = 0
    g_L = Vector{Float64}(undef,0)
    g_U = Vector{Float64}(undef,0)
    nele_jac::Int64 = 0                     # Number of non-zeros in Jacobian
    nele_hess::Int64 = dim.θ₂*(dim.θ₂+1)/2  # Number of non-zeros in Hessian
  elseif alg==2 #Optim
    nothing
  else
    error("Invalid alg input in initOptim")
  end
  Random.seed!(rngSeed)
  θ₂seed = Matrix{Float64}(undef,dim.θ₂,seed)
  u = rand(dim.θ₂,seed)
  for r=1:seed
    for k=1:dim.θ₂
      if length(θ̂)==0
        θ₂seed[k,r] = (x_U[k]-x_L[k])*u[k,r]+x_L[k]
      else
        theta = θ̂[k]+20*(u[k,r]-0.5)
        θ₂seed[k,r] =  min(max(theta, x_L[k]), x_U[k])
      end
    end
  end

  if alg==1
    return θ₂,θ₁,seθ,fval,exitflag,θ₂seed,x_L,x_U,m,g_L,g_U,nele_jac,nele_hess
  elseif alg==2
    return θ₂,θ₁,seθ,fval,exitflag,θ₂seed
  end
end

function runOptim( # multivariate θ
  r      ::Int64,
  θ₂init ::Vector{Float64},
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  update ::Bool,
  nPerson::Int64,
  nIter  ::Int64,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool,
  fJLD   ::String,
  fCSV   ::String,
  fINT   ::String,
  mcid   ::Int64,
  θ̂₂     ::Vector{Float64}) # 1st stage estimate

  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp)
  if (update==false) & (stage==2)
    if iv=="opt" # 2-stage optimal IV
      println("1st stage estim: ", round.(θ̂₂,digits=4))
      setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ̂₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
      fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ̂₂)
      optimIV!(mat,θ̂₂,dat,dim,fxp,indx,pred,diags)
    else
      updateGMMweight!(mat,θ̂₂,dat,dim,fxp,set,indx,pred,diags)
    end
  end
  f(x) = gmmObjOnly(x, dat,dim,fxp,mat,indx,pred,diags,update)

  timeStart = time()
  println("-----------------------------------------------------------------")
  println("Starting Iter ",r," at θ₂: ",round.(θ₂init,digits=4))
  println("\nf(θ₂init): ",round(f(θ₂init),digits=4))

  result = optimize(f,θ₂init,
                    method=NelderMead(),
                    show_trace=false,
                    g_tol=diags.gtolSimplex,
                    iterations=nIter,
                    callback=earlyStop)
  θ₂      = Optim.minimizer(result)
  flag    = Optim.converged(result)
  Jstat   = Optim.minimum(result)
  timeRun = time()-timeStart
  seθ,θ₁,covθ = stdError(θ₂,model,stage,iv,nPerson,impF,update,
                         dat,dim,fxp,mat,set,indx,pred,diags,mcid)


  # csvTable!(fCSV,θ₂,θ₁,Jstat,flag,r,dim)
  printResult!(r,Jstat,θ₂,flag,timeRun)
  # saveResult!(fINT,r,θ₂,Jstat,flag,dim,timeRun)

  param = paramType(θ₂,θ₁,seθ,Jstat)
  return param, flag
end

function runOptim(
  r      ::Int64,
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  update ::Bool,
  nPerson::Int64,
  nIter  ::Int64,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool,
  fJLD   ::String,
  fCSV   ::String,
  fINT   ::String,
  mcid   ::Int64,
  θ̂₂     ::Vector{Float64})

  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp)

  if (update==false) & (stage==2)
    if iv=="opt" # 2-stage optimal IV
      println("1st stage estim: ", round.(θ̂₂,digits=4))
      setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ̂₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
      fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ̂₂)
      optimIV!(mat,θ̂₂,dat,dim,fxp,indx,pred,diags)
    else
      updateGMMweight!(mat,θ̂₂,dat,dim,fxp,set,indx,pred,diags)
    end
  end
  f(x) = gmmObjOnly(x, dat,dim,fxp,mat,indx,pred,diags,update)

  timeStart = time()
  println("-----------------------------------------------------------------")
  result = optimize(f,1e-6,10.0,
                    method=Brent(),
                    show_trace=true,
                    iterations=nIter,
                    callback=earlyStop)
  θ₂      = Optim.minimizer(result)
  flag    = Optim.converged(result)
  Jstat   = Optim.minimum(result)
  timeRun = time()-timeStart
  seθ,θ₁,covθ = stdError([θ₂],model,stage,iv,nPerson,impF,update,
                         dat,dim,fxp,mat,set,indx,pred,diags,mcid)


  csvTable!(fCSV,[θ₂],θ₁,Jstat,flag,r,dim)
  printResult!(r,Jstat,[θ₂],flag,timeRun)
  saveResult!(fINT,r,[θ₂],Jstat,flag,dim,timeRun)

  param = paramType([θ₂],θ₁,seθ,Jstat)
  return param, flag
end

function earlyStop(x::OptimizationState)
  if isnan(x.value) | isinf(x.value)
    println("!!!! GMM objective NaN: ", x.value)
    println("Aborting optimization.\n")
    return true
  end
  return false
end

function runOptimMulti(
  r      ::Int64,
  θ₂init ::Vector{Float64},
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  update ::Bool,
  nPerson::Int64,
  nIter  ::Int64,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool,
  fJLD   ::String,
  fCSV   ::String,
  fINT   ::String,
  mcid   ::Int64,
  θ̂₂     ::Vector{Float64})

  tInit = time()
  param,flag = runOptim(r,θ₂init,model,stage,iv,update,nPerson,nIter,
                        ver,impF,simEmp,fJLD,fCSV,fINT,mcid,θ̂₂)
  timeRun = time()-tInit
  @printf("\nStage %d estimation complete in %.2f sec.\n",stage,timeRun)
  return param, flag, timeRun
end

function setupGmmOptim(
  fName  ::fileNameType,
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  update ::Bool,
  seed   ::Int64,
  nPerson::Int64,
  nIter  ::Int64,
  mcid   ::Int64)

  println("Initializing Model ",model," with ",nPerson," random draws.")
  dim,lab,indx = importData(model,iv,nPerson,ver,impF;output=0)
  println("Estimation sample size: ",dim.obs)
  fJLD,fCSV,fINT,fPAR = assignFilename(fName,model,stage,iv,nPerson,impF)
  initFile!(fCSV,fINT,model,stage,iv,dim,lab)
  fid = open(fPAR,"w")
  close(fid)
  θ₂,θ₁,seθ,fval,exitflag,θ₂seed = initOptim(10+stage,dim,seed,2,indx)
  θ̂₂ = importθ̂₂(model,stage,mcid,iv,nPerson,impF,dim,update)

  return θ̂₂,θ₂,θ₁,seθ,fval,exitflag,θ₂seed,dim,lab,indx,fJLD,fCSV,fINT,fPAR

end

end
