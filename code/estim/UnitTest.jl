module UnitTest

export testIV!, testGmm!, testFixedPoint!, printEstim!, histIncome
using TypeDef, Helper, Estim, Gmm, GMMInterface, Optim, UserFileIO
using Printf, DelimitedFiles, Random, Distributions, Plots

function testIV!(
  model::Int64,  # ID for estimation model
  stage::Int64,  # Estimation stage (0 for continuous updating)
  mcid ::Int64,  # ID for Monte Carlo estimation
  iv   ::String, # IV approach
  ver  ::String, # Version of estimation data
  impF ::String, # Type of import files
  simEmp=false;  # Simulation draws from empirical distribution
  nPerson=200,   # Number of simulation draws
  stageGmm=2,    # Parameter for output file
  lowBound=true) # Lower bound for simulation draws for robust simulation

  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp;lowBound)

  # Export for testing δ
  pathName = string("out/",impF,"/m",model,"s",stage,iv,nPerson)
  imp = readdlm(string(pathName,"/gmmStage",stageGmm,".csv"),',')
  θ = convert(Vector{Float64},imp[mcid,2:(end-2)])
  θ₂ = θ[1:dim.θ₂]
  setupMu!(fxp.eμ,pred.eμ₀,pred.adj, θ₂,mat.Xᵢ,mat.Dᵢ,mat.νᵢ,dim,indx)
  fixPoint!(fxp.eδ,fxp.∂δ∂θ, fxp.eμ,dat,dim,mat,indx,pred,diags,θ₂)
  unpackStackedArray!(fxp.eδ1d, fxp.eδ, dim.market, indx.mkt)
  fid = open(string(pathName,"/expDelta.csv"),"w")
  for i=1:dim.obs
    @printf(fid,"%.15f\n",fxp.eδ1d[i])
  end
  close(fid)

  if iv=="opt"
    optimIV!(mat,θ₂,dat,dim,fxp,indx,pred,diags)
  end
  # Export for Sanderson-Windmeijer test
  ∂δ∂θ₂ = zeros(dim.obs,dim.θ₂)
  for t=1:dim.market
    ∂δ∂θ₂[indx.mkt[:,t],:] = fxp.∂δ∂θ[t]
  end
  fid = open(string(pathName,"/swtest_",iv,".csv"),"w")
  @printf(fid,"%8s, %8s, %8s, %24s, %24s",
          "network","region","quarter","delta","price")
  for j=1:dim.θ₂
    @printf(fid,", %24s",string("jacob",j))
  end
  for j=1:size(mat.Xexo,2)
    @printf(fid,", %24s",string("x",j))
  end
  for j=1:(size(mat.Z,2)-size(mat.Xexo,2))
    @printf(fid,", %24s",string("z",j))
  end
  @printf(fid,"\n")
  for i=1:dim.obs
    @printf(fid,"%8d, %8d, %8d, ",dat.brand[i],dat.region[i],dat.qtr[i])
    @printf(fid,"%24.15f, %24.15f",log(fxp.eδ1d[i]),dat.price[i])
    for j=1:dim.θ₂
      @printf(fid,", %24.15f",∂δ∂θ₂[i,j])
    end
    for j=1:size(mat.Z,2)
      @printf(fid,", %24.15f",mat.Z[i,j])
    end
    @printf(fid,"\n")
  end
  close(fid)

  println("Export complete.")
end

function printEstim!(
  model  ::Int64,
  stage  ::Int64,
  mcid   ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  update ::Bool=true,
  mcid1st::Int64=0,
  nPerson::Int64=200,
  simEmp ::Bool=false)

  dim,lab,indx = importData(model,iv,nPerson,ver,impF;output=0)
  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp)
  pathName = string("out/",impF,"/m",model,"s",stage,iv,nPerson)
  imp = readdlm(string(pathName,"/gmmStage2.csv"),',')
  θ = convert(Vector{Float64},imp[mcid,2:(end-2)])
  θ₂ = θ[1:dim.θ₂]

  seθ,θ₁,covθ = stdError(θ₂,model,stage,iv,nPerson,impF,update,
                         dat,dim,fxp,mat,set,indx,pred,diags,mcid1st)
  # println(seθ)
  Jstat::Float64 = 0
  θ[1] *= -1;
  if model==0
    θ[2] *= 10; seθ[2] *= 10;
    θ[3] *= -1;
  elseif model==15
    θ[2] *= -1;
    θ[4] *= 10; seθ[4] *= 10;
    θ[5] *= 10; seθ[5] *= 10;
  elseif model==27
    θ[2] *= -1;
  end
  param = paramType(θ₂,θ₁,seθ,Jstat)
  nameParam = [lab.L; lab.θ₁]
  fid = open(string(pathName,"/estimLatex.csv"),"w")
  for i=1:dim.θ
    z = abs(θ[i])/param.seθ[i]
    @printf(fid,"%18s,  %.3f",nameParam[i],θ[i])
    if z > 2.575829
      @printf(fid,"***");
    elseif z > 1.959964
      @printf(fid,"**");
    elseif z > 1.644854
      @printf(fid,"*");
    end
    @printf(fid,"\n%18s, (%.3f)\n"," ",param.seθ[i])
  end
  close(fid)

end

function histIncome(
  fName  ::fileNameType,
  model  ::Int64,
  stage  ::Int64,
  iv     ::String,
  ver    ::String,
  impF   ::String,
  simEmp ::Bool,
  figName::String;
  update ::Bool=true,
  seed   ::Int64=20,
  nPerson::Int64=200,
  nIter  ::Int64=1000,
  mcid   ::Int64=0)

  # update=true;seed=20; nPerson=200; nIter=1000;mcid=0
  # stage=0;iv="opt";impF="base";fName=fileName
  θ̂₂,θ₂,θ₁,seθ,fval,exitflag,θ₂seed,dim,lab,indx,fJLD,fCSV,fINT,fPAR =
    setupGmmOptim(fName,model,stage,iv,ver,impF,update,seed,nPerson,nIter,mcid)

  dat,dim,fxp,lab,mat,set,indx,pred,diags =
    initialize(model,iv,nPerson,ver,impF,simEmp)

  y = mat.y[dat.region.==11,:]*100
  histogram(y[1,:],normed=true,xlabel="Monthly income (€)",
            ylabel="Probability",label="Income draws")
  savefig(string("post/",figName,".pdf"))
  histogram(1 ./ y[1,:],normed=true,xlabel="Inverse income (€)",
            ylabel="Probability",label="Income draws")
  savefig(string("post/",figName,"Inv.pdf"))

end

end
