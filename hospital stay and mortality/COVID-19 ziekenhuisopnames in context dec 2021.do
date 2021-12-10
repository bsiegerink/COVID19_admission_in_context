
/* COVID-19 ziekenhuisopnames in context dd 18 / 10 /2021
Mook, Siegerink et al
code written by b.siegerink@lumc.nl

see 

description: this code is a follow up on the code in which we focussed on hospital intake and admission rates.
in this format, we put our focus on legth of stay and hospital mortality.

reason behind this is that the admission rate became unusable because the covid positive case mis become wildly different 
ith large proportion of schoolchildren. 

The following code relies fully on Github repo's  from M van Zelst. The rest of the commentary is in Dutch, please contact me if you need more information.
*/

clear all

cd "C:\Users\bsiegerink\OneDrive - LUMC\huisarts en wetenschap COVID-19\COVID19_admission_in_context\"
set more off, perm
set scheme plotplain, perm
set seed 1988

/* data import 
#3 NICE data incoming
--------------------------------------------------------------------------------
 data van NICE voor instroom in ziekenhuis
Bron is data feed van Marino, die een dagelijk snapshot maakt. 
inkomend is alles wat bevestigd en suspected is, zowel op IC als op de gewone afdeling
*/

import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/nice-today.csv", clear
gen incoming =  hospital_intake_proven + hospital_intake_suspected + ic_intake_proven + ic_intake_suspected
gen running_average_incoming=  ///
(incoming + ///
incoming[_n-1] + ///
incoming[_n-2] + ///
incoming[_n-3] + ///
incoming[_n-4] + ///
incoming[_n-5] + ///
incoming[_n-6])/7  


gen total_beds_currently = hospital_currently +ic_current
gen running_average_total_beds=  ///
(total_beds_currently + ///
total_beds_currently[_n-1] + ///
total_beds_currently[_n-2] + ///
total_beds_currently[_n-3] + ///
total_beds_currently[_n-4] + ///
total_beds_currently[_n-5] + ///
total_beds_currently[_n-6])/7

* rename variables
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 

save 3, replace 

/* data import 
#4 NICE data outgoing
-------------------------------------------------------------------------------
data van NICE voor uitstroom in ziekenhuis
Bron is data feed van Marino, die een dagelijk snapshot maakt. 
uitgaand is alles wat wat sterft of ontslagen is
probleem met deze data is dat ontslagen van IC, ook ontslagen naar afdeling kan zijn
*/

*get the outgoing
import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/exit/Clinical_Beds/nice_daily_exit_clinical_2021-12-10.csv", clear
gen outgoing = 	 overleden_pdag + ontslagen_pdag

* name and rename date variables
gen day = _n
gen week = int((_n-1)/7) +1 
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 

merge 1:1 date using 3
drop _merge

* generate daily incidence of death
gen death_perc = (overleden_pdag / ( total_beds_currently[_n-1]))*100

*generate running average
gen running_average_death_perc=  ///
(death_perc+ ///
death_perc[_n-1] + ///
death_perc[_n-2] + ///
death_perc[_n-3] + ///
death_perc[_n-4] + ///
death_perc[_n-5] + ///
death_perc[_n-6])/7  


/*explore the variable ;  almost one day a week less 
sum death_perc 
hist running_average_death_perc if running_average_death_perc <15
scatter death_perc running_average_death_perc
*/

* generate daily incidence of discharge
gen daily_incidence = outgoing / ( total_beds_currently[_n-1] - (0.5*outgoing) + (0.5*incoming))

*generate running average
gen running_average_daily_incidence=  ///
(daily_incidence + ///
daily_incidence[_n-1] + ///
daily_incidence[_n-2] + ///
daily_incidence[_n-3] + ///
daily_incidence[_n-4] + ///
daily_incidence[_n-5] + ///
daily_incidence[_n-6])/7  ///

*make into hospital stay duration
gen average_hosp_stay_perday = 1/running_average_daily_incidence

/*explore the variable 
sum average_hosp_stay_perday
hist average_hosp_stay_perday if average_hosp_stay_perday <15
*/

// make variable for casemix
gen casemix =  (ic_current /  (hospital_currently+ic_current))*100
gen running_average_casemix=  ///
(casemix+ ///
casemix[_n-1] + ///
casemix[_n-2] + ///
casemix[_n-3] + ///
casemix[_n-4] + ///
casemix[_n-5] + ///
casemix[_n-6])/7  
*twoway scatter percent_casemix  date

save 4, replace 


*_______________________________________________________________________________
* nieuw figuur
*_______________________________________________________________________________
drop if _n>_N-4
twoway	(line  running_average_incoming 	date , yaxis(1) lcol(red*1.3)   lw(*1.5) lpat(solid)) ///
		(line  running_average_total_beds   date , yaxis(2) lcol(green*1.3) lw(*1.5) lpat(solid)) ///
	  	(line  running_average_casemix  	date , yaxis(3) lcol(black*0.7) lw(*1.5) lpat(solid)) ///
		, ///
		yscale(axis(1)) ///
		ylabel(0(150)600, axis(1) angle(90)) ///
		ytitle("nieuwe COVID-19 bedden", axis(1) color(red*1.3) size(small)) ///
		yscale(axis(2)) ///
		ylabel(#5, axis(2) angle(90)) ///
		ytitle("totaal bezette COVID-19 bedden", axis(2) color(green*1.3) size(small)) ///
		yscale(axis(3) alt) ///
		ylabel(0(15)60, axis(3) angle(90)) ///
		ytitle("casemix, % ICU bedden van totaal", axis(3) color(black*1.3) size(small)) ///
		legend(off) ///
		xsize(9) ///
		xtitle("") ///
		xlabel(#10) ///
		title("{bf:A: instroom en totale bezetting}", justification(left) span bexpand nobox margin( 3 3 3 3)) ///
		name(A, replace)
		
twoway 	(line average_hosp_stay_perday  	date if date> mdy(04, 01, 2020) , yaxis(1) lcol(gold)      lw(*1.5) lpat(solid)) ///
		(line running_average_death_perc	date , yaxis(2) lcol(blue*1.3)  lw(*1.5) lpat(solid)) ///
		(line running_average_casemix  		date , yaxis(3) lcol(black*0.7) lw(*1.5) lpat(solid)) ///
		, ///
		yscale(axis(1)) ///
		ylabel(5(5)25, axis(1) angle(90)) ///
		ytitle("gemiddelde ligduur (in dagen)", axis(1) color(gold*1) size(small)  ) ///
		yscale(axis(2)) ///
		ylabel(0(0.5)2.5, axis(2) angle(90)) ///
		ytitle("dagelijkse ziekenhuismortaliteit, %", axis(2) color(blue*1.3) size(small)) /// 
		yscale(axis(3) alt) ///		
		ylabel(0(15)60, axis(3) angle(90)) ///
		ytitle("casemix, % ICU bedden van totaal", axis(3) color(black*1.3) size(small)) ///
		legend(off) ///
		xsize(9) ///	
		xlabel(#10) ///
		xtitle("") ///
		title("{bf:B: ligduur en ziekenhuismortaliteit}", justification(left) span bexpand nobox margin(3 3 3 3)) ///
		name(B, replace)

		
graph combine A B, xcommon row(2) ysize(7) xsize(9) ///
title("COVID-19 instroom, ligduur en mortaliteit in het ziekenhuis") ///
caption("data van NICE, dagelijkse cijfers, 7 daags gemiddelde, zie https://osf.io/5vjgn/ voor meer details, data en code" , size(tiny)) 

graph export "COVID-19, fase 2D korte ligduur en hoge mortaliteit.pdf"

















