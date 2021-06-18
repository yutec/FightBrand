/*******************************************************
 Load merged data produced by "mergeData.do" file
*******************************************************/
cd "~/work/kantar/brand/work"	

clear all
use allMerged, clear
drop unique*

/*******************************************************
 Drop duplicates
 Cases:
 1. Complete duplicates
 2. Phone duplicates (with multiple acuire_date or plans)
 
 Rule of drop: Keep obs with less missing variables
*******************************************************/
duplicates report // 62 full duplicates
duplicates drop

// Service changers
duplicates tag u_other_id period phone1, gen (dupPhone)
*tab period dupPhone // duplicates mostly concentrated in Dec 2011-Jan 2012

replace network = . if network==0
replace prepost = . if prepost==0
replace con_dur = . if con_dur==0 | con_dur==9
replace planType = . if planType==0
replace package_call = . if package_call==0 | package_call==3 | package_call==99
replace package_data = . if package_data==0 | package_data==3 | package_data==99
replace package_text = . if package_text==0 | package_text==3 | package_text==99
replace bill = . if bill==0
replace topup = . if topup==0
replace phone1 = . if phone1==0
replace acquire_date = . if acquire_date==0

egen missVar = rowmiss(u_other_id period network prepost con_dur package* planType tarif bill topup m_spend phone1 ///
	acquire_date) 
egen missVarMin = min(missVar) if dupPhone==1, by (u_other_id)
*li u period network prepost con_d package* planType tarif bill topup m_spend phone1 missVar* if dupPhone==1

bysort u_other_id period: drop if dupPhone==1 & missVar>missVarMin
duplicates tag u_other_id period phone1, gen (dupPhone1) 
*li u period network prepost con_dur package* planType tarif bill topup m_spend phoneName acqu if dupPhone1==1
sort u_other_id period network phone1 acquire_date
duplicates drop u_other_id period phone1, force

duplicates report u_other_id period
duplicates report u_other_id period network prepost
duplicates tag u_other_id period network prepost, gen (dupPlan)
drop missVarMin
egen missVarMin = min(missVar) if dupPlan==1, by (u_other_id)
*li u period network prepost con_d pack* planType tarif bill topup m_s phoneName acqu missVar* if dupPlan==1
bysort u_other_id period: drop if dupPlan==1 & missVar>missVarMin

duplicates tag u_other_id period network prepost, gen (dupPlan1)
*li u period network prepost con_d pack* planType tarif bill topup m_s phoneName acqu missVar* if dupPlan1==1
sort u_other_id period network prepost phone1
duplicates drop u_other_id period network prepost, force
duplicates report u_other_id period network prepost
drop dup*

duplicates tag u_other_id period, gen (dup)
*li u period network prepost con_d pack* planType tarif bill topup m_s phoneName acqu missVar* if dup==1
drop missVarMin
egen missVarMin = min(missVar) if dup==1, by (u_other_id)
bysort u_other_id period: drop if dup==1 & missVar>missVarMin
duplicates tag u_other_id period, gen (dup1)
*li u period network prepost con_d pack* planType tarif bill topup m_s phoneName acqu missVar* if dup1==1
drop if dup1==1 & acquire_date < 199901

drop missVar* dup*

duplicates report u_other_id period

/*******************************************************
 Impute missing network  
*******************************************************/
sort u_other_id monthvar
xtset u_other_id monthvar
gen gapNetwork = (network==. & u_other_id==u_other_id[_n+1] & chgnet[_n+1]==2)
gen gapPrepost = (prepost[_n-1]==prepost[_n+1]|l.prepost==.|tarif_c==tarif_c[_n+1]|bill==bill[_n+1]| ///
	topup==topup[_n+1])
replace network = network[_n+1] if gapNetwork==1
replace prepost = prepost[_n+1] if gapNetwork==1 & gapPrepost==1
replace chgnet1 = 2             if gapNetwork==1 & network==network[_n-1] 
replace con_dur = con_dur[_n+1] if gapNetwork==1 & gapPrepost==1

replace tarif_c = tarif_c[_n+1] if gapNetwork==1 & gapPrepost==1
replace topup   = topup[_n+1]   if gapNetwork==1 & gapPrepost==1
replace bill1   = bill1[_n+1]   if gapNetwork==1 & gapPrepost==1
replace package_call = package_call[_n+1] if gapNetwork==1 & gapPrepost==1
replace package_data = package_data[_n+1] if gapNetwork==1 & gapPrepost==1
replace package_text = package_text[_n+1] if gapNetwork==1 & gapPrepost==1
drop gapNetwork gapPrepost

/*******************************************************
 Clean up tarif_cost
*******************************************************/
sort u period
egen maxtarif = max(tarif_cost), by(u)
gen hightarif1 = (maxtarif>200 & maxtarif<9999)
gen hightarif2 = (maxtarif>=9999 & maxtarif<.)
*li u period network prepost tarif_cost if hightarif1==1
replace tarif_cost = tarif_cost / 100 if tarif>200 & tarif< 9999

* Fix extreme tariffs 
replace tarif_cost = 31 if u==813452000 & period==201205 // € 10 million tariff
replace tarif_cost = m_spend if u==843485300 & period==201212 // € 9999.99 tariff
replace tarif_cost = . if u==941821900 & tarif_cost==14099
replace tarif_cost = . if u==952186700
replace tarif_cost = . if u==947182200 & tarif_cost==120
replace bill       = . if u==947182200 & tarif_cost==120
replace m_spend = m_spend[_n-1] if u==813452000 & period==201205

drop maxtarif hightarif*

/*******************************************************
 Rule-based cleanup
*******************************************************/
drop if u_other_id == 123456 // user id suspicious of miss report
drop if prepost == 99 // drop if prepost unanswered

egen medspend = median(m_spend) if m_spend>0, by(u_other_id)
replace m_spend = m_spend/100 if m_spend/medspend>90 & m_spend/medspend<110

* Reapply numericBill construction
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

gen badscale1 = (contractspend/m_spend>90 & contractspend/m_spend<110)
replace contractspend = contractspend/10 if badscale1==1
replace m_spend = m_spend*10 if badscale==1

gen rt = m_spend/tarif_cost
replace m_spend = m_spend/100 if rt>90 & rt<110
replace rt = m_spend/tarif_cost
replace m_spend = . if rt>99 & rt<. & tarif_cost1>9.9
replace rt = m_spend/tarif_cost
replace tarif_cost = . if rt>9 & rt<11 & tarif_cost1<10
replace rt = m_spend/tarif_cost
gen rt2 = numericBill/tarif_cost

replace m_spend = . if rt>9 & rt<. & rt2<2 & rt2>0.5 & tarif_cost>9.99
replace rt = m_spend/tarif_cost
replace m_spend = . if rt>9 & rt<. 
replace m_spend = . if m_spend>300 & m_spend<.
replace m_spend = . if m_spend>200 & tarif_cost>0 & tarif_cost<.
replace m_spend = . if m_spend>200 & bill>0 & bill<13

replace rt = contractspend/tarif_cost
replace contractspend = . if rt>9 & rt<. & tarif_cost>9.99
replace contractspend = . if rt>9 & rt<. & tarif_cost<=9.99 & contractspend>100 & contractspend/m_spend>10

/*******************************************************
 Clean up network & prepost
*******************************************************/
replace prepost = 1 if network==23 & period<201210 // Only prepaid for Leclerc before Oct 2012
replace prepost = 2 if network==23 & period>=201210 & prepost==3 // No bloque for Leclerc
replace prepost = 2 if network==23 & period>=201210 & prepost==99 & topup==. & bill~=.

replace prepost = 2 if network==30  // Only postpaid for Numericable
replace prepost = 3 if network==45  // Only forfait bloqué for Universal mobile
replace prepost = 1 if network==97  // Only prepaid for Simyo
replace prepost = 2 if network==771 // Only forfait for Free
replace prepost = 2 if network==772 // Only forfait for Sosh
replace prepost = 2 if network==774 // Only forfait for Red

replace prepost = 2 if package_data==2 & prepost==1
replace prepost = 2 if package_call==2 & prepost==1

gen merger2 = 1 if network==773 & prepost==1 & period>=201309 // B&You prepaid to Bouyges

replace network = 771 if u==810637900 & period==201210 // This is Free subscriber
replace network =   7 if merger2==1
drop if network==771 & period<201201

replace prepost = 2 if network==773 & prepost==1  // No prepaid for B&You
replace prepost = 2 if network==773 & prepost==3  // No bloque for B&You

replace con_dur = 9 if con_dur==.
replace con_dur = 0 if prepost==1 | con_dur==6

* Adjust hostNetwork1-4 according to the change in network
replace hostNetwork1 = 1 if network==5
replace hostNetwork3 = 1 if network==7
replace hostNetwork1 = 1 if network==8
replace hostNetwork1 = 1 if network==12
replace hostNetwork2 = 1 if network==14
replace hostNetwork2 = 1 if network==15
replace hostNetwork2 = 1 if network==16 // Old name of La poste mobile
replace hostNetwork1 = 1 if network==19
replace hostNetwork2 = 1 if network==23
replace hostNetwork1 = 1 if network==24
replace hostNetwork2 = 1 if network==26 // Buzzmobile 
replace hostNetwork2 = 1 if network==27
replace hostNetwork1 = 1 if network==28
replace hostNetwork1 = 1 if network==29 & prepost==1 // NRJ: Orange for prepaid
replace hostNetwork2 = 1 if network==29 & prepost>1 //  NRJ: SFR for postpaid (full MVNO from Sep 2011)
replace hostNetwork3 = 1 if network==30
replace hostNetwork1 = 1 if network==32
replace hostNetwork1 = 1 if network==33
replace hostNetwork2 = 1 if network==36
replace hostNetwork1 = 1 if network==41
replace hostNetwork3 = 1 if network==45
// full MVNO w/ SFR 2011/6, w/ Orange 2012/4 (2G/3G), 4G w/ SFR & Bouygues 2014/04
replace hostNetwork3 = 1 if network==47
replace hostNetwork2 = 1 if network==47
replace hostNetwork1 = 1 if network==47
replace hostNetwork2 = 1 if network==59 // post==la post?
replace hostNetwork3 = 1 if network==97
replace hostNetwork3 = 1 if network==134
replace hostNetwork3 = 1 if network==673 // Lyca: full MVNO
replace hostNetwork2 = 1 if network==718
replace hostNetwork2 = 1 if network==727
replace hostNetwork2 = 1 if network==728
replace hostNetwork1 = 1 if network==736
replace hostNetwork2 = 1 if network==769
replace hostNetwork4 = 1 if network==771
replace hostNetwork1 = 1 if network==772
replace hostNetwork3 = 1 if network==773
replace hostNetwork2 = 1 if network==774
replace hostNetwork1 = 1 if network==779 & prepost==1 // Crédit Mutuel Mobile
replace hostNetwork2 = 1 if network==779 & prepost>1  // Crédit Mutuel Mobile

/*******************************************************
 Exchange bill & topup when they don't match prepost (due to miss report or cleaning of prepost)
*******************************************************/
gen bundle = (bill==14)
replace bill = . if bill==0 | bill==13 | bill==999 
replace topup = . if topup==0 | topup==13 | topup==999

replace topup = bill if prepost==1 & topup==. & bill~=. & bundle==0
replace bill = topup if prepost~=1 & topup~=. & bill==.

/*******************************************************
 Classify networks by host antenna networks
*******************************************************/
gen int vendorNetwork = .
replace vendorNetwork =  1 if network==32
replace vendorNetwork =  2 if network==36
replace vendorNetwork =  3 if network==7
replace vendorNetwork =  4 if network==771
replace vendorNetwork =  5 if network==772
replace vendorNetwork =  6 if network==773
replace vendorNetwork =  7 if network==774
replace vendorNetwork = 11 if hostNetwork1==1 & vendorNetwork==.
replace vendorNetwork = 12 if hostNetwork2==1 & vendorNetwork==.
replace vendorNetwork = 13 if hostNetwork3==1 & vendorNetwork==.
replace vendorNetwork = 99 if network==47
replace vendorNetwork =  0 if network==.

label define vendorNetworkLabel  0 "NA"
label define vendorNetworkLabel  1 "Orange", add
label define vendorNetworkLabel  2 "SFR", add
label define vendorNetworkLabel  3 "Bouygues", add
label define vendorNetworkLabel  4 "Free", add
label define vendorNetworkLabel  5 "Sosh", add
label define vendorNetworkLabel  6 "B&You", add
label define vendorNetworkLabel  7 "Red", add
label define vendorNetworkLabel 11 "MVNO:Orange", add
label define vendorNetworkLabel 12 "MVNO:SFR", add
label define vendorNetworkLabel 13 "MVNO:Bouygues", add
label define vendorNetworkLabel 99 "Virgin", add
label values vendorNetwork vendorNetworkLabel

/*******************************************************
 Set up price for postpaid
*******************************************************/
gen forfait = ((prepost==2 | prepost==3) & vendorNetwork~=0)

// Impute missing price from contract spending
gen c_spend = contractspend if forfait==1
replace c_spend = m_spend if contractspend==. & forfait==1

// Numericable bundles excluded
gen price = c_spend if forfait==1 & c_spend>0 & ~(vendorNetwork==13 & prepost==2 & bundle==1) 

// Impute missing prices by average spending within panels
egen avgSpendPostWithnPanel = mean(c_spend) if forfait==1, by(u vendorNetwork prepost bill)
replace price = avgSpendPostWithnPanel if price==. & forfait==1 & avgSpendPostWithnPanel>0 & ~(vendorNetwork==13 & prepost==2 & bundle==1) 

// Tariff of postpaid & forfait bloqué plans
gen gotTarifPost = (tarif_cost>0 & tarif_cost~=.) if forfait==1
replace gotTarifPost = 1 if tarif_cost==0 & vendorNetwork==4 & bundle==1 // Allow for Free's zero bundle pricing
gen postTarif = tarif_cost if gotTarifPost==1
egen avgTarifPostWithnPanel = mean(postTarif) if forfait==1, by(u vendorNetwork prepost bill)
egen avgTarifPostBetwnPanel = mean(postTarif) if forfait==1, by(vendorNetwork prepost bill period)
egen gotPartialTarif = max(gotTarifPost) if forfait==1, by (u vendorNetwork prepost bill)
replace postTarif = avgTarifPostWithnPanel if gotTarifPost==0 & gotPartialTarif==1 & bill~=. // Partially available 
replace postTarif = avgTarifPostBetwnPanel if gotTarifPost==0 & gotPartialTarif==0 & bill~=. // Totally unavailable 

// Price = (postTarif or numericBill) + numericTopup
replace price = postTarif +  numericTopup if forfait==1 & price==.
replace price = numericBill + numericTopup if forfait==1 & price==.

// Use tarif_cost in case of recent handset purchase
replace price = postTarif + numericTopup if gotTarifPost==1 & monthvar-amonthvar<=3 & c_spend>100 & c_spend<. 

// Replace contractspend with m_spend if m_spend is closer to bill
gen overCspend = contractspend - (postTarif+numericTopup) if forfait==1
replace overCspend = contractspend - (numericBill+numericTopup) if forfait==1 & overCspend==.
replace overCspend = -1e12 if overCspend==.
gen overMspend = m_spend - (postTarif+numericTopup) if forfait==1
replace overMspend = m_spend - (numericBill+numericTopup) if forfait==1 & overMspend==.
replace overMspend = -1e12 if overMspend==.
replace c_spend = contractspend if overCspend>=0 & overMspend<0 & forfait==1
replace c_spend = contractspend if min(overCspend,overMspend)>=0 & overCspend<=overMspend & forfait==1
replace c_spend = m_spend if overCspend<0 & overMspend>=0 & forfait==1
replace c_spend = m_spend if min(overCspend,overMspend)>=0 & overCspend>overMspend & forfait==1
count if overCspend<0 & overMspend>0 & forfait==1
drop over* got*

/*******************************************************
 Set up price for prepaid
*******************************************************/
replace price = numericTopup if prepost==1
replace price = numericBill  if prepost==1 & price==.
replace price = tarif_cost   if prepost==1 & price==. & tarif_cost>0

// Impute missing prepaid price by non-zero spending
egen meanSpendPre = mean(m_spend) if prepost==1 & m_spend>0, by (u vendorNetwork prepost topup)
replace price = meanSpendPre if prepost==1 & price==.

/*******************************************************
 Check obs with missing prices
*******************************************************/
gen reportPrice = (price~=.)
egen reportPriceID = min(reportPrice), by (u vendorNetwork prepost)
*li u period vendor prepost1 tarif_c meanSpendPre m_s bill top price reportPrice if reportPriceID==0 & vendorN==4

/*******************************************************
 Impute missing price by average network price
*******************************************************/
bysort u_other_id vendorNetwork prepost: egen priceImpute = mean(price) // could use Kernel density estimate
tab vendorNetwork if price==. & priceImpute~=. & prepost>1 
replace price = priceImpute if price==. & priceImpute~=. & priceImpute>0
label variable price "tarif_cost1>spend>(bill,topup)"
replace price=. if price==0 & forfait==1 & vendorNetwork~=4

/*******************************************************
 Let price = tariff_cost for postpaids !!!!!!!!!!
*******************************************************/
replace price = tarif_cost if forfait==1 & tarif_cost>0 & tarif_cost<.

/*******************************************************
 Clean package variables
*******************************************************/
gen allowCall = .
replace allowCall =   50 if package_call==10
replace allowCall =  100 if package_call==11
replace allowCall =  200 if package_call==12
replace allowCall =  500 if package_call==13
replace allowCall =  700 if package_call==14
replace allowCall = 1000 if package_call==15
replace allowCall = 1500 if package_call==16
replace allowCall = 2000 if package_call==17
replace allowCall = 4000 if package_call==2
replace allowCall =    0 if prepost==1
replace allowCall = allowCall/1e3

gen allowData = . 
replace allowData =    0 if package_data==. & (planType==1|planType==3|planType==5) 
replace allowData =   50 if package_data==10
replace allowData =  100 if package_data==11
replace allowData =  200 if package_data==12
replace allowData =  300 if package_data==13
replace allowData =  500 if package_data==14
replace allowData = 1000 if package_data==15
replace allowData = 2000 if package_data==16
replace allowData = 3000 if package_data==17
replace allowData = 5000 if package_data==2
replace allowData =    0 if package_data==1
replace allowData =    0 if prepost==1
replace allowData = allowData/1e3

gen allowText = . 
replace allowText =   50 if package_text==10
replace allowText =  100 if package_text==11
replace allowText =  200 if package_text==12
replace allowText =  300 if package_text==13
replace allowText =  500 if package_text==14
replace allowText =  700 if package_text==15
replace allowText = 1000 if package_text==16
replace allowText = 1500 if package_text==17
replace allowText = 3000 if package_text==18
replace allowText = 4500 if package_text==19
replace allowText = 6000 if package_text==2
replace allowText =    0 if prepost==1
replace allowText = allowText/1e3

* Impute missing allowanceCall for network==10
xtset u_other_id monthvar
replace allowCall = F.allowCall if allowCall==. & monthvar==623 & F.allowCall~=.

/*******************************************************
 Clean up temporary variables
*******************************************************/
drop meanSpend* report* priceImpute avg* post*

/*******************************************************
 Drop consumers who never subscribe to any tariff
*******************************************************/
gen nomobile = (vendorNetwork==0)
egen nomobileMax = max(nomobile), by(u_other_id)
egen nomobileMin = min(nomobile), by(u_other_id)
drop if nomobileMin==1
replace mobile = 1 if vendorNetwork~=0
drop nomobile*

/*******************************************************
 Construct average of product characteristics
*******************************************************/
gen missing = (month>=623 & month<=647 & prepost>1 & prepost<.)

replace allowCall=0 if allowCall==. & missing==1
replace allowData=0 if allowData==. & missing==1
replace allowText=0 if allowText==. & missing==1

gen missing2 = (month>647 & prepost>1 & prepost<.)

egen tier = group(prepost), label
replace tier = 1 if vendorNetwork==4 & price<14 // Free user below-€10 bill classified to low tier

bysort vendorNetwork prepost quarter: egen meanAllowCall = mean(allowCall)
bysort vendorNetwork prepost quarter: egen meanAllowData = mean(allowData)
bysort vendorNetwork prepost quarter: egen meanAllowText = mean(allowText)
bysort vendorNetwork prepost tier quarter: egen meanPrice = mean(price)

rename prepost1 prepost
bysort period vendorNetwork prepost: gen int groupSizeObs = _N
drop if groupSizeObs <= 1

/*******************************************************
 Bundle products for long fixed-term contracts
*******************************************************/
replace bundle = bundle * (prepost==2 | prepost==3)

/*******************************************************
 Data export
*******************************************************/
drop merger* hostNetwork*  missing
drop if vendorNetwork==. | region==.
compress
save dataProcessed802, replace
