/*******************************************************
 Load processed data produced by "clean.do" file
*******************************************************/
cd "~/work/kantar/brand/work"
set seed 12345
set sortseed 9876

clear all
use dataProcessed802, clear
set type double, permanently
drop network1 choice1* price allow*
rename vendorNetwork network
gen byte operator = 100
replace operator = 1 if network==1 | network==5
replace operator = 2 if network==2 | network==7
replace operator = 3 if network==3 | network==6
replace operator = 4 if network==4
replace operator =  11 if network==11
replace operator =  12 if network==12
replace operator =  13 if network==13
replace operator =  99 if network==99

label define operatorLabel  1 "Orange"
label define operatorLabel  2 "SFR", add
label define operatorLabel  3 "Bouygues", add
label define operatorLabel  4 "Free", add
label define operatorLabel 11 "MVNO1", add
label define operatorLabel 12 "MVNO2", add
label define operatorLabel 13 "MVNO3", add
label define operatorLabel 99 "Virgin", add
label define operatorLabel 100 "NA", add
label values operator operatorLabel

rename meanPrice price
rename meanAllowCall allowCall
rename meanAllowData allowData
rename meanAllowText allowText

save temp, replace 

/*******************************************************
 Construct antenna variables at operator level
*******************************************************/
use temp, clear
gen byte hostNetwork1 = (network==1 | network==5)
gen byte hostNetwork2 = (network==2 | network==7)
gen byte hostNetwork3 = (network==3 | network==6)
gen byte hostNetwork4 = (network==4)

merge m:1 region quarter hostNetwork1 using anfr1, keep(match master) gen(mergeAnfr1)
merge m:1 region quarter hostNetwork2 using anfr2, keep(match master) gen(mergeAnfr2)
merge m:1 region quarter hostNetwork3 using anfr3, keep(match master) gen(mergeAnfr3)
merge m:1 region quarter hostNetwork4 using anfr4, keep(match master) gen(mergeAnfr4)

egen ant2g = rowmax(antAll2g*)
egen ant3g = rowmax(antAll3g*)
egen ant4g = rowmax(antAll4g*)
egen F_ant3g = rowmax(F_ant3g*)
egen F_ant4g = rowmax(F_ant4g*)
egen L_ant2g = rowmax(L_ant2g*)
egen L_ant3g = rowmax(L_ant3g*)
egen L_ant4g = rowmax(L_ant4g*)
replace ant2g = 0 if ant2g==.
replace ant3g = 0 if ant3g==.
replace ant4g = 0 if ant4g==. 
drop hostNetwork* antAll* mergeAnfr*
drop L_ant2g1 L_ant2g2 L_ant2g3 L_ant2g4
drop L_ant3g1 L_ant3g2 L_ant3g3 L_ant3g4
drop L_ant4g1 L_ant4g2 L_ant4g3 L_ant4g4

gen byte hostNetwork1 = (network==4  | network==11 | network==99) // Orange network
gen byte hostNetwork2 = (network==12 | network==99) // SFR network
gen byte hostNetwork3 = (network==13 | network==99) // Bouygues network

merge m:1 region quarter hostNetwork1 using anfr1, keep(match master) gen(mergeAnfr1)
merge m:1 region quarter hostNetwork2 using anfr2, keep(match master) gen(mergeAnfr2)
merge m:1 region quarter hostNetwork3 using anfr3, keep(match master) gen(mergeAnfr3)

// Reclassify Virgin
// full MVNO w/ SFR 2011/6, w/ Orange 2012/4 (2G/3G), 4G w/ SFR & Bouygues 2014/04
gen rannum = uniform() if network==99
sort rannum
gen totAntenna3g = antAll2g1 + antAll2g2 + antAll3g1 + antAll3g2
gen totAntenna4g = antAll4g2 + antAll4g3
gen threshold3g  = (antAll2g1 + antAll3g1) / totAntenna3g
gen threshold4g  = (antAll4g2) / totAntenna4g
gen grp = .
replace grp = 1 if network==99 & period<=201106
replace grp = 2 if network==99 & (period>=201107 & period<=201203)
replace grp = 1 if network==99 & (period>=201204 & period<=201403) & rannum<threshold3g
replace grp = 2 if network==99 & (period>=201204 & period<=201403) & rannum>=threshold3g
replace grp = 1 if network==99 & (period>=201404 & _4g~=1) & rannum<threshold3g
replace grp = 2 if network==99 & (period>=201404 & _4g~=1) & rannum>=threshold3g
replace grp = 2 if network==99 & (period>=201404 & _4g==1) & rannum<threshold4g
replace grp = 3 if network==99 & (period>=201404 & _4g==1) & rannum>=threshold4g

replace antAll2g1 = . if network==99 & grp~=1
replace antAll3g1 = . if network==99 & grp~=1
replace antAll4g1 = . if network==99 & grp~=1
replace antAll2g2 = . if network==99 & grp~=2
replace antAll3g2 = . if network==99 & grp~=2
replace antAll4g2 = . if network==99 & grp~=2
replace antAll2g3 = . if network==99 & grp~=3
replace antAll3g3 = . if network==99 & grp~=3
replace antAll4g3 = . if network==99 & grp~=3

replace operator = 11 if network==99 & grp==1
replace operator = 12 if network==99 & grp==2
replace operator = 13 if network==99 & grp==3
replace network =  11 if network==99 & grp==1
replace network =  12 if network==99 & grp==2
replace network =  13 if network==99 & grp==3

drop grp threshold* totAntenna* rannum hostNetwork* mergeAnfr* antNetwork
save temp, replace

egen ant2gRoam = rowmax(antAll2g*)
egen ant3gRoam = rowmax(antAll3g*)
egen ant4gRoam = rowmax(antAll4g*)
egen L_ant2gRoam = rowmax(L_ant2g*)
egen L_ant3gRoam = rowmax(L_ant3g*)
egen L_ant4gRoam = rowmax(L_ant4g*)
replace ant2gRoam = 0 if ant2gRoam==.
replace ant3gRoam = 0 if ant3gRoam==.
replace ant4gRoam = 0 if ant4gRoam==. | operator==4
replace L_ant4gRoam = 0 if L_ant4gRoam==. | operator==4

drop antAll* 
drop L_ant2g1 L_ant2g2 L_ant2g3
drop L_ant3g1 L_ant3g2 L_ant3g3
drop L_ant4g1 L_ant4g2 L_ant4g3

collapse (mean) ant* F_ant3g F_ant4g L_ant*, by(operator region quarter)

foreach x in ant2g ant3g ant2gRoam ant3gRoam ant4g ant4gRoam {
	replace `x' = `x' / 100
}
save antenna, replace

/*******************************************************
 Construct tariff (price,allowances) variables
*******************************************************/
use temp, clear
collapse (mean) price allow* (first) operator prepost, by(quarter network tier)
collapse (mean) price allow* (first) operator, by(quarter network prepost)
save tariff, replace

/*******************************************************
 Construct new region maps
*******************************************************/
import delimited "~/work/kantar/brand/data/post2014/remapRegion.csv", clear encoding("utf8")
save remapRegion, replace

/*******************************************************
 Construct demographic variables
*******************************************************/
use temp, clear
merge m:1 region using remapRegion, keep(match master) gen(mergeRemapRegion)
save temp1, replace

*** Generate age groups
use temp1, clear
gen grpAge1 = (age<=20)
gen grpAge2 = (age>=21 & age<30)
gen grpAge3 = (age>=30 & age<45)
gen grpAge4 = (age>=45 & age<60)
gen grpAge5 = (age>=60 & age<.)

gen logIncome = log(numericIncome)
save incomeFile, replace 

collapse (mean) income = numericIncome logIncome age grpAge* ///
	(sd) sdIncome = numericIncome sdlogIncome = logIncome sdAge = age ///
	(min) minIncome = numericIncome, by(region2016)

egen sumAge = rowtotal(grpAge*)
forval x = 1/5 {
	replace grpAge`x' = grpAge`x'/sumAge
}
drop sumAge
save demo, replace	

import delimited "~/work/kantar/brand/data/pre2014/population.csv", clear
save population, replace

/*******************************************************
 Collapse & Merge with antenna, tariff, population data
*******************************************************/
use temp1, clear
collapse (count) demand=u_other_id (first) operator (first) datevar (mean) bundle, by(region quarter network prepost)
merge m:1 region quarter operator using antenna, keep(match master) gen(mergeAnfr)
merge m:1 quarter network prepost using tariff, keep(match master) gen(mergeTariff)
label values operator operatorLabel

merge m:1 region using population, keep(match master) gen(mergePopulation)
merge m:1 region using remapRegion, keep(match master) gen(mergeRemapRegion)

collapse (rawsum) demand ant* F_ant* L_ant* pop (mean) price allow* ///
	(first) operator [fw=pop], by(region2016 quarter network prepost)
label values operator operatorLabel

merge m:1 region2016 using demo, keep(match master) gen(mergeDemo)
rename region2016 region

/*******************************************************
 Generate antenna variables
*******************************************************/
gen Totant2g=ant2g+ant2gRoam
gen Totant3g=ant3g+ant3gRoam
gen Totant4g=ant4g+ant4gRoam

gen lTotant2g  = log(Totant2g+1)
gen lTotant3g  = log(Totant3g+1)
gen lTotant4g  = log(Totant4g+1)
gen lant2g     = log(ant2g+1)
gen lant3g     = log(ant3g+1)
gen lant4g     = log(ant4g+1)
gen lant34     = lTotant3g*lant4g
gen lant2gRoam = log(ant2gRoam+1)
gen lant3gRoam = log(ant3gRoam+1)
gen lant4gRoam = log(ant4gRoam+1)

egen allant2g = total(ant2g), by(operator quarter)
egen allant3g = total(ant3g), by(operator quarter)
egen allant4g = total(ant4g), by(operator quarter)

/*******************************************************
 Generate miscellaneous variables
*******************************************************/
drop if network>=5 & network<=7 & quarter==207
*drop L_ant* 
egen msize = total(demand), by(quarter region)
drop if network==0
egen sumDemand = total(demand), by(quarter region)

* Drop samples with ms<0.001
drop if demand/sumDemand<0.001
drop sumDemand
egen sumDemand = total(demand), by(quarter region)

replace msize = msize + 1 if sumDemand==msize
gen  double ms = demand/msize
egen double sumMS = total(ms), by (region quarter)
gen  double ms0 = 1 - sumMS
gen  double delta = log(ms/ms0)

tab operator, gen(FEop)
tab region, gen(FEre)
tab network, gen(FEnet)
gen qtr = quarter - 203
gen byte con = 1

gen double roaming = (ant3g+ant4g) / (ant3g+ant3gRoam+ant4g) if network==4
replace roaming = 0 if network~=4
egen networkRegion = group(network prepost region), label
egen id = group(qtr network prepost), label

* Replace price with exact averages
egen price0 = mean(price), by(qtr network prepost)
drop price
rename price0 price

/*******************************************************
 Create controls & instrumental variables 
*******************************************************/
gen postpaid = (prepost==2)
gen pblocked = (prepost==3)
gen agePostpaid = age*(prepost==2)
gen agePblocked = age*(prepost==3)

* Generate age-specific coefficients
forval x = 1/5 {
	gen age_call`x'     = grpAge`x' * allowCall
	gen age_data`x'     = grpAge`x' * allowData	
	gen age_prepaid`x'  = grpAge`x' * (prepost==1)
	gen age_postpaid`x' = grpAge`x' * (prepost==2)
	gen age_fbloque`x'  = grpAge`x' * (prepost==3)
	gen age_forfait`x'  = grpAge`x' * (prepost==2 & (network<=3 | network>=8))
	gen age_lowcost`x'  = grpAge`x' * (network>=4 & network<=7)
}
save temp, replace

replace age = age/10
forval x = 1/7 {
	gen age_network`x' = FEnet`x'*age
}
egen meanIncome = mean(income)
gen  incomeScale = income/meanIncome
gen py = price/incomeScale
label variable py "Price/income"
gen lincome = log(income)
egen entry = min(qtr), by (network prepost region)
gen entered = (qtr>=entry)

* Product-specific entry times
gen timeSinceEntry = 1/(qtr - entry + 1)
replace timeSinceEntry = 0 if network<4 | (network>7 & network<13)
replace timeSinceEntry = 0 if (network==13) & (prepost~=2)

global antSet ant2g ant3g ant4g 

foreach x in $antSet con {
	egen sum_`x'          = sum(`x'), by (quarter)
	egen sum_region_`x'   = sum(`x'), by (quarter region)
	egen sum_operator_`x' = sum(`x'), by (quarter operator)
	egen sum_network_`x'  = sum(`x'), by (quarter network)
	egen sum_product_`x'  = sum(`x'), by (quarter network prepost)
	egen sum_prepost_`x'  = sum(`x'), by (quarter prepost)
	egen sum_region_operator_`x' = sum(`x'), by (quarter region operator)
	egen sum_region_network_`x'  = sum(`x'), by (quarter region network)
	gen iv_operator_`x'       = (sum_`x' - sum_operator_`x')
	gen iv_network_`x'        = (sum_`x' - sum_network_`x')
	gen iv_product_`x'        = (sum_network_`x' - sum_product_`x')
	gen iv_prepost_`x'        = (sum_prepost_`x' - `x')
	gen iv_region_network_`x' = (sum_region_operator_`x' - sum_region_network_`x')
	gen iv_region_product_`x' = (sum_region_network_`x' - `x')
}

* Differentiation IVs
tab qtr, gen (FEqtr)

global prodchar1 lant2g lant2gRoam lant3g lant3gRoam lant4g lant4gRoam ///
	allowCall allowData 
global networkFE FEnet1 FEnet2 FEnet3 FEnet4 FEnet5 FEnet6 FEnet7 FEnet8 FEnet9 
global demo age ///
	age_postpaid1 age_postpaid2 age_postpaid3 age_postpaid4 ///
	age_prepaid1 age_prepaid2 age_prepaid3 age_prepaid4 ///
	age_fbloque1 age_fbloque2 age_fbloque3 age_fbloque4
global othersFE timeSince FEqtr* FEre*
global ivs iv_network_* iv_product_* ant2g* ant3g* ant4g*

foreach x in $prodchar1 $networkFE $demo {
	egen sum_region_`x' = sum(`x'), by (quarter region)
	egen sum_region_network_`x' = sum(`x'), by (quarter region network)
	egen sum2_`x'      = sum(`x'^2), by (quarter region)
	egen sum2_netw_`x' = sum(`x'^2), by (quarter region network)
	gen iv_sum2_netw_`x' = sum2_`x' - sum2_netw_`x'
	gen iv_sum2_prod_`x' = sum2_netw_`x' - `x'^2
	gen iv_sum1_netw_`x' = sum_region_`x' - sum_region_network_`x'
	gen iv_sum1_prod_`x' = sum_region_network_`x' - `x'
}

foreach x in $prodchar1 $networkFE $demo {
	gen iv_sum3_netw_`x' = (sum_region_con - sum_region_network_con) * `x'^2
	gen iv_sum3_prod_`x' = (sum_region_network_con - 1) * `x'^2
	qui replace iv_sum1_netw_`x' = 2 * `x' * iv_sum1_netw_`x'
    qui	replace iv_sum1_prod_`x' = 2 * `x' * iv_sum1_prod_`x'
	gen iv_diff_netw_`x' = iv_sum3_netw_`x' - iv_sum1_netw_`x' + iv_sum2_netw_`x'
	gen iv_diff_prod_`x' = iv_sum3_prod_`x' - iv_sum1_prod_`x' + iv_sum2_prod_`x'
}
drop iv_diff_prod_FEnet*

gen numProd = sum_product_con
egen mktSize = total(pop), by (quarter network prepost)
gen mktSizePrepaid  = mktSize*(prepost==1)
gen mktSizePostpaid = mktSize*(prepost==2)

drop sum* 

/*******************************************************
 Generate variable labels
*******************************************************/
label variable Totant2g "Total antenna 2G"
label variable Totant3g "Total antenna 3G"
label variable Totant4g "Total antenna 4G"

label variable price "Price"
label variable FEnet1 "Orange"
label variable FEnet2 "SFR"
label variable FEnet3 "Bouygues"
label variable FEnet4 "Free"
label variable FEnet5 "Sosh"
label variable FEnet6 "B&You"
label variable FEnet7 "Red"
label variable FEnet8  "MVNO:Orange"
label variable FEnet9  "MVNO:SFR"
label variable ant2g "2G antenna"
label variable ant3g "3G antenna"
label variable ant4g "4G antenna"
label variable lant2g "Log(2G antenna)"
label variable lant3g "Log(3G antenna)"
label variable lant4g "log(4G antenna)"
label variable lant2gRoam "Log(2G roaming)"
label variable lant3gRoam "Log(3G roaming)"
label variable lant4gRoam "Log(4G roaming)"
label variable ant2gRoam "2G roaming"
label variable ant3gRoam "3G roaming"
label variable Totant2g "2G antenna total"
label variable lTotant2g "Log(2G antenna)"
label variable Totant4g "4G antenna total"
label variable lTotant4g "Log(4G antenna)"
label variable quarter  "Time trend"
label variable income   "Mean income"
label variable age      "Mean age"
label variable operator "Mobile operator"
label variable sdIncome "Income Std. Dev."
label variable minIncome "Minimum income"
label variable agePostpaid "Postpaid*age"
label variable agePblocked "Forfait bloqué*age"
compress
save anfrData822, replace

erase temp.dta
erase antenna.dta
erase tariff.dta

/*******************************************************
 Table A.2 (Observed income only)
*******************************************************/
use temp1, clear
merge m:1 region2016 using demo, keep(match master) gen(mergeDemo)
drop region
rename region2016 region
rename income meanIncome
rename numericIncome income
drop if quarter<=206
drop if region==94
drop if network==0

* Average income by network & product type
collapse (mean) income age price, by (region network prepost)
tab network prepost, su (income) means

erase temp1.dta
erase demo.dta
