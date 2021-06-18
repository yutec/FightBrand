### Instruction:
# This file runs the main estimations in serial-processing mode to isolate
# the source of problem in parallel computation setting
# For the list of input parameters, see gmmOptim! function in GMMInterface.jl
# For the list of input files, check all *.csv files in Helper.jl
# The post estimation step is executed by main.jl

push!(LOAD_PATH,pwd())

using TypeDef, Helper, Estim, Gmm, GMMInterface, UserFileIO, UnitTest
using PostEstim

const ver   = "824"
const fCSV1 = "gmmStage1.csv"
const fCSV2 = "gmmStage2.csv"
const fJLD1 = "gmmStage1.jld"
const fJLD2 = "gmmStage2.jld"
const fINT1 = "gmmStage1Interim.csv"
const fINT2 = "gmmStage2Interim.csv"
const fileName = fileNameType(fCSV1,fCSV2,fJLD1,fJLD2,fINT1,fINT2)


### Continuous updating optimal IV for GMM (Tables 4, A.1 & A.15)
gmmOptim!(fileName, 0,0,"opt",ver,"base";update=true)
# gmmOptim!(fileName,15,0,"opt",ver,"base";update=true)
# gmmOptim!(fileName,27,0,"opt",ver,"base";update=true,nPerson=3000)
# gmmOptim!(fileName,15,0,"opt",ver,"ms15";update=true)
# gmmOptim!(fileName,15,0,"opt",ver,"noAllow";update=true)
# gmmOptim!(fileName,15,0,"opt",ver,"extra";update=true)
#
# ### Comparison of alternative IVs (Table A.17)
# for model=[0,15]
# 	# GMM with BLP IV
# 	gmmOptim!(fileName,model,1,"blp",ver,"base";update=false)
# 	gmmOptim!(fileName,model,2,"blp",ver,"base";update=false,mcid=1)
#
# 	# GMM with diff-quad IV
# 	gmmOptim!(fileName,model,1,"diff-quad",ver,"base";update=false)
# 	gmmOptim!(fileName,model,2,"diff-quad",ver,"base";update=false,mcid=1)
#
# 	# GMM with diff-local IV
# 	gmmOptim!(fileName,model,1,"diff-local",ver,"base";update=false)
# 	gmmOptim!(fileName,model,2,"diff-local",ver,"base";update=false,mcid=1)
# end
