### Instruction:
# Run before main.jl.
# CSV files must be in the input folder matching the simulatin model.
# For the list of input parameters, see readData function in Helper.jl
# For the list of input files, check all *.csv files in Helper.jl
using Distributed
@everywhere include("incl.jl")
@everywhere sayhello()
@everywhere push!(LOAD_PATH,pwd())

@everywhere begin
using TypeDef, Helper, Tools, Compute, Solve, FOCs, UserFileIO, MonteCarlo
using Post
using JLD, Printf
end

model =   0
mcid  =  20
b1    =   1
b2    = 200

### Monte Carlo analysis
for vInt=[false,true]
  @printf("\n=================== Starting Monte Carlo ===================\n")
  @printf("  Model: %2d  MCid: %2d  Vertical Int: %d\n",model,mcid,vInt)
  dat,dim,env,mat,par0,set,sim,indx,mask = readData(model,mcid,b1,b2,vInt,true)
  eqa = simMonteCarloMulti!(b1,b2,dat,dim,env,mat,par0,set,indx,mask,vInt)
end
