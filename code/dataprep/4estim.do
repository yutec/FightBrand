/*******************************************************
 Estimation of logit aggregate demand
*******************************************************/
cd "~/work/kantar/brand/work/"

set more off
set type double
clear all
use  anfrData822, clear
xtset networkRegion quarter

gen prepaid = (prepost==1)
drop if qtr<=3
drop FEqtr1-FEqtr4
drop FEre12 FEre13
drop age_call1 age_data1 grpAge1
drop age_prepaid5 age_postpaid5 age_fbloque5 age_forfait5 age_lowcost5
drop FEnet10
drop FEre9 FEre10 FEre11

global prodchar1 lant2g* lant3g* lant4g* pblocked prepaid allowCall allowData
global networkFE FEnet*
global demo age_forfait* age_prepaid* age_fbloque* age_lowcost* age_network*
global othersFE timeSince FEqtr* FEre*
global ivs iv_network_* iv_product_* ant2g* ant3g* ant4g*
global ivd phatIV iv_diff_netw_* iv_diff_prod_* 
global ivr iv_network_* iv_product_* 

*** First-stage price regression (Table A.21)
eststo clear
eststo: regress price $prodchar1 $networkFE $demo $othersFE $ivr 
esttab using tableFirst.csv, b(%12.3f) se(%8.3f) scalar(J F) nostar wide label nogaps plain replace
predict phatIV

*** Differentiation IV based on p hat
foreach x in phatIV con {
	egen sum_region_`x'         = sum(`x'), by (quarter region)
	egen sum_region_network_`x' = sum(`x'), by (quarter region network)
	egen sum2_`x'        = sum(`x'^2), by (quarter region)
	egen sum2_netw_`x'   = sum(`x'^2), by (quarter region network)
	gen iv_sum2_netw_`x' = sum2_`x' - sum2_netw_`x'
	gen iv_sum2_prod_`x' = sum2_netw_`x' - `x'^2
	gen iv_sum1_netw_`x' = sum_region_`x' - sum_region_network_`x'
	gen iv_sum1_prod_`x' = sum_region_network_`x' - `x'
}	

gen iv_sum3_netw_phatIV = iv_sum1_netw_con * phatIV^2
gen iv_sum3_prod_phatIV = iv_sum1_prod_con * phatIV^2
replace iv_sum1_netw_phatIV = 2 * phatIV * iv_sum1_netw_phatIV
replace iv_sum1_prod_phatIV = 2 * phatIV * iv_sum1_prod_phatIV
gen iv_diff_netw_phatIV = iv_sum3_netw_phatIV - iv_sum1_netw_phatIV + iv_sum2_netw_phatIV
gen iv_diff_prod_phatIV = iv_sum3_prod_phatIV - iv_sum1_prod_phatIV + iv_sum2_prod_phatIV

*** Rescale price
replace py = price/(income/100)

/* Estimation */
eststo clear
eststo: regress delta py $prodchar1 $networkFE $demo $othersFE 

eststo: ivregress gmm delta (py=$ivr) $prodchar1 $networkFE $demo $othersFE, wmatrix(cluster networkRegion)
estat overid

esttab using tableLogit824.csv, b(%12.3f) se(%8.3f) scalar(J) star(* 0.10 ** 0.05 *** 0.01) label nogaps replace
eststo clear

*** Product elasticities
egen epr = total(_b[py] * pop * ms * (1-ms) * py), by (quarter network prepost)
egen totalDemand = total(ms * pop), by (quarter network prepost)
gen elasDemand = epr/totalDemand
su  elasDemand if network<10

*** Market elasticities
gen delta1 = delta + _b[py]*price*0.01/(income/100)
gen num1   = exp(delta1)
egen den   = total(num1), by (quarter region)
gen ms1    = num1 / (1+den)
egen tms   = total(ms), by (quarter region)
egen tms1  = total(ms1), by (quarter region)
gen dmsdp = ((tms1 - tms)/tms*100)
su dmsdp if network<10

compress
save analysis824, replace

*** First stage F test (R2 & F on excluded instruments at the bottom of Table A.21)
qui ivregress gmm delta (py=$ivr) $prodchar1 $networkFE $demo $othersFE, wmatrix(cluster networkRegion) 
estat firststage
