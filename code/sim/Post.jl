module Post

export getTables, printTable, postMonteCarlo, getDivRatio, exportTable!
export collectElast!, reportElast!, fastElasticity, divRatio_ms15

using TypeDef, Helper, Tools, UserFileIO, Compute, Solve
using JLD, Printf, Statistics, LinearAlgebra

function postMonteCarlo(
  model  ::Int64, # ID for simulated model
  mcid   ::Int64, # ID for Monte Carlo estimate for simulation
  vInt   ::Bool,  # Vertical integration model (in Appendix)
  ms15   ::Bool,  # Market size * 1.5 (in Appendix)
  mc_mvno::Int64, # Margial cost of MVNO (different normalizations)
  saveTab::Bool=false, # Export CSV tables of div ratio & elasticities
  listBS ::Vector{Int64}=[1], # List of bootstrap batches (single by default)
  b1     ::Int64=1,
  b2     ::Int64=200)

  dat,dim,env,mat,par0,set,sim,indx,mask =
    readData(model,mcid,b1,b2,vInt,false,ms15,mc_mvno)
  eqb,pab = collectMC(listBS,model,dim,env,mat,par0)
  tab = getTables(eqb,vInt,dat,dim,env,mat,pab,set,sim,indx,mask)
  printTable(tab,vInt,dat,dim,env,eqb,mat,pab,set,sim,indx,mask,true)
  if saveTab==true
    exportTable!(tab,eqb,dat,dim,env,mat,pab,set,sim,indx,mask,model)
  end

  return dim,eqb,tab
end

function exportTable!(
  tab ::tabType,
  eqb ::Array{Array{equilType,1}},
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  pab ::Array{parType,1},
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType,
  model::Int64)

  lab = setupLab()

  ### Diversion ratio & elasticity
  @printf("\n Exporting Diversion ratio (Table A.3) to divRatio.csv and\n")
  @printf(" elasticity table (Table 3) to elasR.csv.\n")
  println("This will take about 10 minutes.")
  for b in eachindex(eqb)
    tic = time()
    initialize!(mat,dat,dim,pab[b],set)
    tab.divRatio[:,:,b] = getDivRatio(1,eqb[b],dim,lab,mat,pab[b],sim,indx,mask)
    collectElast!(tab,b,eqb[b][1],dim,lab,mat,pab[b],sim,indx,mask)
    @printf("Div. ratio for bootstrap %d complete in %.1f sec.\n",b,time()-tic)
  end

  fname = string(env.pathOut,"/tab.jld")
  jldopen(fname,"w") do file
    addrequire(file,TypeDef)
    write(file,"tab",tab)
  end

  csvname = string(env.pathOut,"/divRatio.csv")
  divRatio = mean(tab.divRatio,dims=3)
  fid = open(csvname,"w")
  @printf(fid,"%8s",lab.product[1])
  for i in lab.prodIdx[2:end]
    @printf(fid,", %8s",lab.product[i])
  end
  @printf(fid,"\n")
  for i=1:size(divRatio,1)
    @printf(fid,"%8.2f",divRatio[i,1])
    for j=2:size(divRatio,2)
      @printf(fid,", %8.2f",divRatio[i,j])
    end
    @printf(fid,"\n")
  end
  close(fid)

  fr = open(string(env.pathOut,"/elasR.csv"),"w")
  fw = open(string(env.pathOut,"/elasW.csv"),"w")
  elasR = mean(tab.elasR,dims=3)
  elasW = mean(tab.elasW,dims=3)
  @printf(fr,"%8s",lab.product[1])
  for i in lab.prodIdx[2:end]
    @printf(fr,", %8s",lab.product[i])
  end
  @printf(fr,"\n")
  for i=1:size(elasR,1)
    @printf(fr,"%8.3f",elasR[i,1])
    for j=2:size(elasR,2)
      @printf(fr,", %8.3f",elasR[i,j])
    end
    @printf(fr,"\n")
  end
  for i=1:dim.product
    @printf(fw,"%8.3f",elasW[i,1])
    for j=2:dim.mvno
      @printf(fw,", %8.3f",elasW[i,j])
    end
    @printf(fw,"\n")
  end
  close(fr)
  close(fw)

  # fx =
  # let sim=deepcopy(sim)
  #   b->getDivRatio(1,eqb[b],dim,mat,pab[b],sim,indx,mask)
  # end
  # pout = pmap(fx, 1:8)
  # return pout

end

function printTable(
  tab  ::tabType,
  vInt ::Bool,
  dat  ::datType,
  dim  ::dimType,
  env  ::envType,
  eqb  ::Array{Array{equilType,1}},
  mat  ::matType,
  pab  ::Array{parType,1},
  set  ::setType,
  sim  ::simType,
  indx ::indxType,
  mask ::maskType,
  elast::Bool=false)

  lab = setupLab()

  @printf("\n------------------ Tables for Model %2d ",env.model)
  @printf("------------------\n")

  if vInt==false
    ### Summary elasticity
    if elast==true
      reportElast!(tab,vInt,env)
    end

    ### Retail markup table
    @printf("\n1. Retail market (Table 6)\n")
    @printf("%10s  %10s  %10s  %8s  %8s\n","Network","Product","Tariff",
            "Price","Markup")

    for i in lab.prodIdx
      f = mat.firm[i,2]
      @printf("%10s  %10s  %10s  ",lab.network[f],lab.product[i],lab.prepost[i])
      @printf("%8.2f  %8.2f\n",tab.retail[i,1],tab.retail[i,2])
    end

    ### Wholesale markup table
    if vInt==false
      @printf("\n2. Wholesale market (Table A.5)\n")
      @printf("%8s  %10s  %28s  %28s  %28s\n","Upstream","Downstream",
              "Wholesale.price","Wholesale.markup","Wholesale.mcost")
      @printf("%8s  %10s  ","network","network")
      for k=1:3
        for j=1:3
          @printf("%8s  ",lab.prepost[j])
        end
      end
      @printf("\n")
      for i=1:3
        @printf("%8s  %10s  ",lab.network[i],"MVNO")
        whsale = tab.whsale[mat.mvno[:,i],:]
        mcMean = mean(tab.mcost[1][mat.mvno[:,i],:],dims=2)
        mcStd  = std(tab.mcost[1][mat.mvno[:,i],:],dims=2)
        for k=1:2
          for j=1:3
            @printf("%8.2f  ",whsale[j,k])
          end
        end
        for j=1:3
          @printf("%8.2f  ",mcMean[j])
        end
        @printf("\n%8s  %10s  ","","")
        for k=3:4
          for j=1:3
            @printf("%8.2f  ",whsale[j,k])
          end
        end
        for j=1:3
          @printf("%8.2f  ",mcStd[j])
        end
        @printf("\n")
      end
    end
  end # end of if vInt==false

  ### Fixed cost table
  @printf("\n3. Fixed Cost Bounds (Table 8/A.13)\n")
  @printf("%10s  %10s  %10s  %10s  %10s  %10s\n",
          "Mean","Lower","Upper","f̄̄","Diff1","Diff2")
  for i=1:3
    lb = mean(tab.fb[i,1,:])
    ub = mean(tab.fb[i,2,:])
    f̄̄  = mean(tab.fb[i,3,:])
    ls = std(tab.fb[i,1,:])
    us = std(tab.fb[i,2,:])
    f̄̄s = std(tab.fb[i,3,:])
    d1 = mean(tab.fb[i,2,:]-tab.fb[i,1,:])
    d2 = mean(tab.fb[i,3,:]-tab.fb[i,1,:])
    s1 = std(tab.fb[i,2,:]-tab.fb[i,1,:])
    s2 = std(tab.fb[i,3,:]-tab.fb[i,1,:])
    @printf("%10s  %10.0f  %10.0f  %10.0f  %10.0f  %10.0f\n",
            lab.network[i],lb,ub,f̄̄,d1,d2)
    @printf("%10s  %10.0f  %10.0f  %10.0f  %10.0f  %10.0f\n",
            "(se)",ls,us,f̄̄s,s1,s2)
  end

  if vInt==false
    @printf("\n4. Fixed Cost Bounds - last 2 quarters only (Table A.18)\n")
    printFixCostBounds(tab.fblast,1,lab)

    @printf("\n4. Fixed Cost Bounds - nonstationary model (Table A.19)\n")
    printFixCostBounds(tab.fbns,1,lab)

    @printf("\n4. Fixed Cost Bounds - nonstationary model (Table A.20)\n")
    printFixCostBounds(tab.fbns,2,lab)

    @printf("\n5. Background conditions (Table A.7)\n")
    @printf("%10s  %10s  %10s  %10s  %10s\n","Operator","Δ","Diff E","Diff N","f̄̄")
    t9mean = mean(tab.t9,dims=3)
    t9std  = std(tab.t9,dims=3)
    for i=1:3
      @printf("%10s  %10.2f",lab.network[i],t9mean[i,1])
      for j=2:4
        @printf("  %10.0f",t9mean[i,j])
      end
      @printf("\n%10s  %10.2f","(se)",t9std[i,1])
      for j=2:4
        @printf("  %10.0f",t9std[i,j])
      end
      @printf("\n")
    end
  end

  ### Joint incentives
  payoff = mean(tab.payoff,dims=3)
  ΔΠ0boot = tab.payoff[7:9,1,:] - tab.payoff[10:12,4,:]
  ΔΠ1boot = tab.payoff[1:3,1,:] - tab.payoff[ 4: 6,4,:]
  ΔΠ0 = mean(ΔΠ0boot,dims=2)
  ΔΠ1 = mean(ΔΠ1boot,dims=2)
  sd0 = std(ΔΠ0boot,dims=2)
  sd1 = std(ΔΠ1boot,dims=2)
  @printf("\n6. Joint incentives for fighting brand (Table A.9/A.11)\n")
  @printf("%10s  %10s  %10s\n","Network","No enter","Enter")
  for i=1:3
    @printf("%10s  %10.0f  %10.0f\n",lab.network[i],ΔΠ0[i],ΔΠ1[i])
    @printf("%10s  %10.0f  %10.0f\n","(se)",sd0[i],sd1[i])
  end
  # ΣΔΠ0 = mean(sum(ΔΠ0boot,dims=1))
  # ΣΔΠ1 = mean(sum(ΔΠ1boot,dims=1))
  # sdΣ0 = std(sum(ΔΠ0boot,dims=1))
  # sdΣ1 = std(sum(ΔΠ1boot,dims=1))
  ΣΔΠ0 = sum(ΔΠ0boot,dims=1)
  ΣΔΠ1 = sum(ΔΠ1boot,dims=1)
  @printf("%10s  %10.0f  %10.0f\n","TotalInc",mean(ΣΔΠ0),mean(ΣΔΠ1))
  @printf("%10s  %10.0f  %10.0f\n","(se)",std(ΣΔΠ0),std(ΣΔΠ1))
  ΔΠf = tab.Πchannel[4,1,:] - tab.Πchannel[4,14,:]
  @printf("%10s  %10.0f  %10.0f\n","Free",0,mean(ΔΠf)/1e6)
  @printf("%10s  %10.0f  %10.0f\n","(se)",0,std(ΔΠf)/1e6)

  ### Unilateral incentives
  @printf("\n7. Unilateral incentives for fighting brand (Table 7/A.12)\n")
  t8 = zeros(3,2,length(eqb));
  t8[1,1,:] = tab.payoff[10,3,:] - tab.payoff[10,4,:];
  t8[2,1,:] = tab.payoff[11,2,:] - tab.payoff[11,4,:];
  t8[3,1,:] = tab.payoff[ 9,4,:] - tab.payoff[12,4,:];
  t8[1,2,:] = tab.payoff[ 1,2,:] - tab.payoff[ 1,1,:];
  t8[2,2,:] = tab.payoff[ 2,3,:] - tab.payoff[ 2,1,:];
  t8[3,2,:] = tab.payoff[ 6,1,:] - tab.payoff[ 3,1,:];
  @printf("%10s  %10s  %10s  %10s\n","Network","No enter","Enter","Diff")
  for i=1:3
    ΔΠuni = t8[i,1,:]+t8[i,2,:]
    @printf("%10s  %10.0f  %10.0f  %10.0f\n",
            lab.network[i],mean(t8[i,1,:]),mean(t8[i,2,:]),mean(ΔΠuni))
    @printf("%10s  %10.0f  %10.0f  %10.0f\n","(se)",
            std(t8[i,1,:]),std(t8[i,2,:]),std(ΔΠuni))
  end
  corrOrange = cor(t8[1,2,:],-t8[1,1,:])
  @printf("Corr(Π(NE),Π(E)) for Orange: %.4f\n",corrOrange)

  ### Surplus
  @printf("\n8. Surplus impacts (Table 9/A.14)\n")
  labRow = ["Free's entry"," Variety"," Price","Fight brands","Total"]
  tsplus = mean(tab.tsplus,dims=3)
  tsplus_se = std(tab.tsplus,dims=3)
  @printf("%12s  %10s  %10s  %10s\n","Source","Consumer","Producer","Total")
  for i=1:5
    @printf("%12s",labRow[i])
    for j=1:3
      @printf("  %10.0f",tsplus[i,j]);
    end
    @printf("\n")
    @printf("%12s","(se)")
    for j=1:3
      @printf("  %10.0f",tsplus_se[i,j]);
    end
    @printf("\n")
  end
  @printf("\n8a. Producer surplus change by groups\n")
  idx_inc = [1,2,3,5,6,7]
  Δpsall  = tab.Πchannel[idx_inc,14,:] - tab.Πchannel[idx_inc,16,:]
  Δpsfree = tab.Πchannel[4,14,:] - tab.Πchannel[4,16,:]
  @printf("%10s  %10.2f\n","Inc+MVNO",sum(mean(Δpsall,dims=2))/1e6)
  @printf("%10s  %10.2f\n","Free",mean(Δpsfree)/1e6)

  ### Payoff matrix
  @printf("\n9. Payoff matrix (Table A.6/A.10)\n")
  payoff = mean(tab.payoff,dims=3)
  for i=1:12
    @printf("%10.0f",payoff[i,1])
    for j=2:4
      @printf("  %10.0f",payoff[i,j]);
    end
    @printf("\n")
  end

  if vInt==false
    ### Price effects
    @printf("\n10. Price effects in retail market (Table A.8)\n")
    Δprice = mean(tab.Δprice,dims=3)
    @printf("%10s  %10s  %10s  %10s  %10s\n","Operator","Product","Retail p",
            "Change(%)","Change")
    for i in lab.prodIdx[1:12]
      @printf("%10s  %10s",lab.product[i],lab.prepost[i])
      for j=1:3
        @printf("  %10.2f",Δprice[i,j])
      end
      @printf("\n")
    end

    ### Price effects
    @printf("\n11. Lerner index & Ebitda in retail market\n")
    lerner = mean(tab.lerner,dims=2)
    ebitda = mean(tab.ebitda,dims=2)
    @printf("%10s  %10s  %10s\n","Operator","Lerner","Ebitda")
    for i=1:4
      @printf("%10s  %10.4f  %10.4f\n",lab.network[i],lerner[i],ebitda[i])
    end
  end
end

function getTables(
  eqb ::Array{Array{equilType,1}},
  vInt::Bool,
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  pab ::Array{parType,1},
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  nBS      = length(eqb)
  payoff   = zeros(4*3,4,nBS)
  Πperiod  = zeros(dim.network,dim.qtr,16,nBS)
  t9       = zeros(3,4,nBS)
  t9last   = zeros(3,4,2,nBS)
  t9ns     = zeros(3,4,2,nBS)
  fb       = zeros(3,3,nBS)
  fblast   = zeros(3,3,2,nBS)
  fbns     = zeros(3,3,2,nBS)
  bound    = zeros(3,2,nBS)
  divR     = zeros(dim.product,dim.product,nBS)
  elasR    = zeros(dim.product,dim.product,nBS)
  elasW    = zeros(dim.product,dim.mvno,nBS)
  Πchannel = zeros(dim.network,16,nBS)
  csplus   = zeros(16,nBS)
  tsplus   = zeros(5,3,nBS)
  Δprice   = zeros(dim.product,3,nBS)
  lerner   = zeros(4,nBS)
  ebitda   = zeros(4,nBS)

  pm = zeros(dim.product,2,nBS)
  wm = zeros(dim.product,2,nBS)
  mcost = [zeros(dim.product,nBS) for k=1:2]
  for b=1:nBS
    eq = eqb[b][1]
    for i=1:dim.product
      idx = findall(eq.price[i,:].>0)
      pm[i,1,b] = mean(eq.price[i,idx])
      if mask.mno[i]
        pm[i,2,b] = mean(eq.price[i,idx] - eq.mcost[2][i,idx])
      elseif mask.mvno[i] & (!vInt)
        pm[i,2,b] = mean(eq.price[i,idx] - eq.wprice[i,idx])
        wm[i,1,b] = mean(eq.wprice[i,idx])
        wm[i,2,b] = mean(eq.wprice[i,idx] - eq.mcost[1][i,idx])
      elseif mask.mvno[i] & vInt
        pm[i,2,b] = mean(eq.price[i,idx] - eq.mcost[2][i,idx])
      end
      mcost[1][i,b] = mean(eq.mcost[1][i,idx])
      mcost[2][i,b] = mean(eq.mcost[2][i,idx])
    end

    for t=1:dim.qtr
      ∑D  = zeros(4)
      ∑mD = zeros(4)
      ∑pD = zeros(4)
      entries = findall(eq.price[1:dim.mno,t].>0)
      for i in entries
        j = mat.firm[i,2]
        ∑D[j] += eq.demand[i,t]
        ∑mD[j] += eq.markup[i,t,2]*eq.demand[i,t]
        ∑pD[j] += eq.price[i,t]*eq.demand[i,t]
      end
      for i in entries
        j = mat.firm[i,2]
        weight = eq.demand[i,t]/∑D[j]
        lerner[j,b] += eq.markup[i,t,2]/eq.price[i,t] * weight / dim.qtr
      end
      for j=1:4
        if ∑pD[j]>0
          ebitda[j,b] += ∑mD[j]/∑pD[j] / dim.qtr
        end
      end
    end
  end
  retail = reshape([mean(pm,dims=3) std(pm,dims=3)],dim.product,4)
  whsale = reshape([mean(wm,dims=3) std(wm,dims=3)],dim.product,4)

  tab = tabType(retail,whsale,mcost,payoff,Πperiod,t9,t9last,t9ns,fb,fblast,
                fbns,bound,divR,elasR,elasW,Πchannel,csplus,tsplus,Δprice,
                lerner,ebitda)

  for b=1:nBS
    ### Equilibrium payoffs
    r      = view(tab.payoff,:,:,b)
    Πchanl = view(tab.Πchannel,:,:,b)
    Πper   = view(tab.Πperiod,:,:,:,b)
    loadPayoff!(r,Πchanl,Πper,eqb[b],vInt,dim,env,mat,sim,indx,mask)

    #### Table: Background condition
    t9 = view(tab.t9,:,:,b)
    CN = r[10:12,4]
    DN = [r[10,3],r[11,2],r[9,4]]
    NN = r[7:9,1]
    CE = r[4:6,4]
    DE = [r[4,3],r[5,2],r[3,4]]
    NE = r[1:3,1]

    @. t9[:,2] = DE - NE  # Diff E
    @. t9[:,3] = DN - NN  # Diff N
    @. t9[:,1] = (DE-CE)/(DE-NE) - (DN-CN)/(DN-NN) # Δ

    # f double bar
    num = zeros(3); den = zeros(3);
    @. num = CE*(DN-NN)-CN*(DE-NE)+DE*NN-DN*NE
    @. den = DE-DN-NE+NN
    @. t9[:,4] = num/den

    ### Table 9: bounds on fixed costs
    fb = view(tab.fb,:,:,b)
    fb[1,1] = r[7,1] - r[10,4]
    fb[2,1] = r[8,1] - r[11,4]
    fb[3,1] = r[9,1] - r[12,4]

    fb[1,2] = r[7,1] - r[ 7,2]
    fb[2,2] = r[8,1] - r[ 8,3]
    fb[3,2] = r[9,1] - r[12,1]

    fb[:,3] = t9[:,4]

    ### Table A.19/A.20: bounds on fixed costs (2-period model)
    nNS = [2,4]
    for t=1:2
      fbns   = view(tab.fbns,  :,:,t,b)
      fblast = view(tab.fblast,:,:,t,b)
      t9ns   = view(tab.t9ns,  :,:,t,b)
      t9last = view(tab.t9last,:,:,t,b)
      getFixCostBounds!(fbns,fblast,t9ns,t9last,Πper,nNS[t],dim)
    end

    ### Collect surplus table
    for i=1:16
      tab.csplus[i,b] = sum(eqb[b][i].csplus)
    end
    tsplus = view(tab.tsplus,:,:,b)
    surplusTable!(tsplus,Πchanl,vInt,eqb[b],dat,dim,env,mat,pab[b],set,sim,
                  indx,mask)

    ### Price difference between endog & exo pricing when Free exits
    Δp = view(tab.Δprice,:,:,b)
    peq = partialBertrand(eqb[b],dat,dim,env,mat,pab[b],set,sim,indx,mask,vInt)
    postEntry = 2:13
    p0    = eqb[b][3].price[:,postEntry]
    rate  = (p0-peq[1].price[:,postEntry])./p0 .* 100
    level = (p0-peq[1].price[:,postEntry])
    rate[rate[:].==0] .= NaN
    level[level[:].==0] .= NaN
    for j=1:dim.product
      Δp[j,1] = mean(skipmissing(p0[j,:]))
      Δp[j,2] = mean(skipmissing(rate[j,:]))
      Δp[j,3] = mean(skipmissing(level[j,:]))
    end

  end # end of b loop

  return tab
end

function surplusTable!(
  tsplus,
  Πchannel,
  vInt::Bool,
  eq  ::Array{equilType,1},
  dat ::datType,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  par ::parType,
  set ::setType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  initialize!(mat,dat,dim,par,set)

  peq = deepcopy(eq[14])
  @. peq.pdline  = eq[16].pdline
  @. peq.price   *= peq.pdline
  @. peq.mcost[1] = eq[1].mcost[1] * peq.pdline
  @. peq.mcost[2] = eq[1].mcost[2] * peq.pdline
  @. peq.wprice  *= peq.pdline

  Πchanlpeq = zeros(dim.network)

  for t=1:dim.qtr
    setupIndex!(sim,indx,peq.pdline,dim,mat,mask,t)
    collectEquil!(peq,t,vInt,peq.mcost,dim,mat,par,sim,indx,mask)
    collectΠ!(Πchanlpeq,peq,vInt,t,dim,mat,indx,mask)
  end

  tsplus[2,1] = sum(eq[14].csplus-peq.csplus)
  tsplus[3,1] = sum(peq.csplus-eq[16].csplus)
  tsplus[2,2] = sum(Πchannel[:,14] - Πchanlpeq)
  tsplus[3,2] = sum(Πchanlpeq - Πchannel[:,16])
  tsplus[1,1] = sum(eq[14].csplus - eq[16].csplus)
  tsplus[1,2] = sum(Πchannel[:,14] - Πchannel[:,16])
  tsplus[4,1] = sum(eq[1].csplus - eq[14].csplus)
  tsplus[4,2] = sum(Πchannel[:,1] - Πchannel[:,14])
  tsplus[5,1] = sum(eq[1].csplus - eq[16].csplus)
  tsplus[5,2] = sum(Πchannel[:,1] - Πchannel[:,16])

  tsplus[:,3] = sum(tsplus[:,1:2],dims=2)
  @. tsplus /= 1e6

end

function loadPayoff!(
  payoff,
  ΠChannel,
  Πperiod,
  eq  ::Array{equilType,1},
  vInt::Bool,
  dim ::dimType,
  env ::envType,
  mat ::matType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  for x=1:16
    Πchanl = view(ΠChannel,:,x)
    for t=1:dim.qtr
    # for t=1:dim.qtr-2  ## Last 2 quarters
      Πper = view(Πperiod,:,t,x)
      setupIndex!(sim,indx,eq[x].pdline,dim,mat,mask,t)
      collectΠ!(Πchanl,eq[x],vInt,t,dim,mat,indx,mask)
      collectΠ!(Πper,  eq[x],vInt,t,dim,mat,indx,mask)
    end # end of t loop
  end # end of x loop
  payoff .= reshape(ΠChannel[1:3,:],4*3,4)/1e6
  # payoff .= reshape(mean(Πperiod[1:3,:,:],dims=2),4*3,4)/1e6 * 13

end

function collectElast!(
  tab ::tabType,
  b   ::Int64,
  eq  ::equilType,
  dim ::dimType,
  lab ::labType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  eR = Array{Union{Missing,Float64}}(missing,dim.product,dim.product,dim.qtr)
  eW = Array{Union{Missing,Float64}}(missing,dim.product,dim.mvno,dim.qtr)

  for t=1:dim.qtr
    eRs = view(eR,:,:,t)
    eWs = view(eW,:,:,t)
    elasticity!(eRs,eWs,t,eq,dim,mat,par,sim,indx,mask)
  end

  elasR = zeros(dim.product,dim.product)
  for j=1:dim.product
    for i=1:dim.product
      elasR[i,j] = mean(skipmissing(eR[i,j,:]))
    end
  end

  elasW = zeros(dim.product,dim.mvno)
  for j=1:dim.mvno
    for i=1:dim.product
      elasW[i,j] = mean(skipmissing(eW[i,j,:]))
    end
  end

  elasR = elasR[:,lab.prodIdx]
  elasR = elasR[lab.prodIdx,:]

  tab.elasR[:,:,b] = elasR
  tab.elasW[:,:,b] = elasW

end

function elasticity!(
  elasR,
  elasW,
  t   ::Int64,
  eq  ::equilType,
  dim ::dimType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  p      = eq.price[:,t]
  wprice = eq.wprice[:,t]
  mcost  = [eq.mcost[1][:,t], eq.mcost[2][:,t]]
  demand!(sim,p,dim,mat,par,indx)
  markupR,markupW,markupV = getMarkup(p,wprice,mcost)
  x = passThrough(markupR,markupW,markupV,dim,mat,sim,indx,mask)
  w = wprice[mask.mvno]

  prodIdx = findall(indx.anyActive)
  for j=1:dim.mvno
    for i in prodIdx #i=1:dim.product
      if sim.D[i]>0
        elasW[i,j] = 0
        for l in prodIdx #l=1:dim.product
          elasW[i,j] += sim.∂D∂p[i,l]*x[l,j]*w[j]/sim.D[i]
        end
      end
    end
  end

  for j in prodIdx #j=1:dim.product
    for i in prodIdx #i=1:dim.product
      if sim.D[i]>0
        elasR[i,j] = sim.∂D∂p[i,j]*p[j]/sim.D[i]
      else
        elasR[i,j] = 0
      end
    end
  end

end

function getDivRatio(
  free::Int64,
  eq  ::Array{equilType,1},
  dim ::dimType,
  lab ::labType,
  mat ::matType,
  par ::parType,
  sim ::simType,
  indx::indxType,
  mask::maskType)

  # dF = Array{Union{Missing,Float64}}(missing,dim.product,dim.product,dim.qtr)
  dF = zeros(dim.product,dim.product,dim.qtr)
  if free==1
    id = 1
  elseif free==0
    id = 3
  end
  for t=1:dim.qtr
    setupIndex!(sim,indx,eq[id].pdline,dim,mat,mask,t)
    p = eq[id].price[:,t]
    D,cs = demandOnly(sim,p,dim,mat,par,indx)
    prodIdx = findall(indx.anyActive)
    for j in prodIdx
      p1 = copy(p)
      p1[j] = p1[j] + 1.0
      D1,cs = demandOnly(sim,p1,dim,mat,par,indx)
      dDown = -(D1[j] - D[j])
      for i in prodIdx
        dD = D1[i] - D[i]
        dF[i,j,t] = dD/dDown
      end
      if sum(skipmissing(dF[:,j,t]))>0
        for i in eachindex(dF[:,j,t])
          @printf("%.4f\n",dF[i,j,t])
        end
      end
    end
    # println(sum(dF[:,:,t],dims=1))
  end

  divRatio = zeros(dim.product,dim.product)
  for j=1:dim.product
    for i=1:dim.product
      divRatio[i,j] = mean(skipmissing(dF[i,j,:]))*100
    end
    if divRatio[j,j] > -100.0
      dRatioOwn = abs(divRatio[j,j])
      for i=1:dim.product
        divRatio[i,j] /= (dRatioOwn/100)
      end
    end
  end
  divRatio = divRatio[:,lab.prodIdx]
  divRatio = divRatio[lab.prodIdx,:]
  return divRatio

end

function reportElast!(
  tab  ::tabType,
  vInt ::Bool,
  env  ::envType)

  m    = env.model
  mcid = env.mcid
  mcv  = env.mc_mvno
  opt  = false
  ms15 = false

  dat,dim,env,mat,par0,set,sim,indx,mask = readData(m,mcid,0,0,vInt,opt,ms15,mcv)
  eq = allocateEquil(dim)
  sim = allocateSim(dim)
  initialize!(mat,dat,dim,par0,set)
  marginalCost!(eq,dat,dim,env,mat,par0,set,sim,indx,mask,vInt)
  bertrandSolve!(eq,dat,dim,env,mat,par0,set,sim,indx,mask,vInt,1)

  lab = setupLab()
  collectElast!(tab,1,eq[1],dim,lab,mat,par0,sim,indx,mask)

  elasOwn = tr(tab.elasR[:,:,1])/dim.product
  elasReg = zeros(dim.region,dim.qtr)

  for t=1:dim.qtr
    p0 = copy(eq[1].price[:,t])
    setupIndex!(sim,indx,eq[1].pdline,dim,mat,mask,t)
    demandOnly(sim,p0,dim,mat,par0,indx)
    tms0 = sum(sim.ms,dims=1)

    p1 = copy(p0)
    @. p1[indx.anyActive] *= 1.01
    demandOnly(sim,p1,dim,mat,par0,indx)
    tms1 = sum(sim.ms,dims=1)
    for i=1:dim.region
      elasReg[i,t] = (tms1[i]-tms0[i])/tms0[i]*100
    end
  end
  elasMarket = mean(elasReg)

  @printf("\nElasticity table\n")
  @printf("%10s  %10s\n","Own","Market")
  @printf("%10.3f  %10.3f\n",elasOwn,elasMarket)

  return elasOwn, elasMarket
end

function fastElasticity(
  model::Int64,
  mcid ::Int64,
  vInt ::Bool,
  ver  ::String="824")

  dat,dim,env,mat,par0,set,sim,indx,mask =
    readData(model,mcid,0,0,vInt,false,false,0;ver)
  eq = allocateEquil(dim)
  sim = allocateSim(dim)
  initialize!(mat,dat,dim,par0,set)
  lab = setupLab()

  eR = Array{Union{Missing,Float64}}(missing,dim.product,dim.product,dim.qtr)

  for t=1:dim.qtr
    setupIndex!(sim,indx,eq[1].pdline,dim,mat,mask,t)
    demand!(sim,sim.p,dim,mat,par0,indx)
    elasRt = view(eR,:,:,t)

    prodIdx = findall(indx.anyActive)
    for j in prodIdx #j=1:dim.product
      for i in prodIdx #i=1:dim.product
        if sim.D[i]>0
          elasRt[i,j] = sim.∂D∂p[i,j]*sim.p[j]/sim.D[i]
        else
          elasRt[i,j] = 0
        end
      end
    end
  end

  elasR = zeros(dim.product,dim.product)
  for j=1:dim.product
    for i=1:dim.product
      elasR[i,j] = mean(skipmissing(eR[i,j,:]))
    end
  end

  elasR = elasR[:,lab.prodIdx]
  elasR = elasR[lab.prodIdx,:]
  elasOwn = tr(elasR)/dim.product

  @printf("\nOwn national demand elasticity (average):\n")
  @printf("%10.3f\n",elasOwn)

  return elasR, elasOwn

end

function getFixCostBounds!(
  fbns,
  fblast,
  t9ns,
  t9last,
  Πper,
  nNS::Int64, # length of nonstationary time periods
  dim::dimType)

  t0 = dim.qtr - nNS

  ### Bounds on fixed costs (2-period model)
  Π0 = reshape(mean(Πper[1:3,2:t0,:], dims=2)[:,1,:],3*4,4) * 12/1e6
  Π1 = reshape(mean(Πper[1:3,(t0+1):dim.qtr,:], dims=2)[:,1,:],3*4,4) * 12/1e6

  CN = hcat(Π0[10:12,4], Π1[10:12,4])
  DN = hcat([Π0[10,3],Π0[11,2],Π0[9,4]], [Π1[10,3],Π1[11,2],Π1[9,4]])
  NN = hcat(Π0[7:9,1], Π1[7:9,1])
  Π̂N = hcat([Π0[7,2],Π0[8,3],Π0[12,1]], [Π1[7,2],Π1[8,3],Π1[12,1]])

  CE = hcat(Π0[4:6,4], Π1[4:6,4])
  DE = hcat([Π0[4,3],Π0[5,2],Π0[3,4]], [Π1[4,3],Π1[5,2],Π1[3,4]])
  NE = hcat(Π0[1:3,1], Π1[1:3,1])

  fbns[:,1] = NN[:,2] - CN[:,2]
  fbns[:,2] = NN[:,2] - Π̂N[:,2]

  aE = CE[:,2] - CE[:,1]
  aN = CN[:,2] - CN[:,1]
  A  = DN[:,1] - NN[:,2] + aN
  B  = DE[:,1] - NE[:,2] + aE

  # δᴱ - δᴺ = Coef_f*f + Δ0 > 0
  Coef_f = zeros(3); Δ0 = zeros(3)
  @. Coef_f = 1/A - 1/B
  @. Δ0 = (DE[:,1]-CE[:,1])/B - (DN[:,1]-CN[:,1])/A
  @. fbns[:,3] = -Δ0./Coef_f

  ### Bounds on fixed costs (last period only)
  @. fblast = fbns

  @. t9last[:,2] = (DE - NE)[:,2]  # Diff E
  @. t9last[:,3] = (DN - NN)[:,2]  # Diff N
  @. t9last[:,1] = ((DE-CE)/(DE-NE) - (DN-CN)/(DN-NN))[:,2] # Δ
  num = zeros(3,2); den = zeros(3,2);
  @. num = CE*(DN-NN)-CN*(DE-NE)+DE*NN-DN*NE
  @. den = DE-DN-NE+NN
  @. t9last[:,4] = (num/den)[:,2]

  @. fblast[:,3] = t9last[:,4]

  #### Table: Background condition (2-period model)
  @. t9ns[:,1] = Δ0
  @. t9ns[:,2] = B
  @. t9ns[:,3] = A
  @. t9ns[:,4] = fbns[:,3]

end

end
