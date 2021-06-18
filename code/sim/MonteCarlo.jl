module MonteCarlo

export simMonteCarlo!, simMonteCarloMulti!, runSim
using TypeDef, Tools, Helper, Solve, UserFileIO
using Printf, JLD, Distributed

function simMonteCarlo!(
  b1  ::Int64,
  b2  ::Int64,
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType,
  set ::setType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  tic = time()
  eqa = allocEqArray(b1,b2,dim)
  for b=b1:b2
    runSim!(eqa,b,b1,dat,dim,env,mat,par0,set,indx,mask,vInt)
  end
  @printf("Total %.0f sec elapsed.\n",time()-tic);
  saveJLD!(eqa,env,env.fileOutp)

  return eqa
end

function simMonteCarloMulti!(
  b1  ::Int64,
  b2  ::Int64,
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType,
  set ::setType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  tic = time()
  eqa = allocEqArray(b1,b2,dim)
  f =
  let dat=deepcopy(dat),mat=deepcopy(mat),indx=deepcopy(indx)
    n->runSim(n,b1,dat,dim,env,mat,par0,set,indx,mask,vInt)
  end
  pout = pmap(f, b1:b2)
  for b in eachindex(pout)
    eqa[b] = pout[b]
  end
  @printf("Total %.0f sec elapsed.\n",time()-tic);
  saveJLD!(eqa,env,env.fileOutp)

  return eqa
end

function runSim(
  b   ::Int64,
  b1  ::Int64,
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType,
  set ::setType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  toc = time()
  par = sampleParam!(b,dim,env,mat,par0)
  # par = par0
  sim = allocateSim(dim)
  eq  = allocateEquil(dim)
  initialize!(mat,dat,dim,par,set)
  marginalCost!(eq,dat,dim,env,mat,par,set,sim,indx,mask,vInt)
  bertrandSolve!(eq,dat,dim,env,mat,par,set,sim,indx,mask,vInt)
  printLog!(b,toc,eq,env.fileLog)
  @printf("σₐ[%3d]: %.4f complete in %.0f sec.\n",b,par.θ₂[1],time()-toc)

  return eq

end

function runSim!(
  eqa ::Array{Array{equilType,1},1},
  b   ::Int64,
  b1  ::Int64,
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par0::parType,
  set ::setType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  toc = time()
  par = sampleParam!(b,dim,env,mat,par0)
  # par = par0
  sim = allocateSim(dim)
  bid = b - b1 + 1
  initialize!(mat,dat,dim,par,set)
  marginalCost!(eqa[bid],dat,dim,env,mat,par,set,sim,indx,mask,vInt)
  bertrandSolve!(eqa[bid],dat,dim,env,mat,par,set,sim,indx,mask,vInt)
  # saveCSV!(b,eqa[bid],dim,env)
  # saveJLD!(eqa,env,env.fileOutp)
  printLog!(b,toc,eqa[bid],env.fileLog)
  @printf("σₐ[%3d]: %.4f complete in %.0f sec.\n",b,par.θ₂[1],time()-toc)

end

end
