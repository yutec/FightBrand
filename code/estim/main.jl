### Instruction:
### This file runs post estimation after mainMulti.jl is complete.
# The CSV files exported from mainMulti.jl must be in the same output folder.
# For definition of function inputs, see UnitTest.jl and PostEstim.jl

push!(LOAD_PATH,pwd())

using Revise
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

### Export e(δ) for weak IV test
testIV!( 0, 0,20,"opt",ver,"base")
testIV!(15, 0,10,"opt",ver,"base")
testIV!( 0, 2, 1,"blp",ver,"base")
testIV!( 0, 2, 1,"diff-quad",ver,"base")
testIV!( 0, 2, 1,"diff-local",ver,"base")
testIV!(15, 2, 1,"blp",ver,"base")
testIV!(15, 2, 1,"diff-quad",ver,"base")
testIV!(15, 2, 1,"diff-local",ver,"base")

### Print Tables 4, A.1 & A.15
printEstim!( 0, 0,20,"opt",ver,"base")
printEstim!(15, 0,10,"opt",ver,"base")
printEstim!(27, 0,17,"opt",ver,"base",true,0,3000)
printEstim!(15, 0, 2,"opt",ver,"ms15")
printEstim!(15, 0,16,"opt",ver,"noAllow")
printEstim!(15, 0, 2,"opt",ver,"extra")

### Print Table A.17: Comparison of alternative IVs
printEstim!( 0, 2, 1,"blp",ver,"base",false)
printEstim!( 0, 2, 1,"diff-quad",ver,"base",false)
printEstim!( 0, 2, 1,"diff-local",ver,"base",false)
printEstim!(15, 2, 1,"blp",ver,"base",false)
printEstim!(15, 2, 1,"diff-quad",ver,"base",false)
printEstim!(15, 2, 1,"diff-local",ver,"base",false)

### Table A.2: Monte Carlo Average income for subscribers (yAvg)
yAvg, y025, y975 = MonteCarloIncome(15,10,200,"opt",ver,"base",true;lowB=false)

### Bootstrap samples export for Monte Carlo simulation
yAvg, y025, y975 = MonteCarloIncome( 0,20,200,"opt",ver,"base",true)
yAvg, y025, y975 = MonteCarloIncome(15,10,200,"opt",ver,"base",true)
