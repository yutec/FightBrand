### Instruction:
# Run after mainMulti.jl is finished.
# sim824.jld needs to be in the same output folder.
# For definition of inputs, see postMonteCarlo function in Post.jl
push!(LOAD_PATH,pwd())

using Revise
using TypeDef, Helper, Tools, Compute, Solve, FOCs, UserFileIO, MonteCarlo
using Post
using JLD, Printf

### Post-simulation in wholesale-retail markets
dim,eqb,tab = postMonteCarlo(15,10,false,false,0,true)

### Post-simulation under vertical integration
dim,eqb,tab = postMonteCarlo(15,10,true,false,0)

### Demand elasticity for Model 0 (Table 4 Column 3)
dim,eqb,tab = postMonteCarlo( 0,20,false,false,0,false)
