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
drop FEqtr1
drop FEnet10
drop FEre12 FEre13
drop age_prepaid5 age_postpaid5 age_fbloque5 age_forfait5 age_lowcost5
drop FEre9 FEre10 FEre11

global prodchar2 lant2g* lant3g* lant4g* pblocked prepaid
global networkFE FEnet*
global demo age_forfait* age_prepaid* age_fbloque* age_lowcost* age_network*
global othersFE timeSince FEqtr* FEre*
global ivs iv_network_* iv_product_* ant2g* ant3g* ant4g*
global ivd phatIV iv_diff_netw_* iv_diff_prod_* 
global ivr iv_network_* iv_product_* 

// drop if qtr<=3
regress price $prodchar2 $networkFE $demo $othersFE $ivr
predict phatIV

*** Correct py = price/income
replace py = price/(income/100)

/* Estimation */
eststo: regress delta py $prodchar1 $networkFE $demo $othersFE 

eststo: ivregress gmm delta (py=$ivs) $prodchar2 $networkFE $demo $othersFE, wmatrix(cluster networkRegion)
estat overid

eststo: ivregress gmm delta (py=$ivr) $prodchar2 $networkFE $demo $othersFE, wmatrix(cluster networkRegion)
estat overid

compress
save analysis824extra, replace

