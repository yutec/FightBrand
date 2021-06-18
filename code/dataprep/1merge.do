cd "~/work/kantar/brand/work"
clear all

/*******************************************************
 Date format variable
*******************************************************/
import delimited "~/work/kantar/brand/data/pre2014/France_Data.csv", clear
save franceData1, replace
import delimited "~/work/kantar/brand/data/post2014/FranceDatav2.csv", clear
save franceData2, replace

use franceData2, clear
set more off
replace operatingsystem = "10" if operatingsystem=="A"
local varStringType1 g_1 acq additional bill boughttype chgnumber choice* con
local varStringType2 family* newused nps old* package* pay1edit shop sim_why
local varStringType3 tarif_cost topup type1 whychg screensize touchphone oper
foreach var of var `varStringType1' `varStringType2' `varStringType3' {
	replace `var' = "" if `var'=="NULL"
	destring `var', replace
}
drop monthlyspendedited
recast long pay1 
recast int payplan1
drop if period < 201401
save franceData2append, replace

use franceData1, clear
append using franceData2append, gen(tagAppend)
rename g_1 _4g_1
save franceData, replace

/*******************************************************
 Date format variable
*******************************************************/
use franceData, clear
tostring period, gen(datestring)
gen int datevar = date(datestring, "YM")
format datevar %td
gen int monthvar = mofd(datevar)
format monthvar %tm

gen int quarter = qofd(datevar)
format quarter %tq

tostring acquire_date, gen(adatestring)
gen int adatevar = date(adatestring, "YM")
format adatevar %td
gen int amonthvar = mofd(adatevar)
format amonthvar %tm

bysort u_other_id network prepost con_dur: egen int initmonth = min(monthvar)

drop adatevar

/*******************************************************
 Variable & value labeling
*******************************************************/
gen planType = 0
replace planType = 1 if tarif_new1=="1000000000" | tarif_new1=="1000000001"
replace planType = 2 if tarif_new1=="0100000000" | tarif_new1=="0100000001"
replace planType = 3 if tarif_new1=="0010000000" | tarif_new1=="0010000001"
replace planType = 4 if tarif_new1=="1100000000" | tarif_new1=="1100000001"
replace planType = 5 if tarif_new1=="1010000000" | tarif_new1=="1010000001"
replace planType = 6 if tarif_new1=="0110000000" | tarif_new1=="0110000001"
replace planType = 7 if tarif_new1=="1110000000" | tarif_new1=="1110000001"

replace planType = 1 if tarif_new1=="100" | tarif_new1=="1000" | tarif_new1=="10000"
replace planType = 5 if tarif_new1=="10100"
replace planType = 4 if tarif_new1=="1100" | tarif_new1=="11000"
replace planType = 5 if tarif_new1=="11100"

drop tarif_new1
label define planTypeLabel 1 "Call only"
label define planTypeLabel 2 "Data only", add
label define planTypeLabel 3 "Text only", add
label define planTypeLabel 4 "Call+Data", add
label define planTypeLabel 5 "Call+Text", add
label define planTypeLabel 6 "Data+Text", add
label define planTypeLabel 7 "All inclus", add
label define planTypeLabel 0 "NA", add
label values planType planTypeLabel

label define prepostLabel  0 "NA"
label define prepostLabel  1 "Prepaid", add
label define prepostLabel  2 "Postpaid", add
label define prepostLabel  3 "F. Bloqué", add
label define prepostLabel 99 "No Answer", add
label values prepost1 prepostLabel

label variable tarif_cost1 "Tariff cost contracted"
replace tarif_cost1 = tarif_cost1 / 100

label variable bill1 "Bill paid"
label define billLabel   0 "NA"
label define billLabel   1 "0-5€", add
label define billLabel   2 "6-10€", add
label define billLabel   3 "11-20€", add
label define billLabel   4 "21-30€", add
label define billLabel   5 "31-40€", add
label define billLabel   6 "41-50€", add
label define billLabel   7 "51-60€", add
label define billLabel   8 "61-80€", add
label define billLabel   9 "81-100€", add
label define billLabel  10 "101-150€", add
label define billLabel  11 "151-200€", add
label define billLabel  12 "201€+", add
label define billLabel  13 "Don't know", add
label define billLabel  14 "Bundle", add
label define billLabel 999 "No answer", add 
label values bill1 billLabel

gen numericBill = 0
replace numericBill = 2.5 if bill== 1 
replace numericBill = 7.5 if bill== 2 
replace numericBill =  15 if bill== 3 
replace numericBill =  25 if bill== 4 
replace numericBill =  35 if bill== 5 
replace numericBill =  45 if bill== 6 
replace numericBill =  55 if bill== 7 
replace numericBill =  70 if bill== 8 
replace numericBill =  90 if bill== 9 
replace numericBill = 125 if bill==10 
replace numericBill = 175 if bill==11 
replace numericBill = 200 if bill==12 

label define topupLabel   0 "NA"
label define topupLabel   1 "0-5€", add
label define topupLabel   2 "6-10€", add
label define topupLabel   3 "11-20€", add
label define topupLabel   4 "21-30€", add
label define topupLabel   5 "31-40€", add
label define topupLabel   6 "41-50€", add
label define topupLabel   7 "51-60€", add
label define topupLabel   8 "61-80€", add
label define topupLabel   9 "81-100€", add
label define topupLabel  10 "101-150€", add
label define topupLabel  11 "151-200€", add
label define topupLabel  12 "201€+", add
label define topupLabel  13 "Don't know", add
label define topupLabel 999 "No answer", add 
label values topup1 topupLabel

gen numericTopup = .
replace numericTopup =  2.5 if topup==1
replace numericTopup =  7.5 if topup==2
replace numericTopup =   15 if topup==3
replace numericTopup =   25 if topup==4
replace numericTopup =   35 if topup==5
replace numericTopup =   45 if topup==6
replace numericTopup =   55 if topup==7
replace numericTopup =   70 if topup==8
replace numericTopup =   90 if topup==9
replace numericTopup =  125 if topup==10
replace numericTopup =  175 if topup==11
replace numericTopup =  200 if topup==12
replace numericTopup =    0 if numericTopup==. & (prepost==2|prepost==3)

label define networkLabel   0 "NA"
label define networkLabel   1 "3 (Three)", add
label define networkLabel   5 "Auchan", add
label define networkLabel   7 "Bouygues", add
label define networkLabel   8 "Breizh", add
label define networkLabel  12 "Carrefour", add
label define networkLabel  14 "Coriolis", add
label define networkLabel  15 "Darty box", add
label define networkLabel  16 "Debitel", add
label define networkLabel  19 "Fnac", add
label define networkLabel  23 "Leclerc", add
label define networkLabel  24 "M6", add
label define networkLabel  27 "Neuf", add
label define networkLabel  28 "France tel", add
label define networkLabel  29 "NRJ mobile", add
label define networkLabel  30 "Numericable", add
label define networkLabel  32 "Orange", add
label define networkLabel  33 "Casino", add
label define networkLabel  36 "SFR", add
label define networkLabel  41 "Tele 2", add
label define networkLabel  45 "Universal", add
label define networkLabel  47 "Virgin", add
label define networkLabel  49 "Vodafone", add
label define networkLabel  52 "Don't know", add
label define networkLabel  59 "Poste", add
label define networkLabel  66 "BASE", add
label define networkLabel  97 "Simyo", add
label define networkLabel 134 "Lebara", add
label define networkLabel 662 "T mobile", add
label define networkLabel 673 "Lyca", add
label define networkLabel 718 "Simplicime", add
label define networkLabel 727 "0 forfait", add
label define networkLabel 728 "PRIXTEL", add
label define networkLabel 736 "MobiStar", add
label define networkLabel 769 "La Poste", add
label define networkLabel 771 "Free", add
label define networkLabel 772 "Sosh", add
label define networkLabel 773 "B&You", add
label define networkLabel 774 "Red", add
label define networkLabel 779 "C le mobile", add
label define networkLabel 169 "Other", add
label define networkLabel 9998 "Other", add
label values network1 networkLabel

gen byte hostNetwork1 = 0 // Orange network dummy
gen byte hostNetwork2 = 0 // SFR network
gen byte hostNetwork3 = 0 // Bouygues network
gen byte hostNetwork4 = 0 // Free network

replace network=0 if network==1 // 3 mobile roaming
replace network=0 if network==4 // AOL mobile 
replace network=0 if network==31 // O2 roaming
replace network=0 if network==42 // Ten mobile enterprise
replace network=0 if network==43 // Tesco mobile roaming
replace network=0 if network==49 // Vodafone roaming
replace network=0 if network==52 // Don't know
replace network=0 if network==58 // Wind mobile roaming
replace network=0 if network==66 // BASE roaming
replace network=0 if network==91 // Ortel mobile roaming
replace network=0 if network==122 // ACN mobile with unknown network
replace network=0 if network==133 // Happy Movil roaming
replace network=0 if network==135 // Movistar roaming
replace network=0 if network==460 // Telecom Italia Mobile roaming
replace network=0 if network==662 // T-Mobile roaming
replace network=0 if network==663 // TracFone Wireless
replace network=0 if network==169
replace network=0 if network==9998

label define conDurLabel 0 "NA"
label define conDurLabel 1 "1-12 months", add
label define conDurLabel 2 "13-18 months", add
label define conDurLabel 3 "19-24 months", add
label define conDurLabel 4 "25-36 months", add
label define conDurLabel 5 "37+ months", add
label define conDurLabel 6 "0 month", add
label define conDurLabel 9 "No answer", add
label values con_dur1 conDurLabel

label define chanTypeLabel  0 "NA"
label define chanTypeLabel  1 "Internet", add
label define chanTypeLabel  2 "Phone", add
label define chanTypeLabel  3 "Shop", add
label define chanTypeLabel  4 "Mail", add
label define chanTypeLabel  5 "Other", add
label define chanTypeLabel 99 "No answer", add
label values type1 chanTypeLabel
label variable type1 "Channel type"

label define chgnetLabel  0 "NA"
label define chgnetLabel  1 "Yes", add
label define chgnetLabel  2 "No", add
label define chgnetLabel 99 "No answer", add
label values chgnet1 chgnetLabel

label define chgnumberLabel  0 "NA"
label define chgnumberLabel  1 "Yes", add
label define chgnumberLabel  2 "No", add
label define chgnumberLabel 99 "No answer", add
label values chgnumber1 chgnumberLabel

label define replaceLabel 0 "NA"
label define replaceLabel 1 "Replace", add
label define replaceLabel 2 "First", add
label define replaceLabel 3 "Additional", add
label define replaceLabel 4 "No reply", add
label values replace1 replaceLabel

label variable boughttype1 "Mobile phone payment type"
replace pay1 = pay1 / 100
label variable pay1 "One-off cost of mobile phone"

replace payplan1 = payplan1 / 100
label variable payplan1 "Monthly cost of mobile phone"
label variable payplanmonth "Months for mobile phone payment"

label variable acquire_date1 "Phone acquisition date"

label variable monthlyspend "Bill due last month"
rename monthlyspend m_spend

label define dataLabel  0 "NA"
label define dataLabel  1 "No Internet", add
label define dataLabel  2 "Unlimited", add
label define dataLabel  3 "Don't know", add
label define dataLabel 10 "50MB", add
label define dataLabel 11 "100MB", add
label define dataLabel 12 "200MB", add
label define dataLabel 13 "300MB", add
label define dataLabel 14 "500MB", add
label define dataLabel 15 "1GB", add
label define dataLabel 16 "2GB", add
label define dataLabel 17 "2GB+", add
label define dataLabel 99 "No answer", add
label values package_data1 dataLabel

label define callLabel  0 "NA"
label define callLabel  2 "Unlimited", add
label define callLabel  3 "Don't know", add
label define callLabel 10 "50min", add
label define callLabel 11 "100min", add
label define callLabel 12 "200min", add
label define callLabel 13 "500min", add
label define callLabel 14 "700min", add
label define callLabel 15 "1000min", add
label define callLabel 16 "1500min", add
label define callLabel 17 "1500min+", add
label define callLabel 99 "No answer", add
label values package_calls1 callLabel

label define textLabel  0 "NA"
label define textLabel  2 "Unlimited", add
label define textLabel  3 "Don't know", add
label define textLabel 10 "50", add
label define textLabel 11 "100", add
label define textLabel 12 "200", add
label define textLabel 13 "300", add
label define textLabel 14 "500", add
label define textLabel 15 "700", add
label define textLabel 16 "1000", add
label define textLabel 17 "1500", add
label define textLabel 18 "3000", add
label define textLabel 19 "3000+", add
label define textLabel 99 "No response", add
label values package_texts1 textLabel

label define shopLabel   0 "NA"
label define shopLabel   1 "The phone house", add
label define shopLabel   7 "Virgin Megastore", add
label define shopLabel   3 ///
		"Boutique ORANGE/Agence France Telecom/mobistore/Orange.fr", add
label define shopLabel  21 "Auchan", add
label define shopLabel  23 "Carrefour", add
label define shopLabel  25 "Club Bouygues telecom /bouyguestelecom.fr", add
label define shopLabel  31 "Leclerc", add
label define shopLabel  33 "Espace SFR/SFR.fr / Neuf Cegetel", add
label define shopLabel  96 "Internet", add
label define shopLabel 383 "Apple", add
label define shopLabel 450 "France Telecom", add
label define shopLabel 484 "Boutique SFR", add
label define shopLabel 998 "Other", add
label values shop1 shopLabel

label define simnumLabel  0 "NA"
label define simnumLabel  1 "1", add
label define simnumLabel  2 "2+", add
label define simnumLabel 99 "No answer", add
label values sim_number1 simnumLabel

label define whopayLabel  0 "NA"
label define whopayLabel  1 "Self", add
label define whopayLabel  2 "Company", add
label define whopayLabel  3 "Company/Self", add
label define whopayLabel  4 "Other", add
label define whopayLabel 99 "No answer", add
label values whopays1 whopayLabel

label define _4gLabel 0 "NA"
label define _4gLabel 1 "4G", add
label define _4gLabel 2 "Not 4G", add
label values _4g_1 _4gLabel

sort u_other_id period
save franceDataLabeled, replace

/*******************************************************
 Merge data
*******************************************************/
/*** Merge with phone dataset ***/
insheet using "~/work/kantar/brand/data/post2014/PhoneList.csv", clear
rename ans_code1 phone1
rename maste_answer phoneName
rename brand phoneBrand
rename fr_description phoneNameFr
rename brandcode phoneBrandCode
rename gphone _3gphone

label define _3gLabel 0 "2G"
label define _3gLabel 1 "3G", add
label define _3gLabel 2 "4G", add
label define _3gLabel 9 "NA", add
label values _3gphone _3gLabel

sort phone1
duplicates report phone1
replace operatingsystem = "10" if operatingsystem=="A"
replace operatingsystem = "10" if operatingsystem=="B"
replace operatingsystem = "10" if operatingsystem=="C"
destring operatingsystem, replace
save phoneList2014, replace

use franceDataLabeled, clear
merge m:1 phone1 using phoneList2014, keep(match master) gen(mergePhonelist2014)

tab phone1 if mergePhonelist==1	// always phone1=0 if  if it exits only in master data
save phoneMerged, replace

/*** Merge with panel demographics dataset ***/
insheet using "~/work/kantar/brand/data/pre2014/PanelDemogs.csv", clear
duplicates report u_other_id
duplicates report u_other_id age
duplicates report u_other_id hhsize region children income
	//almost all of the duplicates are because of multiple age variables
duplicates report u_other_id if hhsize==1
	//even duplicates if hhsize=1
duplicates drop
duplicates drop u_other_id, force
	// brute force duplicates drop (need to understand why age is duplicated)
duplicates report u_other_id
drop socialclass occpan
sort u_other_id
save panel2013, replace

insheet using "~/work/kantar/brand/data/post2014/FrancePanelv2.csv", clear
duplicates report u_other_id
replace hhincome = "00" if hhincome=="NULL"
destring hhincome, gen (income)
drop hhincome socialclass occupationpan u_country
sort u_other_id
save panel2014, replace

use phoneMerged, clear
merge m:1 u_other_id using panel2013, keep(match master) gen(mergeDemo2013)
merge m:1 u_other_id using panel2014, keep(match master) gen(mergeDemo2014)
drop if mergeDemo2013==1 & mergeDemo2014==1 // Drop 11 obs with missing demo

gen numericIncome = .
replace numericIncome =  300 if income== 1
replace numericIncome =  450 if income== 2
replace numericIncome =  600 if income== 3
replace numericIncome =  750 if income== 4
replace numericIncome =  900 if income== 5
replace numericIncome = 1100 if income== 6
replace numericIncome = 1200 if income== 7
replace numericIncome = 1400 if income== 8
replace numericIncome = 1500 if income== 9
replace numericIncome = 1900 if income==10
replace numericIncome = 2300 if income==11
replace numericIncome = 2700 if income==12
replace numericIncome = 3000 if income==13
replace numericIncome = 3800 if income==14
replace numericIncome = 4500 if income==15
replace numericIncome = 5400 if income==16
replace numericIncome = 7000 if income==17
replace numericIncome = 8000 if income==18
save panel_demogs, replace

save demoMerged, replace

/*** Merge with deptINSEE dataset ***/
insheet using "~/work/kantar/brand/data/pre2014/deptINSEE1.csv", clear
rename deptinsee deptinsee1
save deptINSEE1, replace
insheet using "~/work/kantar/brand/data/pre2014/deptINSEE2.csv", clear
rename panel_number u_other_id
rename deptinse deptinsee2
save deptINSEE2, replace
insheet using "~/work/kantar/brand/data/pre2014/deptINSEE3.csv", clear
rename dptinsee deptinsee3
save deptINSEE3, replace

use demoMerged, clear
inspect deptinse
rename deptinse deptinsee
merge m:1 u_other_id using deptINSEE1, keep(match master) gen(mergeDeptINSEE1) keepusing(deptinsee1)
replace deptinsee = deptinsee1 if deptinsee==.
merge m:1 u_other_id using deptINSEE2, keep(match master) update gen(mergeDeptINSEE2) keepusing(deptinsee2)
replace deptinsee = deptinsee2 if deptinsee==.
merge m:1 u_other_id using deptINSEE3, keep(match master) update gen(mergeDeptINSEE3) keepusing(deptinsee3)
replace deptinsee = deptinsee3 if deptinsee==.
unique(u_other_id) if deptinsee==.
*li u_other_id period network prepost if deptinsee==.
drop deptinsee1-deptinsee3 mergeDeptINSEE*
save deptInseeMerged, replace

/*** Merge with contractspend dataset ***/
insheet using "~/work/kantar/brand/data/pre2014/bill2.csv", clear
save bill2, replace

use deptInseeMerged, clear
merge m:1 u_other_id period using bill2, keep(match master) gen(mergeBill2)
save contractspendMerged, replace

/*** Merge with INSEE department/region file ***/
import delimited using "~/work/kantar/brand/data/pre2014/depts2011.txt", clear
drop if dep=="2B"  // Leave 1 dept for Corse
replace dep = "20" if dep=="2A"
destring dep, gen(deptinsee)
drop if deptinsee > 99
keep region deptinsee 
compress
save regionCodeINSEE, replace

use contractspendMerged, clear
drop region
merge m:1 deptinsee using regionCodeINSEE, gen(mergeRegionCode) 
compress
save allMerged, replace

/*******************************************************
 Build ANFR data "ssc install carryforward"
*******************************************************/
clear all
import delimited using "~/work/kantar/brand/data/post2014/anfr2016.csv", clear
*import delimited using "./pre2014/anfr.csv", clear
replace department="020" if department=="02A" | department=="02B"
*replace department="20" if department=="2A" | department=="2B"
destring department, gen(deptinsee)
merge m:1 deptinsee using regionCodeINSEE, gen(mergeRegion)
gen int datevar = date(datestr, "YMD")
format datevar %td
gen int monthvar = mofd(datevar)
format monthvar %tm
gen int quarter = qofd(datevar)
format quarter %tq
drop if monthvar>671  // drop obs after 2015 Dec
tab generation, gen(antGen)
collapse (sum) antGen*, by (region operator quarter)
order region operator quarter

sort region operator quarter
by region operator: gen int antAll2g = sum(antGen1) 
by region operator: gen int antAll3g = sum(antGen2) 
by region operator: gen int antAll4g = sum(antGen3) 
label variable antAll2g "Cumulative number of 2G antennas"
label variable antAll3g "Cumulative number of 3G antennas"
label variable antAll4g "Cumulative number of 4G antennas"

gen byte antNetwork = 1 if operator=="ORANGE"
replace antNetwork = 2 if operator=="SFR"
replace antNetwork = 3 if operator=="BOUYGUES TELECOM"
replace antNetwork = 4 if operator=="FREE MOBILE"
keep region antNetwork quarter antAll*

label define networkAntLabel 1 "Orange"
label define networkAntLabel 2 "SFR", add
label define networkAntLabel 3 "Bouygues", add
label define networkAntLabel 4 "Free", add
label define networkAntLabel 0 "Unknown", add
label values antNetwork networkAntLabel
order region antNetwork antAll*

egen panelid = group(region antNetwork)
tsset panelid quarter
tsfill
bysort panelid: carryforward antAll2g, replace
bysort panelid: carryforward antAll3g, replace
bysort panelid: carryforward antAll4g, replace
bysort panelid: carryforward antNetwork, replace
bysort panelid: carryforward region, replace
tsfill, full
bysort panelid: carryforward antAll2g, replace
bysort panelid: carryforward antAll3g, replace
bysort panelid: carryforward antAll4g, replace
bysort panelid: carryforward antNetwork, replace
bysort panelid: carryforward region, replace

gsort panelid - quarter
bysort panelid: carryforward antAll2g, replace
bysort panelid: carryforward antAll3g, replace
bysort panelid: carryforward antAll4g, replace
bysort panelid: carryforward antNetwork, replace
bysort panelid: carryforward region, replace

sort region antNetwork quarter
xtset panelid quarter
gen F_ant3g = F.antAll3g
gen F_ant4g = F.antAll4g
gen L_ant2g = L.antAll2g
gen L_ant3g = L.antAll3g
gen L_ant4g = L.antAll4g
drop panelid
tab antNetwork, gen(hostNetwork)
drop if quarter<204 //monthvar<612  drop obs before 2011 Jan
save anfr2016, replace

keep if hostNetwork1==1
rename antAll2g antAll2g1
rename antAll3g antAll3g1
rename antAll4g antAll4g1
rename F_ant3g  F_ant3g1
rename F_ant4g  F_ant4g1
rename L_ant2g  L_ant2g1
rename L_ant3g  L_ant3g1
rename L_ant4g  L_ant4g1
save anfr1, replace
use anfr2016, clear
keep if hostNetwork2==1
rename antAll2g antAll2g2
rename antAll3g antAll3g2
rename antAll4g antAll4g2
rename F_ant3g  F_ant3g2
rename F_ant4g  F_ant4g2
rename L_ant2g  L_ant2g2
rename L_ant3g  L_ant3g2
rename L_ant4g  L_ant4g2
save anfr2, replace
use anfr2016, clear
keep if hostNetwork3==1
rename antAll2g antAll2g3
rename antAll3g antAll3g3
rename antAll4g antAll4g3
rename F_ant3g  F_ant3g3
rename F_ant4g  F_ant4g3
rename L_ant2g  L_ant2g3
rename L_ant3g  L_ant3g3
rename L_ant4g  L_ant4g3
save anfr3, replace
use anfr2016, clear
keep if hostNetwork4==1
rename antAll2g antAll2g4
rename antAll3g antAll3g4
rename antAll4g antAll4g4
rename F_ant3g  F_ant3g4
rename F_ant4g  F_ant4g4
rename L_ant2g  L_ant2g4
rename L_ant3g  L_ant3g4
rename L_ant4g  L_ant4g4
save anfr4, replace

//*** end of file ***//

// Erase temporary files
erase phoneList2014.dta 
erase phoneMerged.dta
erase panel2013.dta
erase panel2014.dta
erase demoMerged.dta
erase deptInseeMerged.dta
erase bill2.dta
*erase regionCodeINSEE.dta
erase anfr2016.dta
erase deptINSEE1.dta
erase deptINSEE2.dta
erase deptINSEE3.dta
erase contractspendMerged.dta
erase franceData2append.dta
erase franceDataLabeled.dta
