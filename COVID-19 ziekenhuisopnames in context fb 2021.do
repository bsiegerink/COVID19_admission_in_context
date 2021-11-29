
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
 [] assen aan figuur toevoegen
	[ ] assen aanpassen voor leesbaarheid
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
_________________________________________________________________________________*/

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

/* data import 
#2 LCPS data
--------------------------------------------------------------------------------
data van LCPS voor ziekenhuisbesmettingen
bron https://lcps.nu/wp-content/uploads/covid-19-datafeed.csv, datum 11/11/2021

beschrijving variabelen
Datum: Datum waarop de beddenbezetting is vastgesteld (geschreven in de volgende datumnotatie: 01-01-2020);
		IC_Bedden_COVID: Het aantal IC-bedden bezet door patiënten met COVID-19;
		IC_Bedden_Non_COVID: Het aantal IC-bedden bezet door patiënten zonder COVID-19;
		IC_Nieuwe opnames_COVID: Het aantal patiënten met COVID-19 dat in 24 uur nieuw is opgenomen op de IC;
		Kliniek_Bedden: Het aantal kliniekbedden bezet door patiënten met COVID-19.
		Kliniek_Nieuwe opnames_COVID: Het aantal patiënten met COVID-19 dat in 24 uur nieuw is opgenomen in de kliniek;
*/

clear all
import delimited "C:\Users\bsiegerink\OneDrive - LUMC\huisarts en wetenschap COVID-19\COVID19_admission_in_context\covid-19 lcps.csv", varnames(1) clear 

gen date = date(datum, "DMY")
format date %tdDDmon
sort date 
destring(ic_bedden_covid ic_bedden_non_covid kliniek_bedden ic_nieuwe_opnames_covid kliniek_nieuwe_opnames_covid), force replace

merge 1:1 date using 1
drop _merge

*totaalbezetting met COVID bedden. uiteindelijk gebruiken we deze variabele niet, omdat we overstappen op LCPS data
gen bezettingcovid =  ic_bedden_covid + kliniek_bedden

* proporties berekenen + 95CI 
gen proportion= (zhopname / besmettingen)
gen ul_prop = (prop + (1.96*(sqrt((prop*(1-prop))/besmettingen))))
gen ll_prop = (prop - (1.96*(sqrt((prop*(1-prop))/besmettingen))))

*omzetten naar percentage.
generate perc = prop*100
generate ul_perc = ul_prop*100
generate ll_perc = ll_prop*100

save 2, replace 

/* data import 
#3 NICE data incoming
--------------------------------------------------------------------------------
 data van NICE voor instrom in ziekenhuis
Bron is data feed van Marino, die een dagelijk snapshot maakt. 
inkomend is alles wat bevestigd en suspected is, zowel op IC als op de gewone afdeling
*/

import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/nice-today.csv", clear
gen incoming =  hospital_intake_proven + hospital_intake_suspected + ic_intake_proven + ic_intake_suspected
gen total_beds_currently = hospital_currently +ic_current
keep date incoming hospital_currently ic_current total_beds_currently
save incoming, replace

*drop latest obs due to incomplete reporting
drop if _n > _N-4 

* rename variables
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 

merge 1:1 date using 2
drop _merge

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
import delimited "https://raw.githubusercontent.com/mzelst/covid-19/master/data-nice/exit/Clinical_Beds/nice_daily_exit_clinical_2021-11-27.csv", clear
gen outgoing = 	 overleden_pdag + ontslagen_pdag
keep date outgoing 
save outgoing, replace

*drop latest obs due to incomplete reporting
drop if _n > _N-4 

* rename variables
rename date datum
gen date = date(datum, "YMD")
format date %tdDDmon
gen week_d=dow(date) 

merge 1:1 date using 3
drop _merge

* generate ligduur

gen daily_incidence = outgoing / ( total_beds_currently[_n-1] - 0.5*outgoing + 0.5*incoming)

gen average_hosp_stay_perday = 1/daily_incidence
sum average_hosp_stay_perday


twoway scatter average_hosp_stay_perday date if  (date > mdy(01, 01, 2021) )

gen running_average_hosp_stay_perday= (average_hosp_stay_perday[_n-1] ///
+average_hosp_stay_perday[_n-2] +average_hosp_stay_perday[_n-3] ///
 +average_hosp_stay_perday[_n-4] +average_hosp_stay_perday[_n-5] ///
 +average_hosp_stay_perday[_n-6] +average_hosp_stay_perday[_n-7]) / 7

save 4, replace 





*_______________________________________________________________________________
* figuur
*_______________________________________________________________________________
drop if date < mdy(08, 25, 2020)
twoway	(line besmettingen date, yaxis(2) lcol(red*1.3) lw(*1.5) lpat(solid)) ///
		(line  bezettingcovid date , yaxis(3) lcol(green*1.3) lw(*1.5) lpat(--)) ///
	    (scatter perc date, yaxis(1) mcol(blue*1.3) msymbol(0)) ///
		(rcap ul_perc ll_perc date, yaxis(1) lcol(blue*1.3)) /// 
		(scatter running_average_hosp_stay_perday date, yaxis(4) msymbol(+) mcol(gold)) ///
			, ///
		ylabel(0(1)6, axis(1)) yscale(range(0 1 to 6) axis(1)) ///
		ylabel(0(4)40, axis(4)) yscale(range(0 5 to 40) axis(4)) ///
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
		
	
	
	
	
	