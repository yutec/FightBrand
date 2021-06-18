/*******************************************************
 Sample statistics
*******************************************************/
cd "~/work/kantar/brand/work"
clear all
use analysis824, clear

replace ant2g = ant2g*100
replace ant3g = ant3g*100
replace ant4g = ant4g*100
replace ant3gRoam = ant3gRoam*100
replace allowCall = allowCall*1e3
replace allowData = allowData*1e3

gen subscriber = ms*pop/1000
gen forfait = (prepost==3)

*** Table 1
drop ant2gRoam ant3gRoam ant4gRoam
su subscriber price ant* prepaid postpaid forfait allowCall allowData

save table824, replace

* Income draws from empirical distribution for output
use incomeFile, clear
label variable numericIncome "Income"
label variable logIncome "Log(Income)"

set seed 54321
set sortseed 6789

keep region2016 numericIncome
drop if numericIncome==.
bsample 200, strata(region2016)

gen y = 1/numericIncome
rename numericIncome income
rename region2016 region
order region income y
export delimited using incomeEMdraws.csv, replace

*** Table 2
use table824, clear
drop allowText
collapse (mean) price ant2g ant3g ant4g allow* [iw=ms], by(network region quarter)
tabstat ant2g ant3g ant4g allow* price, by (network) format(%6.0g)

use table824, clear
collapse (sum) ms, by(network region quarter)
tabstat ms, by (network) format(%6.0g)

*** Table 3
use table824, clear
keep if qtr==4 | qtr==16
collapse (mean) ms, by (network prepost qtr)
// bysort prepost: tab network if qtr==4, su (ms)
// bysort prepost: tab network if qtr==16, su (ms)

egen id = group(network qtr)
reshape wide ms, i(id) j(prepost)
order qtr network ms*
* Left columns
li if qtr==4
* Right columns
li if qtr==16

* Market size growth
use analysis824, clear
tab qtr, su(ms0)

