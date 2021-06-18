module Solve

export marginalCost!, bertrandSolve!, partialBertrand, collectEquil!
using TypeDef, Helper, Tools, Compute, FOCs, UserFileIO
using NLsolve, Printf

function bertrandSolve!(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false,
  nEq ::Int64=16)

  if any(eq[1].fail) # Skip if marginal cost solution failed
    @printf("Terminating bertrandSolve!\n")
    return
  end

  if vInt==false
    game2stages!(eq,dat,dim,env,mat,par,set,sim,indx,mask,nEq)
  else
    game1stage!(eq,dat,dim,env,mat,par,set,sim,indx,mask,nEq)
  end
end

function partialBertrand2(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  peq = deepcopy(eq[14]) # Market without Fight brands
  @. peq.mcost = eq[1].mcost
  for j=1:dim.product
    if j!=10
      peq.price[j] = eq[16].price[j] * peq.pdline[j]
    end
  end

  sim = allocateSim(dim)
  for t=1:dim.qtr
    setupIndex!(sim,indx,peq.pdline,dim,mat,mask,t)
    for j=1:dim.product
      if j!=10
        indx.anyActive[j] = false
      end
    end
    mc = [peq.mcost[1][:,t], peq.mcost[2][:,t]]
    if any(indx.anyActive)
      p0 = peq.price[indx.anyActive,t]
      pj = peq.price[:,t]
      wp = peq.wprice[:,t]
      foc2(x) = foc_retailPartial(x,pj,wp,mc,dim,mat,par,sim,indx,mask)
      stage2 = nlsolve(foc2,p0)
      peq.price[indx.anyActive,t] = stage2.zero
    end
    collectEquil!(peq,t,vInt,peq.mcost,dim,mat,par,sim,indx,mask)
  end

  return peq
end

function partialBertrand(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  peq = [deepcopy(eq[1]) for i=1:3]
  @. peq[1].pdline = eq[ 3].pdline  # Market without Free
  @. peq[2].pdline = eq[16].pdline  # Market without Free & Fight brands
  @. peq[3].pdline = eq[14].pdline  # Market without Fight brands

  for i=1:3
    for j=1:dim.product
      peq[i].price[j] = peq[i].price[j] * peq[i].pdline[j]
    end
  end

  for i=1:2
    for t=1:dim.qtr
      setupIndex!(sim,indx,peq[i].pdline,dim,mat,mask,t)
      collectEquil!(peq[i],t,vInt,peq[1].mcost,dim,mat,par,sim,indx,mask)
    end
  end

  i=3
  sim = allocateSim(dim)
  for t=1:dim.qtr
    setupIndex!(sim,indx,peq[i].pdline,dim,mat,mask,t)
    for j=1:dim.product
      if j!=10
        indx.anyActive[j] = false
      end
    end
    mc = [peq[1].mcost[1][:,t], peq[1].mcost[2][:,t]]
    if any(indx.anyActive)
      p0 = peq[1].price[indx.anyActive,t]
      pj = peq[1].price[:,t]
      wp = peq[1].wprice[:,t]
      foc2(x) = foc_retailPartial(x,pj,wp,mc,dim,mat,par,sim,indx,mask)
      stage2 = nlsolve(foc2,p0)
      peq[i].price[indx.anyActive,t] = stage2.zero
    end
    collectEquil!(peq[i],t,vInt,peq[1].mcost,dim,mat,par,sim,indx,mask)
  end

  return peq
end

function game2stages!(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  nEq ::Int64=16)

  for i=1:nEq
    eq[i].fail .= false
    tic = time()
    for t=1:dim.qtr
      setupIndex!(sim,indx,eq[i].pdline,dim,mat,mask,t)
      wprice0 = eq[1].wprice[indx.mvno,t]
      # mcost   = eq[1].mcost[:,t]
      mcost   = [eq[1].mcost[1][:,t], eq[1].mcost[2][:,t]]
      f0      = zeros(sum(indx.anyActive[mask.mvno]))
      fail    = eq[i].fail[t:t]
      foc1(f,x) = foc_whsale!(f,x,sim.p,mcost,fail,dim,mat,par,sim,indx,mask)
      df = OnceDifferentiable(foc1,wprice0,f0,autodiff=:finiteforward)
      stage1 = nlsolve(df,wprice0,iterations=100)
      iter = 1
      while (checkConvg(iter,stage1,fail[1])==false) & (iter<=2)
        fail .= false
        @printf("Re-solving the foc_whsale for %d times....\n",iter+1)
        stage1 = nlsolve(foc1,wprice0+2randn(length(wprice0)),iterations=100)
        iter += 1
      end
      eq[i].fail[t] = (checkConvg(iter,stage1,fail[1])==false)
      if eq[i].fail[t]
        @printf("Solving foc_whsale failed %d times.\n",iter)
        @printf("Exiting bertrandSolve!.\n")
        break
      end
      eq[i].wprice[indx.mvno,t] = stage1.zero

      foc2(x) = foc_retail(x,mcost,eq[i].wprice[:,t],dim,mat,par,sim,indx,mask)
      p0 = view(sim.p,indx.anyActive)
      stage2 = nlsolve(foc2,p0)

      eq[i].price[indx.anyActive,t] = stage2.zero
      collectEquil!(eq[i],t,false,eq[1].mcost,dim,mat,par,sim,indx,mask)
      # @printf("Equil %2d Qtr %2d complete in %.1f seconds.\n",i,t,time()-tic)
    end
    if any(eq[i].fail)
      @printf("Simulating equil %2d failed.\n",i)
      break
    else
      @printf("Equil %2d complete in %.1f seconds.\n",i,time()-tic)
    end
  end # end of i loop
end

function game1stage!(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  nEq ::Int64=16)

  for i=1:nEq
    eq[i].fail .= false
    # tic = time()
    for t=1:dim.qtr
      setupIndex!(sim,indx,eq[i].pdline,dim,mat,mask,t)
      # mcost   = eq[1].mcost[:,t]
      mcost   = [eq[1].mcost[1][:,t], eq[1].mcost[2][:,t]]
      p0      = sim.p[indx.anyActive]
      f0      = zeros(sum(indx.anyActive))
      fail    = eq[i].fail[t:t]
      foc(f,x) = foc_retailV!(f,x,mcost,dim,mat,par,sim,indx,mask)
      df = OnceDifferentiable(foc,p0,f0,autodiff=:finiteforward)
      stage1 = nlsolve(df,p0,iterations=100)
      iter = 1
      while (checkConvg(iter,stage1,fail[1])==false) & (iter<=2)
        fail .= false
        @printf("Re-solving the foc_retailV for %d times....\n",iter+1)
        stage1 = nlsolve(foc,p0+2randn(length(p0)),iterations=100)
        iter += 1
      end
      eq[i].fail[t] = (checkConvg(iter,stage1,fail[1])==false)
      if eq[i].fail[t]
        @printf("Solving foc_retailV failed %d times.\n",iter)
        @printf("Exiting bertrandSolve!.\n")
        break
      end
      eq[i].price[indx.anyActive,t] = stage1.zero

      D, csplus = demandOnly(sim,eq[i].price[:,t],dim,mat,par,indx)
      eq[i].demand[:,t] = D
      eq[i].csplus[t] = csplus
      eq[i].markup[:,t,2] = eq[i].price[:,t] - mcost[2]
      @. eq[i].profit[:,t,2] = 3D * eq[i].markup[:,t,2]
      # @printf("Equil %2d Qtr %2d complete in %.1f seconds.\n",i,t,time()-tic)
    end
    if any(eq[i].fail)
      @printf("Simulating equil %2d failed.\n",i)
      break
    else
      # @printf("Equil %2d complete in %.1f seconds.\n",i,time()-tic)
    end
  end # end of i loop

end

function marginalCost!(
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  vInt::Bool=false)

  for t=1:dim.qtr
    if vInt==false
      mc!(eq,t,dim,env,mat,par,sim,indx,mask)
    else
      mcvInt!(eq,t,dim,env,mat,par,sim,indx,mask)
    end
  end

end

function mc!(
  eq  ::Array{equilType,1},
  t   ::Int64,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  tic = time()
  setupIndex!(sim,indx,eq[1].pdline,dim,mat,mask,t)
  demand!(sim,sim.p,dim,mat,par,indx)
  wprice = whsaleprice(sim.p,dim,mat,sim,indx)

  mcostfree = wprice[mask.free]
  mcostinc0 = wprice[indx.anyActive .& .!mask.free]

  foc(x) = foc_mcost(x,mcostfree,sim.p,wprice,dim,mat,par,sim,indx,mask)
  result = nlsolve(foc,mcostinc0,autodiff=:finiteforward)
  mcost  = mergeMcosts(result.zero,mcostfree,dim,indx,mask)

  fail = eq[1].fail[t:t]
  foc1(f,x) = foc_whsale!(f,x,sim.p,mcost,fail,dim,mat,par,sim,indx,mask)
  Op = nlsolve(foc1,wprice[indx.mvno],autodiff=:finiteforward)
  d = maximum(abs.(Op.zero - wprice[indx.mvno]))
  if (d<1e-6) & converged(Op)
    @printf("Test passed for market %d in %.1f sec.\n",t,time()-tic)
    if env.mc_mvno==0      # MVNO's marginal cost = 0
      # eq[1].mcost[1][:,t] = mcost
      mcostmvno = zeros(sum(indx.mvno))
    elseif env.mc_mvno==1  # MVNO's marginal cost = 10% of wholesale price
      mcostmvno = 0.1*wprice[indx.mvno]
    elseif env.mc_mvno==2  # MVNO's marginal cost = 5% of retail price
      mcostmvno = 0.05*sim.p[indx.mvno]
    end
    eq[1].mcost[2][indx.mno, t] = mcost[2][indx.mno]
    eq[1].mcost[2][indx.mvno,t] = mcostmvno
    eq[1].mcost[1][indx.mvno,t] = mcost[1][indx.mvno] - mcostmvno
    eq[1].wprice[indx.mvno,t]   = wprice[indx.mvno]- mcostmvno
  else
    @printf("Test failed in mc! Markups not matching\n")
    eq[1].fail .= true
    return
  end
end

function mcvInt!(
  eq  ::Array{equilType,1},
  t   ::Int64,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  tic = time()
  setupIndex!(sim,indx,eq[1].pdline,dim,mat,mask,t)
  demandD1only!(sim,sim.p,dim,mat,par,indx)
  mcost  = [zeros(dim.product) for t=1:2]
  any = indx.anyActive
  Ds = sim.∂D∂p' .* mat.host
  mcost[2][any] = sim.p[any] + Ds[any,any]\sim.D[any]

  # Test validity
  foc(f,x) = foc_retailV!(f,x,mcost,dim,mat,par,sim,indx,mask)
  Op = nlsolve(foc,sim.p[indx.anyActive],autodiff=:finiteforward)
  d = maximum(abs.(Op.zero - sim.p[indx.anyActive]))
  if (d<1e-6) & converged(Op)
    # @printf("Test passed for market %d in %.1f sec.\n",t,time()-tic)
    eq[1].mcost[2][:,t] = mcost[2]
  else
    @printf("Test failed in mcvInt! Markups not matching\n")
    eq[1].fail .= true
    return
  end
end

function collectEquil!(
  eq  ::equilType,
  t   ::Int64,
  vInt::Bool,
  mc  ::Vector{Matrix{Float64}},
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  p  = eq.price[:,t]
  w  = eq.wprice[:,t]

  D, csplus = demandOnly(sim,p,dim,mat,par,indx)

  for i=1:dim.product
    if indx.anyActive[i]
      if mask.mno[i]
        eq.markup[i,t,1] = 0
        eq.markup[i,t,2] = p[i] - mc[2][i,t]
      elseif mask.mvno[i]
        if vInt==false
          eq.markup[i,t,1] = w[i] - mc[1][i,t]
          eq.markup[i,t,2] = p[i] - w[i] - mc[2][i,t]
        else
          eq.markup[i,t,2] = p[i] - mc[2][i,t]
        end
      end
      eq.demand[i,t]   = D[i]
      eq.profit[i,t,1] = 3D[i] * eq.markup[i,t,1]
      eq.profit[i,t,2] = 3D[i] * eq.markup[i,t,2]
    end
  end
  eq.csplus[t] = csplus

  # mRetail = price - mcost
  # mRetail[mask.mvno] = price[mask.mvno] - wprice[mask.mvno]
  # mWhsale = wprice - mcost
  # mWhsale[mask.mno] .= 0
end

end
