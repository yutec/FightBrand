/*******************************************************
 Construct prediced national price
*******************************************************/
cd "~/work/kantar/brand/work/"

set more off
set type double, permanently
clear all
use  analysis824extra, clear
xtset networkRegion quarter 

global prodchar2 lant2g* lant3g* lant4g* pblocked prepaid
global networkFE FEnet*
global demo age_forfait* age_prepaid* age_fbloque* age_lowcost* age_network*
global othersFE timeSince FEqtr* FEre*
global ivs iv_network_* iv_product_* ant2g* ant3g* ant4g*
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

keep $core $prodchar2 $networkFE $demo $othersFE $antSet $ivr
compress
save testIV824extra, replace

/*******************************************************
 Export to Matlab for BLP estimation
*******************************************************/
use testIV824extra, clear
keep  $core 
order $core 
format _all %21.0g
export delimited using demand824extra.csv, replace nolabel

use testIV824extra, clear

keep  $prodchar2 $networkFE $demo $othersFE
order $prodchar2 $networkFE $demo $othersFE
format _all %21.0g
export delimited using Xinput824extra.csv, replace nolabel

use testIV824extra, clear
keep   $ivr
order  $ivr
format _all %21.0g
export delimited using ZinputBlp824coreextra.csv, replace nolabel
