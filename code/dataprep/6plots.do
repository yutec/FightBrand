/*******************************************************
 Load processed data produced by "cleanData.do" file
*******************************************************/
cd "~/work/kantar/brand/work"

clear all
use anfrData822, clear

collapse (mean) price ant3g (sum) ms, by (network quarter region)
collapse (mean) ms price ant3g, by (network quarter)
label variable price "Price"
label variable ant3g "3G antenna"
label variable quarter "Quarter"
label variable ms "Share"
xtset network quarter

*** Figure 2
graph twoway ///
	(connected ms quarter if network==1, msize(small) msymbol(D) lcolor(orange) mcolor(orange)) ///
	(connected ms quarter if network==5, msize(small) msymbol(D) lcolor(orange) mcolor(orange) lpattern(shortdash)) ///
	(connected ms quarter if network==2, msize(small) msymbol(T) lcolor(cranberry) mcolor(cranberry)) ///
	(connected ms quarter if network==7, msize(small) msymbol(T) lcolor(cranberry) mcolor(cranberry) lpattern(shortdash)) ///
	(connected ms quarter if network==3, msize(small) msymbol(S) lcolor(navy) mcolor(navy)) ///
	(connected ms quarter if network==6, msize(small) msymbol(S) lcolor(navy) mcolor(navy) lpattern(shortdash)) ///
	(connected ms quarter if network==4, msize(small) msymbol(O) lcolor(gs2) mcolor(gs2)), ///
	legend(label(1 Orange) label(2 Sosh) label(3 SFR) label(4 Red) ///
	label(5 Bouygues) label(6 B&You) label(7 Free)) ///
	saving(share1, replace) scheme(sj) graphregion(fcolor(white))
graph export ms1.pdf, replace

*** Figure 1
graph twoway ///
	(connected price quarter if network==1, msize(small) msymbol(D) lcolor(orange) mcolor(orange)) ///
	(connected price quarter if network==5, msize(small) msymbol(D) lcolor(orange) mcolor(orange) lpattern(shortdash)) ///
	(connected price quarter if network==2, msize(small) msymbol(T) lcolor(cranberry) mcolor(cranberry)) ///
	(connected price quarter if network==7, msize(small) msymbol(T) lcolor(cranberry) mcolor(cranberry) lpattern(shortdash)) ///
	(connected price quarter if network==3, msize(small) msymbol(S) lcolor(navy) mcolor(navy)) ///
	(connected price quarter if network==6, msize(small) msymbol(S) lcolor(navy) mcolor(navy) lpattern(shortdash)) ///
	(connected price quarter if network==4, msize(small) msymbol(O) lcolor(gs2) mcolor(gs2)), ///
	legend(label(1 Orange) label(2 Sosh) label(3 SFR) label(4 Red) ///
	label(5 Bouygues) label(6 B&You) label(7 Free)) ///
	ysc(r(0 30)) ylabel(0(5)30) saving(price, replace) scheme(sj) graphregion(fcolor(white)) 
graph export price1.pdf, replace

*** Appendix Figure A.1
graph twoway ///
	(line price quarter if network==11, recast(connected) msize(small) msymbol(D) lcolor(orange) mcolor(orange)) ///
	(line price quarter if network==12, recast(connected) msize(small) msymbol(T) lcolor(cranberry) mcolor(cranberry)) ///
	(line price quarter if network==13, recast(connected) msize(small) msymbol(S) lcolor(navy) mcolor(navy)), ///
	legend(label(1 Orange MVNO) label(2 SFR MVNO) label(3 Bouygues MVNO)) ///
	ysc(r(0 30)) ylabel(0(5)30) saving(price, replace) scheme(sj) graphregion(fcolor(white)) 
graph export price2.pdf, replace

