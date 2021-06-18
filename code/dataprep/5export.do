/*******************************************************
 Construct prediced national price
*******************************************************/
cd "~/work/kantar/brand/work/"

set more off
set type double, permanently
clear all
use  analysis824, clear
xtset networkRegion quarter 

global prodchar1 lant2g* lant3g* lant4g* pblocked prepaid allowCall allowData
global networkFE FEnet*
global demo age_forfait* age_prepaid* age_fbloque* age_lowcost* age_network*
global othersFE timeSince FEqtr* FEre*
global ivs iv_network_* iv_product_* ant2g* ant3g* ant4g*
global ivd phatIV iv_diff_netw_* iv_diff_prod_* 
global ivr iv_network_* iv_product_* 

/*******************************************************
 Prepare data for Matlab 
*******************************************************/
format %9.0g quarter 
format %20.0g ms price py income roaming
global antSet ant2g ant3g ant4g 

replace network = 8 if network==11
replace network = 9 if network==12
replace network =10 if network==13
replace operator = 5 if operator==11
replace operator = 6 if operator==12
replace operator = 7 if operator==13
compress
sort qtr region network prepost
drop id
xtset networkRegion qtr
gen id = _n
gen idLag = L.id
replace idLag = id if idLag==.
gen byte indexSample = (id~=idLag)
sort qtr region network prepost

global core qtr region operator network population ms ms0 price phatIV ///
	income sdIncome indexSample prepost id idLag logIncome sdlogIncome

keep $core $prodchar1 $networkFE $demo $othersFE $antSet $ivs $ivd
compress
save testIV824, replace

/*******************************************************
 Export to Matlab for BLP estimation
*******************************************************/
use testIV824, clear
keep  $core 
order $core 
format _all %21.0g
export delimited using demand824.csv, replace nolabel

use testIV824, clear
keep  $prodchar1 $networkFE $demo $othersFE
order $prodchar1 $networkFE $demo $othersFE
format _all %21.0g
export delimited using Xinput824.csv, replace nolabel

use testIV824, clear
keep   $ivs
order  $ivs
format _all %21.0g
export delimited using ZinputBlp824.csv, replace nolabel

use testIV824, clear
keep   $ivr
order  $ivr
format _all %21.0g
export delimited using ZinputBlp824core.csv, replace nolabel

use testIV824, clear
keep  lant2g* lant3g* lant4g* pblocked prepaid timeSince
order lant2g* lant3g* lant4g* pblocked prepaid timeSince
format _all %21.0g
export delimited using DiffIVinput824reduced.csv, replace nolabel

use testIV824, clear
keep  lant2g* lant3g* lant4g* pblocked prepaid  
order lant2g* lant3g* lant4g* pblocked prepaid 
format _all %21.0g
export delimited using DiffIVinput824reduced2.csv, replace nolabel

use testIV824, clear
collapse (first) income sdIncome logIncome sdlogIncome, by (region)
format _all %21.0g
export delimited using income.csv, replace nolabel

/*******************************************************
 Export modified files 
*******************************************************/
*** Drop allowances
use testIV824, clear
global prodchar2 lant2g* lant3g* lant4g* pblocked prepaid
keep  $prodchar2 $networkFE $demo $othersFE
order $prodchar2 $networkFE $demo $othersFE
format _all %21.0g
export delimited using Xinput824NoAllow.csv, replace nolabel

use testIV824, clear
regress price $prodchar2 $networkFE $demo $othersFE $ivs
drop phatIV
predict phatIV
keep  $core 
order $core 
format _all %21.0g
export delimited using demand824NoAllow.csv, replace nolabel

*** Increase market size to 50%
use testIV824, clear
replace ms = ms / 1.5
egen sumMS = total(ms), by (region qtr)
replace ms0 = 1 - sumMS
keep  $core 
order $core 
format _all %21.0g
export delimited using demand824ms15.csv, replace nolabel

