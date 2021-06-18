* Figure 4: Years of entry by low-cost brands in the OECD countries
* Fig4a: Timing of entry (number of fighting brand entries per year for OECD countries)
cd ~/work/kantar/brand/data/oecd
use "crosscountry.dta", clear
twoway bar entries year, barw(0.8) xtitle("Year") ytitle("Number of entries") graphregion(fcolor(white)) fcolor(gs7) xline(2011, lcolor(red))
graph export fig4a.pdf, replace
* Fig4b: Timing of first entry (number of 'earliest' entries per year for OECD countries)
use startyear, clear
drop if startyear==.
gen cnt=1
collapse (sum) cnt, by(startyear)
twoway bar cnt startyear, barw(0.8) yscale(r(0 5)) ymtick(0(1)5) ylabel(0(1)5) xtitle("Year") ytitle("Number of earliest entries") graphregion(fcolor(white)) fcolor(gs7) xline(2011, lcolor(red))
graph export fig4b.pdf, replace
