
/* COVID-19 ziekenhuisopnames in context dd 18 / 10 /2021
Mook, Rosendaal, Siegerink
written by b.siegerink@lumc.nl

Deze file heeft de volgende onderdelen:
 
// data import and prep:
		we importeren data van verschillende bronnen:
		1 RIVM report voor wekelijkse GGD getallen
		2 lcps file voor dagelijkse bezetting in de ziekenhuizen
		3 instroom ziekenhuis/IC volgens NICE
		4 uitstroom ziekenhuis/IC volgens NICE
// merge files
// make graph
_______________________________________________________________________________
to do: 
[x] assen aan figuur toevoegen
	[x] assen aanpassen voor leesbaarheid
	[x] x as meer labels
	[x] y as optrekken naar top vor hele pandemie
	
[ ] opruimen van code
	[x] volgorde
	[x] bronverwijzing
[x ] alles in 1 run 
[x] brondata duidelijk labelen
[ ] originele grafiek herconstryeren met databronnen van marino 
	[x] kijk ook he de bron data van ricm en marino overeenkomen 
[]  maak grafiek alleen voor afgelopen drie maanden
	[]  split voor IC en zaal
________________________________________________________________________________*/

clear all

cd "C:\Users\bsiegerink\OneDrive - LUMC\huisarts en wetenschap COVID-19\COVID19_admission_in_context\"
set more off, perm
set scheme plotplain, perm
set seed 1988

/* data import 
#1 RIVM report:
--------------------------------------------------------------------------------
bron via RIVM reports, Epidemiologische situatie COVID-19 in Nederland  (https://www.rivm.nl/sites/default/files/2021-02/COVID-19_WebSite_rapport_wekelijks_20210202_1259_final.pdf tabel 2 & 10  
en 
https://www.rivm.nl/sites/default/files/2021-03/COVID-19_WebSite_rapport_wekelijks_20210316_1159.pdf
te vinden op 
https://www.rivm.nl/coronavirus-covid-19/actueel/wekelijkse-update-epidemiologische-situatie-covid-19-in-nederland
de meest recente data zijn zo veel gebruikt.

beschrijving variabelen:
week - datum van eerste dag van de genoemde week
zhopnamen  - ziekenhuisopnames per week
besmettingen  - aantal besmettingen per week
percentageziekenhuisopnameper - let op, dit percentage is in gebruikt voor een initiele tweet van co-auteur DOMK. het betreft hier het percentage ziekenhuisopnames over het gemiddelde van de huidige en voorgaande week. Deze aanpak is verlaten nalv de discussie die volgende, maar voor de volledigheid wel aanweizg in de dataset.

* NB date is de start van de week! */

import excel "C:\Users\bsiegerink\OneDrive - LUMC\huisarts en wetenschap COVID-19\COVID19_admission_in_context\COVID-19 RIVM.xlsx", sheet("Sheet1") firstrow
rename *, lower

format week %tdDDmon
rename week date

save 1, replace 

// /* data import 
// #2 LCPS data
// --------------------------------------------------------------------------------
// data van LCPS voor ziekenhuisbesmettingen
// bron https://lcps.nu/wp-content/uploads/covid-19-datafeed.csv, datum 11/11/2021
//
// beschrijving variabelen
// Datum: Datum waarop de beddenbezetting is vastgesteld (geschreven in de volgende datumnotatie: 01-01-2020);
// 		IC_Bedden_COVID: Het aantal IC-bedden bezet door patiënten met COVID-19;
// 		IC_Bedden_Non_COVID: Het aantal IC-bedden bezet door patiënten zonder COVID-19;
// 		IC_Nieuwe opnames_COVID: Het aantal patiënten met COVID-19 dat in 24 uur nieuw is opgenomen op de IC;
// 		Kliniek_Bedden: Het aantal kliniekbedden bezet door patiënten met COVID-19.
// 		Kliniek_Nieuwe opnames_COVID: Het aantal patiënten met COVID-19 dat in 24 uur nieuw is opgenomen in de kliniek;
// */
//
// clear all
// import delimited "C:\Users\bsiegerink\OneDrive - LUMC\huisarts en wetenschap COVID-19\COVID19_admission_in_context\covid-19 lcps.csv", varnames(1) clear 
//
// gen date = date(datum, "DMY")
// format date %tdDDmon
// sort date 
// destring(ic_bedden_covid ic_bedden_non_covid kliniek_bedden ic_nieuwe_opnames_covid kliniek_nieuwe_opnames_covid), force replace
//
// merge 1:1 date using 1
// drop _merge
//
// *totaalbezetting met COVID bedden. uiteindelijk gebruiken we deze variabele niet, omdat we overstappen op LCPS data
// gen bezettingcovid =  ic_bedden_covid + kliniek_bedden
//
// * proporties berekenen + 95CI 
// gen proportion= (zhopname / besmettingen)
// gen ul_prop = (prop + (1.96*(sqrt((prop*(1-prop))/besmettingen))))
// gen ll_prop = (prop - (1.96*(sqrt((prop*(1-prop))/besmettingen))))
//
// *omzetten naar percentage.
// generate perc = prop*100
// generate ul_perc = ul_prop*100
// generate ll_perc = ll_prop*100
//
// save 2, replace 

/* data import 
#3 NICE data incoming
--------------------------------------------------------------------------------
 data van NICE voor instroom in ziekenhuis
Bron is data feed van Marino, die een dagelijk snapshot maakt. 
inkomend is alles wat bevestigd en suspected is, zowel op IC als op de gewone afdeling
*/

import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/nice-today.csv", clear
gen incoming =  hospital_intake_proven + hospital_intake_suspected + ic_intake_proven + ic_intake_suspected
gen total_beds_currently = hospital_currently +ic_current

save incoming, replace


* rename variables
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 
//
// merge 1:1 date using 2
// drop _merge

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
import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/exit/Clinical_Beds/nice_daily_exit_clinical_2021-12-06.csv", clear
gen outgoing = 	 overleden_pdag + ontslagen_pdag
save outgoing, replace

gen day = _n
gen week = int((_n-1)/7) +1 

* rename variables
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 

merge 1:1 date using 3
drop _merge


* generate daily incidence of death
gen death_perc = overleden_pdag / ( total_beds_currently[_n-1])

*generate running average
gen running_average_death_perc=  ///
(death_perc+ ///
death_perc[_n-1] + ///
death_perc[_n-2] + ///
death_perc[_n-3] + ///
death_perc[_n-4] + ///
death_perc[_n-5] + ///
death_perc[_n-6])/7  


*explore the variable ;  almost one day a week less 
sum death_perc 
hist running_average_death_perc if running_average_death_perc <15
scatter death_perc running_average_death_perc
twoway scatter running_average_death_perc date if  (date > mdy(10, 01, 2021)) 
twoway scatter running_average_death_perc date 


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

*explore the variable 
sum average_hosp_stay_perday
hist average_hosp_stay_perday if average_hosp_stay_perday <15
twoway scatter average_hosp_stay_perday date if  (date > mdy(10, 01, 2021)) , ylabel(0(1)15)
regress average_hosp_stay_perday day if(date > mdy(10, 01, 2021))
regress average_hosp_stay_perday week if(date > mdy(10, 01, 2021))


gen percent_casemix =  ic_current /  (hospital_currently+ic_current)
twoway scatter percent_casemix  date
save 4, replace 









*_______________________________________________________________________________
* nieuw figuur
*_______________________________________________________________________________
*drop if date < mdy(08, 25, 2020)
drop if _n>_N-4
twoway	(line  incoming 					date , yaxis(1) lcol(red*1.3)   lw(*1.5) lpat(solid)) ///
		(line  total_beds_currently		    date , yaxis(2) lcol(green*1.3) lw(*1.5) lpat(solid)) ///
	   	(line average_hosp_stay_perday  	date if date> mdy(04, 01, 2020) , yaxis(3) lcol(gold)      lw(*1.5) lpat(solid)) ///
		(line running_average_death_perc	date , yaxis(4) lcol(blue*1.3)  lw(*1.5) lpat(solid)) ///
		(scatter percent_casemix  date, yaxis(5)) ///
		, ///
		yscale(axis(1)) ///
		ylabel(#5, axis(1)) ///
		ytitle("total new COVID beds occupied per day (IC and non ICU)", axis(1) color(red*1.3) size(small)) ///
		yscale(axis(2)) ///
		ylabel(#5, axis(2)) ///
		ytitle("total number of beds occupied (- -)", axis(2) color(green*1.3) size(small)) ///
		yscale(axis(3) alt) ///
		ylabel(#5, axis(3)) ///
		yscale(range(0 5 to 40) axis(3)) ///
		ytitle("average hospital stay of those dicharged (+)", axis(3) color(gold) size(small)) ///
		yscale(axis(4) alt) ///
		ylabel(#5, axis(4)) ///
		ytitle("daily mortality (proportion)", axis(4) color(blue*1.3) size(small)) ///
		yscale(axis(5) alt) ///
		ylabel(#5, axis(5)) ///
		ytitle("percent ICU beds from total COVID-19 patients (+)", axis(5) color(black*1.3) size(small)) ///
		legend(off) ///
		xsize(9)		///
		xtitle("datum") ///
		xlabel(#10) ///
		title("COVID-19 patients in dutch hospitals") ///
		subtitle("total number of patients incoming, total beds occupied, percentage of occupied beds in ICU, length of stay, and mortality", size(small)) ///
		caption("work in progress" , size(tiny))
	
		






























*_______________________________________________________________________________
* oud figuur
*_______________________________________________________________________________
drop if date < mdy(08, 25, 2020)
twoway	(line besmettingen date, yaxis(2) lcol(red*1.3) lw(*1.5) lpat(solid)) ///
		(line  bezettingcovid date , yaxis(3) lcol(green*1.3) lw(*1.5) lpat(--)) ///
	    (scatter perc date, yaxis(1) mcol(blue*1.3) msymbol(0)) ///
		(rcap ul_perc ll_perc date, yaxis(1) lcol(blue*1.3)) /// 
		(scatter average_hosp_stay_perday  date, yaxis(4) msymbol(+) mcol(gold)) ///
			, ///
		ylabel(0(1)6, axis(1)) yscale(range(0 1 to 6) axis(1)) ///
		ylabel(0(4)20, axis(4)) yscale(range(0 5 to 20) axis(4)) ///
		xtitle("datum") ///
		legend(off) ///
		xlabel(#8) ///
		yscale(axis(4)) ///
		yscale(axis(1)) ///
		yscale(axis(2) alt) ///
		yscale(axis(3) alt) ///
		ytitle("opname/besmettingen per week in % (●)", axis(1) color(blue*1.3) size(small)) ///
		ytitle("gemiddelde ligduur - 7 dagen gemiddelde (+)", axis(4) color(gold) size(small)) ///
		ytitle("besmettingen per week (—)", axis(2) color(red*1.3) size(small)) ///
		ytitle("bezette bedden per dag (- -)", axis(3) color(green*1.3) size(small)) ///
		title("COVID-19 ziekenhuisopnames in context:") ///
		subtitle("totaal besmettingen, dagelijkse beddenbezetting, in relatie tot bijbehorende percentage opnames per week en gemiddelde ligduur", size(small)) ///
		caption("work in progress, zie ook https://osf.io/5vjgn/ voor eerdere versies en meer informatie over de brondata en bewerking" , size(tiny)) ///
		xsize(9)
		
	
	
	
	
	