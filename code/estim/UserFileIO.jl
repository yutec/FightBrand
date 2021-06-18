module UserFileIO

export saveResult!, printResult!, saveEstimGlobal!, loadResult, initFile!,
  csvTable!, saveData!, saveEstim!
using TypeDef, JLD, Optim
using Printf, Dates

function saveData!(fJLD::String, model::Int64,
  dat::datType, dim::dimType, fxp::fxpType, lab::labType, mat::matType,
  set::setType, indx::indxType, pred::predType, diags::diagsType)

  D = Dict([("model",model),
            ("dat",dat),("dim",dim),("fxp",fxp),("lab",lab),("mat",mat),
            ("set",set),("indx",indx),("pred",pred),("diags",diags)])
  if isfile(fJLD)==true
    rm(fJLD)
  end
  jldopen(fJLD,"w") do file
    addrequire(file,TypeDef)
    write(file,"D",D)
  end

end

function saveEstimGlobal!(fJLD::String, fCSV::String,
  param::paramType, model::Int64, intNum::Int64, nIter::Int64, tInit::Float64,
  dat::datType, dim::dimType, fxp::fxpType, lab::labType, mat::matType,
  set::setType, indx::indxType, pred::predType, diags::diagsType)

  D = Dict([("θ₂",param.θ₂),("θ₁",param.θ₁),("seθ",param.seθ),("Jstat",param.Jstat),
            ("model",model),("intNum",intNum),("nIter",nIter),
            ("dat",dat),("dim",dim),("fxp",fxp),("lab",lab),("mat",mat),
            ("set",set),("indx",indx),("pred",pred),("diags",diags)])

  if isfile(fJLD)==true
    rm(fJLD)
  end
  jldopen(fJLD,"w") do file
    addrequire(file,TypeDef)
    write(file,"D",D)
  end

  nameParam = [lab.L; lab.θ₁]
  θ  = [param.θ₂; param.θ₁]
  fid = open(fCSV,"w")
  for i=1:dim.θ
    z = abs(θ[i])/param.seθ[i]
    @printf(fid,"%18s,  %.4f",nameParam[i],θ[i])
    if z > 2.575829
      @printf(fid,"***");
    elseif z > 1.959964
      @printf(fid,"**");
    elseif z > 1.644854
      @printf(fid,"*");
    end
    @printf(fid,"\n%18s, (%.4f)\n"," ",param.seθ[i])
  end
  @printf(fid,"%18s, %d\n","Observations",dim.obs)
  @printf(fid,"%18s, %.8f\n","J statistic",param.Jstat)
  @printf(fid,"%18s, %d\n","D.F.",size(mat.Z,2)-dim.θ)
  @printf(fid,"%18s, %d\n","Model",model)
  @printf(fid,"%18s, %d\n","Sim. draws",dim.person)
  @printf(fid,"%18s, %.2f\n\n","Run time",time()-tInit)

  @printf(fid,"Point estimates\n")
  for i=1:dim.θ
    @printf(fid,"%.16f\n",θ[i])
  end
  close(fid)
end

function saveEstim!(
  fCSV::String,
  param::paramType,
  model::Int64,
  tInit::Float64,
  dim::dimType,
  lab::labType,
  optMulti::Bool=false)

  nameParam = [lab.L; lab.θ₁]
  θ  = [param.θ₂; param.θ₁]
  fid = open(fCSV,"a")
  for i=1:dim.θ
    z = abs(θ[i])/param.seθ[i]
    @printf(fid,"%18s,  %.4f",nameParam[i],θ[i])
    if z > 2.575829
      @printf(fid,"***");
    elseif z > 1.959964
      @printf(fid,"**");
    elseif z > 1.644854
      @printf(fid,"*");
    end
    @printf(fid,"\n%18s, (%.4f)\n"," ",param.seθ[i])
  end
  @printf(fid,"%18s, %d\n","Observations",dim.obs)
  @printf(fid,"%18s, %.8f\n","J statistic",param.Jstat)
  # @printf(fid,"%18s, %d\n","D.F.",size(mat.Z,2)-dim.θ)
  @printf(fid,"%18s, %d\n","Model",model)
  @printf(fid,"%18s, %d\n","Sim. draws",dim.person)
  if optMulti==false
    @printf(fid,"%18s, %.2f\n","Run time",time()-tInit)
  else
    @printf(fid,"%18s, %.2f\n","Run time",tInit)
  end
  @printf(fid,"-----------------------------------------------------------\n\n")
  close(fid)
end

function csvTable!(fileName::String, θ₂::Vector{Float64}, θ₁::Vector{Float64},
  fval::Float64, exitflag::Bool, r::Int64, dim::dimType)

  fid = open(fileName,"a")
  @printf(fid,"%3d",r)
  for k=1:dim.θ₂
    @printf(fid,", %22.15f",θ₂[k])
  end
  for k=1:dim.θ₁
    @printf(fid,", %22.15f",θ₁[k])
  end
  @printf(fid,", %15.9f, %3d\n",fval,exitflag)
  close(fid)
end

function saveResult!(fINT::String, r::Int64, θ₂::Vector{Float64},
  fval::Float64, exitflag::Bool, dim::dimType, timeRun::Float64)

  fid = open(fINT,"a")
  @printf(fid," %4d",r)
  for k=1:dim.θ₂
    @printf(fid," %12.5f",θ₂[k])
  end
  ts = Dates.now()
  tsstr = Dates.format(ts,"yyyy-mm-dd HH:MM:SS")
  @printf(fid," %18.8f %6s %8.0f %20s\n",fval,string(exitflag),timeRun,tsstr)
  close(fid)
end

function loadResult(fJLD::String)
  D = jldopen("./import/"*fJLD,"r") do file
    read(file,"D")
  end
  θ₂ = D["θ₂"]
  θ₁ = D["θ₁"]
  seθ = D["seθ"]
  Jstat = D["Jstat"]
  model = D["model"]
  intNum = D["intNum"]
  nIter = D["nIter"]
  dat = D["dat"]
  dim = D["dim"]
  fxp = D["fxp"]
  lab = D["lab"]
  mat = D["mat"]
  set = D["set"]
  indx = D["indx"]
  pred = D["pred"]
  diags = D["diags"]
  return θ₂,θ₁,seθ,Jstat,model,intNum,nIter,dat,dim,fxp,lab,mat,set,indx,pred,
         diags
end

function printResult!(r::Int64, fval::Float64, θ₂::Vector{Float64},
  exitflag::Bool, timeRun::Float64)

  println("-----------------------------------------------------------------")
  @printf("Estimation summary at starting point: %3d\n",r)
  println("GMM obj: ",fval)
  println("θ₂: ", θ₂)
  println("Exit flag: ",exitflag)
  @printf("Elapsed time: %8.1f seconds\n",timeRun)
  println("-----------------------------------------------------------------")
end

function initFile!(
  fCSV::String,
  fINT::String,
  modelid::Int64,
  stage  ::Int64,
  iv     ::String,
  dim    ::dimType,
  lab    ::labType)

  fid = open(fCSV,"w")
  close(fid)
  fid = open(fINT,"w")
  @printf(fid," %4s","Seed")
  for k=1:dim.θ₂
    @printf(fid," %12s",lab.L[k])
  end
  @printf(fid," %18s %6s %8s %20s\n","Obj","Conv.","RunTime","TimeStamp")
  close(fid)

end

end # end of module
