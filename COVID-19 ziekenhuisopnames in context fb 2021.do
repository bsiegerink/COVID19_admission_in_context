



** COVID-19 ziekenhuisopnames in context dd 18 / 10 /2021
* Mook, Rosendaal, Siegerink
* written by b.siegerink@lumc.nl
*_______________________________________________________________________________
*prep stata
set more off, perm
set scheme plotplain, perm
set seed 1988
*_______________________________________________________________________________

clear all 

/*** data covid besmettingen importeren - 
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

* NB date is de start van de week!
*/
clear
import excel "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID19_admission_in_context\COVID-19 RIVM.xlsx", sheet("Sheet1") firstrow
rename *, lower

format week %tdDDmon
rename week date

save "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID19_admission_in_context\rivm epidemiologisch rapport.dta", replace 

/** data van LCPS voor ziekenhuisbesmettingen
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
import delimited "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID19_admission_in_context\covid-19 lcps.csv", varnames(1) clear 

gen date = date(datum, "DMY")
format date %tdDDmon
drop if date < mdy(08, 25, 2020)
drop if date > mdy(18, 01, 2021)
sort date 

destring(ic_bedden_covid ic_bedden_non_covid kliniek_bedden ic_nieuwe_opnames_covid kliniek_nieuwe_opnames_covid), force replace


merge 1:1 date using "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID19_admission_in_context\rivm epidemiologisch rapport.dta"


*totaalbezetting met COVID bedden.
gen bezettingcovid =  ic_bedden_covid + kliniek_bedden

* proporties berekenen + 95CI 
gen proportion= (zhopname / besmettingen)
gen ul_prop = (prop + (1.96*(sqrt((prop*(1-prop))/besmettingen))))
gen ll_prop = (prop - (1.96*(sqrt((prop*(1-prop))/besmettingen))))

*omzetten naar percentage.
generate perc = prop*100
generate ul_perc = ul_prop*100
generate ll_perc = ll_prop*100




*________________________________________
*** GRAFIEK
*________________________________________

twoway  (scatter perc date, yaxis(1) mcol(navy*2) msymbol(0)) ///
		(rcap ul_perc ll_perc date, yaxis(1) lcol(navy*1.5)) /// 
		(line besmettingen date, yaxis(2) lcol(red*2) lw(*1.5) lpat(solid)) ///
		(line  bezetting date , yaxis(3) lcol(green*2) lw(*1.5) lpat(--)) ///
			, ///
		ylabel(0(1)8) yscale(range(0 1 to 8)) ///
		xtitle("datum") ///
		legend(off) ///
		yscale(axis(1)) ///
		yscale(axis(2) alt) ///
		yscale(axis(3) alt) ///
		ytitle(" opname/besmettingen per week in percentage (●)", axis(1) color(navy*1.5) size(small)) ///
		ytitle("besmettingen per week (—)", axis(2) color(red*2) size(small)) ///
		ytitle("bezette bedden per dag (- -)", axis(3) color(green*2) size(small)) ///
		title("COVID-19 ziekenhuisopnames in context:") ///
		subtitle("totaal besmettingen en bijbehorende percentage opnames per week" "in relatie tot de dagelijkse beddenbezetting", size(small)) ///
		caption("zie ook https://osf.io/5vjgn/ voor meer informatie over de brondata en bewerking", size(tiny))
		
		graph export "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID-19 ziekenhuisopnames in context.pdf", replace
		
		export delimited "C:\Users\bsiegerink\Desktop\huisarts en wetenschap COVID-19\COVID-19 ziekenhuisopnames in context feb 2021 analyse file.csv", replace
		
