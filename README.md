# FightBrand

This repository contains program codes for replicating the analysis of the article "***Market Entry, Fighting Brands and Tacit Collusion: Evidence from the French Mobile Telecommunications Market***" by Marc Bourreau, Yutec Sun and Frank Verboven.

Below is the description of the program codes and input data, with guideline for the replication process. 



## Data sources

1. Kantar
 - The demand-side data was purchased from the Kantar Worldpanel (https://www.kantarworldpanel.com/global) under a non-disclosure agreement. For purchase inquiry, it is recommended to contact the Kantar UK director Tony Fitzpatrick (Tony.Fitzpatrick@KantarWorldpanel.com). It can take several months to negotiate data use agreements and gain access to the data. The authors will assist with any reasonable replication attempts for two years following publication.
 - The data for our analysis are located in two folders: `data/pre2014` and `data/post2014`.
 - The pre2014 data contain the following components:
	1. `France_Data.csv`: main consumer survey
	2. `bill2.csv`: mobile tariff bills of each consumer categorized by ranges
	3. `spend.csv`: mobile spending of each consumer
	4. `PanelDemogs.csv`: consumer panel demographics
	5. `PhoneList.csv`, PhoneListUpdate.csv: list of mobile phone devices
	6. `deptINSEE1.csv`,` deptINSEE2.csv`, `deptINSEE3.csv`: geographic locations (departments) of consumer panel
	7. `depts2011.txt`: code list of departments in France
 - The post2014 data augment the above with 2014 survey sample in similarly structure:
	1. `FranceDatav2.csv`
	2. `FrancePanelv2.csv`
	3. `PhoneList.csv`
	4. `DEPTINSE.csv`

2. ANFR
 - The dataset on cellular networks was originally provided by Agence Nationale des Fréquences (ANFR) under the non-disclosure agreement. Later it became publicly accessible at https://data.anfr.fr through the government's open data policy. Go to menu "DONNEES" => "Données sur les réseaux mobiles" => "Export" to find the data file ("fichier plat"). Our dataset may contain some discrepancy with the public version. The ANFR dataset is under `data/anfr` folder.

3. Census
 - The 2012 population data came from Institut National de la Statistique et des Études Économiques (INSEE). The data is publicly available at https://www.insee.fr/fr/statistiques/2119585?sommaire=2119686. It can be found at `data/pre2014/population.csv`.

4. OECD data on fighting brands
 - This contains the entry years of low-cost brands across OECD countries within folder `data/oecd`. The data were manually compiled from various publicly accessible sources. The source locations and links are documented in the accompanying file `low_cost_subsidiary_brands.docx` within the same folder where the raw data and Stata codes for processing the file are also provided.



## System requirement

The replication process requires a single local machine operating Linux/Mac OS with Stata 14.2, Julia 1.6.0, Matlab 2019, and a Unix-like shell equivalent to Bash. In Linux, 1 gigabytes of memory and 10 gigabytes of disk space would be sufficient. Total computation takes about 2 days with 40 CPU cores in our system. Without parallelization, multithreading is the default option for Julia, but it is inefficient and might take up to 2-3 months in our crude estimation. Extra flag options, shell scripts, and system configuration must be provided for cluster systems to run the Julia codes. Microsoft Windows is not guaranteed to work with the Julia replication code, and it is the user's responsibility to ensure seamless execution. 

Optionally for Julia IDE, the user is advised to use Atom. Visual Studio Code is not supported due to unresolved file IO and library path issues. 

1. Stata
  - Install the following Stata packages by running `0config.do`:
  - `carryforward` 
  - `ivreg2`
  - `unique`
  - `estout`

2. Julia
 - Download the Julia binary from https://julialang.org/. Using Julia built from the source may produce different results. 

 - Install the required packages by entering within the Julia REPL console the following command:

		] add JLD, LoopVectorization, Optim, NLsolve, StatsBase, Distributions, Plots, Revise, CSV, DataFrames

3. Matlab (optional)
 - For generating Latin hypercube pseudorandom numbers for estimation and simulation, we use Matlab's lhsnorm procedure. The files are provided in the replication package. 



## Workflow 

We provide a step-by-step description on how the results were produced for the manuscript. 

1. Move `data` folder to `~/work/kantar/brand/data` (data not included).
2. Create path `~/work/kantar/brand/work` for Stata outputs. 
3. Create path `~/work/kantar/brand/workfiles` for Julia to import the csv files exported by Stata. 
4. Execute Stata codes in `dataprep` folder. Follow the instruction below for details. 
5. Move csv file outputs in `~/work/kantar/brand/work` to `~/work/kantar/brand/workfiles`.
6. Go to `code/estim`
7. Run `julia -O3 -p 20 mainMulti.jl`. It can take about 2 days on the Intel Xeon E5-4627 v4 system. Check below for details.  
8. Run `julia -O3 main.jl 2>&1 | tee -a log.txt`. It takes about 20-30 minutes on MacBook Pro 2019 with Intel Core i9. 
9. Copy output files: 
 - `cp out/base/m0s2blp200/swtest_blp.csv post/testIV/m0/`
 - `cp out/base/m0s2diff-quad200/swtest_diff-quad.csv post/testIV/m0/`
 - `cp out/base/m0s2diff-local200/swtest_diff-local.csv post/testIV/m0/`
 - `cp out/base/m15s2blp200/swtest_blp.csv post/testIV/m15/`
 - `cp out/base/m15s2diff-quad200/swtest_diff-quad.csv post/testIV/m15/`
 - `cp out/base/m15s2diff-local200/swtest_diff-local.csv post/testIV/m15/`
10. Go to `post/testIV/m0` and run `swtest.do`.
11. Go to `post/testIV/m15` and run `swtest.do`.
12. Go to `code`
13. Copy csv files for `sim` module:
 - `cp estim/out/base/m0s0opt200/*.csv sim/input/dat824/m0/`
 - `cp estim/out/base/m15s0opt200/*.csv sim/input/dat824/m15/`
14. Go to `code/sim`
15. Run `julia -O3 -p 40 mainMulti.jl`. With 40 CPU cores, this step usually takes about 8-10 hours. 
16. Run `julia -O3 -p 40 mainMulti2.jl`.
17. Run `julia -O3 main.jl 2>&1 | tee -a log.txt`. 

This completes the replication process. 



## Warnings before getting started

The replication workflow proceeds in multiple stages. Throughout the estimation process, the Julia program selects the best result from the previous stage among multiple estimation runs, but this selection was manually determined. 

Hence, the replication process follows the pre-determined sequence based on the prior knowledge of the best estimates in each stage. In case of any change of input data or random numbers, it is critical to update the programs to make correct selection when working with different data or random numbers. 

The Stata codes exhibit random behevior during the data-cleaning process (steps 1 and 2 within Module `dataprep`) for generating the file `dataProcessed802.dta`. Hence, it is required to use the same file `dataProcessed802.dta` to ensure the replication to perform correctly every time. 

Different Stata versions may cause discrepancy in some tables. For example, Stata 14 and 17 were found to generate different results for Table A.2. 



## Program structure

The analysis results are generated in multiple steps by the program files organized by the corresponding folder structure.

### 1. Module `dataprep`

Within this folder, Stata scripts build from sources the dataset for analysis. Before getting started, the external packages can be installed by executing the Stat do-script file `0config.do` first. Then, the do-script files must be executed in the following order. 

1. merge: Merge all raw source files into Stata format
2. clean: Clean up the dataset and define variables
3. reshape: Reshape the data structure into estimation format
4. estim: Estimate simple and IV logit demands
5. export: Export datasets into csv format for estimation and simulation in Julia
6. plots/tables: Produce descriptive statistics and plots reported in the paper. 
7. estim.extra: the version of estim implemented for the full sample
8. export.extra: the full-sample version of export

The generated dataset may vary slightly depending on the version of Stata due to differences in internal pseudo-random number generation mechanism. For consistent and correct replication, it is necessary to use the same output `dataProcessed802.dta` as described in the warning section above. For the compplete list of tables produced by this module, see the section **Tables** below. 

The script file `5export.do` exports the csv files for estimation in Step 2:
- `demand824.csv`: consumer demand and sample identifiers for the main model
- `demand824ms15.csv`: a version of demand824.csv where market size increased by 50%
- `demand824NoAllow.csv`: a version of demand824.csv where sample is extended to 2011 Q1 without allowance variables
- `Xinput824.csv`: product characteristics 
- `ZinputBlp824.csv`,` ZinputBlp824core.csv`: inputs for BLP instruments 
- `DiffIVinput824reduced.csv`,` DiffIVinput824reduced2.csv`: inputs for differentiation IVs
- `income.csv`, `incomeEMdraws`: income statistics and draws

All the csv files are generated under `~/work/kantar/brand/work` by default. They must be copied into `~/work/kantar/brand/workfiles` for the next stage. 

### 2. Module `estim`

This folder contains Julia program files for random coefficients logit demand estimations in the Unix-type shell environment. It also includes Stata scripts within subfolder `post/testIV` to perform weak IV tests. 

In addition to the above CSV files, the estimation needs input files for random draws simulated by external program. We used Matlab's lhsnorm to generate Latin hypercupe samples from normal distribution. The file names must be consistent with the dimension of the random coefficients distribution and the number of simulation draws. Matlab codes used for random number generation are `sampleDraws.m` and `simDraw.m`. They are included within the directory `~/work/kantar/brand/workfiles/simdraws` where the input random number files are also located. 

The program should run in the following steps.

#### 1. mainMulti.jl
Estimate RC logit demand using various specifications & IV approaches from 20 starting points. For acceleration, it is advised to use multiple processors by entering in the command shell:

	julia -p 20 -O3 mainMulti.jl

where 20 is the maximum number of CPUs for running each of the estimation runs from 20 starting points. More CPUs are redundant, and large memory is not required. For PBS clusters, a sample job launch script looks as follows:

	#!/bin/bash
	#PBS -S /bin/bash
	#PBS -N julia
	#PBS -l nodes=1:ppn=4
	#PBS -l walltime=03:00:00:00
	#PBS -l pmem=1gb
	#PBS -o out.txt
	#PBS -e err.txt
	#PBS -m abe
	
	date 
	
	# Change to directory from which job was submitted
	cd $PBS_O_WORKDIR
	echo $PBS_O_WORKDIR
	
	echo "loaded modules"
	#module load R/3.5.0-foss-2014a-bare
	module list
	
	echo "here is your PBS_NODEFILE"
	cat $PBS_NODEFILE
	
	echo "check library path"
	echo $LD_LIBRARY_PATH
	
	echo "calling julia now"
	julia -O3 --machine-file $PBS_NODEFILE mainMulti.jl
	echo "julia successfully finished"

On alternative cluster, the user may have to follow similar procedure for the cluster to load library paths and worker nodes properly. For more information on troubleshooting cluster problems, consult with Julia documentations at https://docs.julialang.org/en/v1/stdlib/Distributed/. General information on Julia parallel computing is available at https://docs.julialang.org/en/v1/manual/distributed-computing/. 

Estimating model 29 (Line 29 in `mainMulti.jl`) alone takes about 30 hours when running on a 40-core Xeon E5-4627 v4 system. The rest of the lines may take about total 6-8 hours. To save time, it is advised to run estimations (especially Line 29) separately (by commenting out all other lines) while estimating other models in parallel.  

#### 2. main.jl
This generates main estimation tables for the manuscript and input files for the weak IV tests, using the estimation results obtained in Step 1. It also exports input files for the Monte Carlo simulation in the next step. All the output files are exported to corresponding subfolders under `out`. Excecute by running:

	julia -O3 main.jl 2>&1 | tee -a log.txt

The program exports the estimation results into CSV files to be imported to LibreOffice for print-friendly format. The list includes:
- The remaining columns in Tables 4 & A.1 
- Table A.15
- Table A.17
- Table A.2 (only in screen output)

When the excecution is complete, file `log.txt` stores all the screen outputs, among which Table A.2 can be found.  

#### 3. swtest.do
The Stata script performs the Sanderson-Windmeijer test under subfolder `post/testIV/mXX` where XX denotes model ID code. It takes as input the CSV files named `swtest_xxx.csv` (xxx is a tag identifier) under the subfolder `out`, which are exported by "testIV!" function in `main.jl`. 

The output file is:
- Tables A.16

#### 4. Summary of output files generated by module `Estim`
All the estimation results are stored within a subfolder corresponding to each estimation specification under the output directory `out/`. 
- `gmmStage2.csv`: output for post-estimation analysis
- `gmmParam.csv`, `estimLatex.csv`: ouptput for formatted tables
- `gmmStage2Interim.csv`: summary of 20 estimation runs
- `paramDraws.csv`: Bootstrap samples of GMM estimates for Monte Carlo simulation
- `expDelta.csv`: BLP fixed point exp(delta)
- `swtest_xxx.csv`: outputs for the weak IV tests. Tag xxx corresponds to IV approaches (BLP or diff IVs)

### 3. Module `sim`

The Julia code under this folder produces Monte Carlo simulation results. It takes as input the CSV files exported from the estimation step, which must be copied to subfolder `input/dat824/mxx` where tag xx is the model identifier. 

#### 1. mainMulti.jl
It performs 200 Monte Carlo simulations for all 16 possible equilibria. Each CPU executes single Monte Carlo cycle out of the total 200 simulations. For example, we run on 40 CPUs by entering:

	julia -p 40 -O3 mainMulti.jl

Each instance does not need large memory (about 1GBs of memory would work). The output `sim824.jld` is exported, for example, to subfolder `output/dat824/m15/mc0/b1/`, where m15 is model ID for the RC logit demand specification, mc0 for the default wholesale marginal cost of MVNOs, b1 for the 1st 200 batch of the Monte Carlo (v1 for vertical integration model). For details, see "readData" function in `Helper.jl`. 

#### 2. mainMulti2.jl

This file performs the same simulation analysis as `mainMulti.jl` only for different model ("model=0"). It runs by command:

	julia -p 40 -O3 mainMulti2.jl

#### 3. main.jl
This post-simulation code generates all the remaining tables for the counterfactual exercises in the manuscript. Most outputs are printed in the command-line console. The large tables for diversion ratios and elasticities are exported as CSV files within the same subfolder as in the above (`mainMulti.jl`). It takes as input the file `sim824.jld` in the original path. 

```
julia -O3 main.jl 2>&1 | tee -a log.txt
```

As before, the tables displayed on the screen can be retrieved from file `log.txt`.

## Continuous-updating optimal IV

For the BLP demand estimation, this paper uses the continuous-updating version of the optimal IV approach based on Reynaert and Verboven (Journal of Econometrics, 2014). The procedure is implemented by the `optimIV!` function within `Estim.jl` of the **estim** module. The rest of the main computations for the GMM estimation is performed by `Estim.jl` as well.



## Tables

The following table lists the location of source codes generating the tables in the manuscript as either screen or file output. The exported CSV files are not in print-friendly format and need to be imported into LibreOffice or equivalent to generate the final table. The line numbers are where the analysis results are processed for the final output, **after** the main part of intensive computations is complete. 

| Table | Program  | Folder                      | Line number | Output                              |
| ------------ | ----|----------------- | ------------------- |---------|
| 1            | 6tables.do                     | dataprep              | 20                      |Screen|
| 2            | 6tables.do                     | dataprep              | 46, 50                  |Screen|
| 3            | 6tables.do                     | dataprep              | 63, 65                  |Screen|
| 4            | -        | - | - |From Table A1|
|              | 4estim.do | dataprep |71, 81 (IV logit-elasticities)|Screen|
|              | post.jl | sim |24 (RC logit I-elasticities)|Screen|
|              |             |                       |24 (RC logit II-elasticities)|Screen|
| 5     | -           | -                     | -                              | From Table A3                              |
| 6     | post.jl     | sim                   | 24                             | Screen                                     |
| 7     | post.jl     | sim                   | 24                             | Screen                                     |
| 8     | post.jl     | sim                   | 24                             | Screen                                     |
| 9 | post.jl | sim | 24 | Screen |
| A1 | 4estim.do | dataprep | 64 (Logit & IV logit) | tableLogit824.csv |
|       | main.jl | estim | 32 (RC logit I) | out/base/m0s0opt200/estimLatex.csv |
|       | main.jl | estim | 33 (RC logit II) | out/base/m15s0opt200/estimLatex.csv |
| A2 | 3reshape.do | dataprep | 422 (Observed income) | Screen |
|       | main.jl | estim | 48 (Predicted income) | Screen |
| A3 | post.jl | sim | 26 | output/dat824/m15/mc0/b1/divRatio.csv |
| A4 | post.jl | sim | 26 | output/dat824/m15/mc0/b1/elasR.csv |
| A5 | post.jl | sim | 24 | Screen |
| A6 | post.jl | sim | 24 | Screen |
| A7 | post.jl | sim | 24 | Screen |
| A8    | post.jl     | sim                   | 24                             | Screen                                     |
| A9    | post.jl     | sim                   | 24                             | Screen                                     |
| A10   | post.jl     | sim                   | 24                             | Screen                                     |
| A11   | post.jl     | sim                   | 24                             | Screen                                     |
| A12   | post.jl     | sim                   | 24                             | Screen                                     |
| A13   | post.jl     | sim                   | 24                             | Screen                                     |
| A14   | post.jl     | sim                   | 24                             | Screen                                     |
| A15   | main.jl     | estim                 | 32 (RC logit I)                | out/base/m0s0opt200/estimLatex.csv         |
|       |             |                       | 33 (RC logit II)               | out/base/m15s0opt200/estimLatex.csv        |
|       |             |                       | 34 (Normal RC)                 | out/base/m27s0opt3000/estimLatex.csv       |
|       |             |                       | 35 (M*1.5)                     | out/ms15/m15s0opt200/estimLatex.csv        |
|       |             |                       | 36 (No Allownace)              | out/noAllow/m15s0opt200/estimLatex.csv     |
|       |             |                       | 37 (Full sample)               | out/extra/m15s0opt200/estimLatex.csv       |
| A16   | swtest.do   | estim/post/testIV/m0  | 7 (RC logit I-BLP)             | Screen (manually collected)                |
|       |             |                       | 12 (RC logit I-Diff IV quad)   | Screen (manually collected)                |
|       |             |                       | 17 (RC logit I-Diff IV local)  | Screen (manually collected)                |
|       | swtest.do   | estim/post/testIV/m15 | 7 (RC logit II-BLP)            | Screen (manually collected)                |
|       |             |                       | 12 (RC logit II-Diff quad)     | Screen (manually collected)                |
|       |             |                       | 17 (RC logit II-Diff local)    | Screen (manually collected)                |
| A17   | main.jl     | estim                 | 40 (RC logit I-BLP)            | out/base/m0s2blp200/estimLatex.csv         |
|       |             |                       | 41 (RC logit I-Diff quad)      | out/base/m0s2diff-quad200/estimLatex.csv   |
|       |             |                       | 42 (RC logit I-Diff local)     | out/base/m0s2diff-local200/estimLatex.csv  |
|       |             |                       | 43 (RC logit II-BLP)           | out/base/m15s2blp200/estimLatex.csv        |
|       |             |                       | 44 (RC logit II-Diff quad)     | out/base/m15s2diff-quad200/estimLatex.csv  |
|       |             |                       | 45 (RC logit II-Diff local)    | out/base/m15s2diff-local200/estimLatex.csv |
| A18   | post.jl     | sim                   | 24                             | Screen                                     |



## Figures

The following table lists the location of codes exporting the figures shown in the manuscript and appendix. 

| Figure | Program    | Folder     | Line number    | Output     |
| ------ | ---------- | ---------- | -------------- | ---------- |
| 1      | 6plots.do  | dataprep   | 43             | price1.pdf |
| 2      | 6plots.do  | dataprep   | 29             | ms1.pdf    |
| 3      | paper.tex  | LaTeX file | 731-836        | In text    |
| 4      | figure4.do | data/oecd  | 6 (Figure 4a)  | fig4a.pdf  |
|        |            |            | 13 (Figure 4b) | fig4b.pdf  |
| A1     | 6plots.do  | dataprep   | 52             | price2.pdf |

For Figure 4, the Stata code `figure4.do` imports input data `crosscountry.dta` that was manually entered based on the table "Entries per year" in the enclosed Excel file `table low cost brands.xlsx` All the raw data and their sources are in the same folder `data/oecd`. 

