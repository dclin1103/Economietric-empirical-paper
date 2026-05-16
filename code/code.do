clear all
set more off

cd "/Users/dachenglin/Desktop/Sp26 Econometrics HW/Empirical Paper"

capture log close
log using "empirical project.log", replace text

capture mkdir "dta"

* 1. REAL GDP
import delimited using "REAL GDP.csv", varnames(nonames) clear stringcols(_all)
drop in 1
drop if missing(v4)
rename v3 country
rename v4 code
drop v1 v2
local yr = 1960
forvalues j = 5/70 {
    
    rename v`j' y`yr'
    
    local yr = `yr' + 1
}
reshape long y, i(code) j(year)
rename y rgdppc
replace rgdppc = "" if rgdppc == ".."
destring rgdppc, replace force
keep country code year rgdppc
order country code year rgdppc
sort code year
save "dta/real_gdp.dta", replace

* 2. Trade openness
import delimited using "Tradeopenness.csv", varnames(nonames) clear stringcols(_all)
drop in 1
drop if missing(v4)
rename v3 country
rename v4 code
drop v1 v2
local yr = 1960
forvalues j = 5/70 {
    
    rename v`j' y`yr'
    
    local yr = `yr' + 1
}
reshape long y, i(code) j(year)
rename y tradeopen
replace tradeopen = "" if tradeopen == ".."
destring tradeopen, replace force
keep country code year tradeopen
order country code year tradeopen
sort code year
save "dta/tradeopenness.dta", replace

* 3. GFCF
import delimited using "GFCF.csv", varnames(nonames) clear stringcols(_all)
drop in 1
drop if missing(v4)
rename v3 country
rename v4 code
drop v1 v2
local yr = 1960
forvalues j = 5/70 {
    
    rename v`j' y`yr'
    
    local yr = `yr' + 1
}
reshape long y, i(code) j(year)
rename y gfcf
replace gfcf = "" if gfcf == ".."
destring gfcf, replace force
keep country code year gfcf
order country code year gfcf
sort code year
save "dta/gfcf.dta", replace

* 4. Democracy index
import delimited using "democracy-index-polity.csv", varnames(1) case(lower) clear
rename entity country
rename democracy democracy
destring year, replace force
destring democracy, replace force
drop if missing(code)
keep country code year democracy
order country code year democracy
sort code year
save "dta/democracy.dta", replace

* 4.1. Democracy index extend(adding 7 other countries which are missing in previous dataset)
import delimited using "democracy-index-polity extend.csv", varnames(1) case(lower) clear
rename entity country
rename democracy democracy
destring year, replace force
destring democracy, replace force
drop if missing(code)
keep country code year democracy
order country code year democracy
sort code year
save "dta/democracyextend.dta", replace

* 5. Mean years of schooling
import delimited using "mean-years-of-schooling-long-run.csv", varnames(1) case(lower) clear
rename entity country
rename averageyearsofschooling educ
destring year, replace force
destring educ, replace force
drop if missing(code)
keep country code year educ
order country code year educ
sort code year
save "dta/education.dta", replace

* 6. Merge
use "dta/real_gdp.dta", clear
merge 1:1 code year using "dta/tradeopenness.dta", keep(master match) keepusing(tradeopen)
tab _merge
drop _merge
merge 1:1 code year using "dta/gfcf.dta", keep(master match) keepusing(gfcf)
tab _merge
drop _merge
merge 1:1 code year using "dta/democracy.dta", keep(master match) keepusing(democracy)
tab _merge
drop _merge
merge 1:1 code year using "dta/education.dta", keep(master match) keepusing(educ)
tab _merge
drop _merge
merge 1:1 code year using "dta/democracyextend.dta", update
tab _merge
drop if _merge==2
drop _merge
encode code, gen(country_id)
order country country_id code year rgdppc democracy tradeopen gfcf educ
save "dta/final_merged_panel.dta", replace
/* restrict observations range from 1960 to 2015 */
keep if inrange(year, 1960, 2015)

/* drop observation which at least one main value in this research (democracy and rgdppc) is missing */
drop if missing(rgdppc)| missing(democracy)
 
/* drop Cambodia observations before 1989 because we need gdp lag in our regression and there has a break between 1978 and 1989 */
drop if code == "KHM" & year < 1989

/* drop countries with extensive missing values in the control variables */
drop if code == "SOM"
drop if code == "BDI"
drop if code == "LBR"
drop if code == "MMR"
drop if code == "MWI"
drop if code == "NGA" 

/* filling education missing value by linear interpolation */
sort code year
bysort code: ipolate educ year, gen(education)
replace educ = education if missing(educ) & !missing(education)
drop education

/* generate missing value variables */
gen tradeopen_missing = missing(tradeopen)
gen gfcf_missing = missing(gfcf)
gen educ_missing = missing(educ)
replace tradeopen = 0 if missing(tradeopen)
replace gfcf = 0 if missing(gfcf)
replace educ = 0 if missing(educ)

/* generate ln real gdp per capita and growth rate */
xtset country_id year
gen ln_gdp_pc= ln(rgdppc)
gen growthrate= D.ln_gdp_pc*100

/* gen standardized democracy index */
egen stdDem = std(democracy)


/* table of variable definitions */
label variable ln_gdp_pc "Log of real GDP per capita (constant 2015 USD)"
label variable educ "Average years of schooling from Barro-Lee dataset"
label variable tradeopen "Trade openness: (exports + imports) as % of GDP"
label variable gfcf "Gross fixed capital formation (% of GDP), proxy for investment"
label variable democracy "Democracy index ranges from -10 to 10."
label variable code "Country code"
label variable country_id "Country code"
label variable year "Year"
label variable rgdppc "Real GDP per capita (constant 2015 USD)"
label variable country "Country"
label variable stdDem "Standardized Democracy Index"
label variable growthrate "Real GDP per capita growth rate"
label variable tradeopen_missing "=1 if the origin value of tradeopen is missing"
label variable gfcf_missing "=1 if the origin value of gfcf is missing"
label variable educ_missing "=1 if the origin value of educ is missing"
order country country_id code year rgdppc ln_gdp_pc growthrate democracy stdDem gfcf gfcf_missing tradeopen tradeopen_missing educ educ_missing
asdoc describe, save(Myfile.doc) replace

/* table of summary statistics */
tabstat ln_gdp_pc growthrate stdDem gfcf gfcf_missing tradeopen tradeopen_missing educ educ_missing, ///
	stat(mean sd min max n) format(%9.3f)
asdoc tabstat ln_gdp_pc growthrate stdDem gfcf gfcf_missing tradeopen tradeopen_missing educ educ_missing, ///
    stat(mean sd min max N) format(%9.3f) ///
    title(Table 2: Summary Statistics) ///
    save(Myfile.doc) replace

/* detail info. about ln_gdp_pc and stdDem */
sum growthrate stdDem, detail
asdoc sum growthrate stdDem, detail title(Table 3: growthrate and stdDem detail information) save(Myfile.doc), replace

binscatter growthrate stdDem, ///
    nquantiles(15) ///
    ytitle("Real GDP per Capita Growth rate") ///
    xtitle("Standardized democracy index") ///
    title("Figure 1: Growth Rate and Democracy") ///
    note("Each point represents the mean within a bin of the democracy index.")
	
twoway ///
    (lpoly growthrate stdDem), ///
    ytitle("Real GDP per Capia Growth rate") ///
    xtitle("Standardized democracy index") ///
    title("Figure 2: Nonlinear Fit: Growth rate and Democracy") ///
    note("Local polynomial fit shows the nonlinear relationship.")
	
/* Model 1 */
* Test for Growth rate lag
xtset country_id year
xtreg growthrate stdDem L.growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title("Table 6: Test Growth Rate Lag") ///
    ctitle("Lag 1") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate stdDem L(1/2).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-2") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-3") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate stdDem L(1/4).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-4") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate stdDem L(1/5).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-5") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate stdDem L(1/6).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-6") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

* Model 1 outcome
reg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing, ///
    vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title("Table 7: Democracy and GDP Growth") ///
    ctitle("No FE") ///
    drop(educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, No, Year FE, No, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)
			
xtreg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing, ///
    fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Country FE") ///
    drop(educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, No, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)
			
xtreg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Country FE + Year FE") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)
			
/* Model 2 */
* Test for Growth rate lag
xtset country_id year
xtreg growthrate c.stdDem##c.educ L.growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title("Table 8: Test Growth Rate Lag (Model 2)") ///
    ctitle("Lag 1") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate c.stdDem##c.educ L(1/2).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-2") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate c.stdDem##c.educ L(1/3).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-3") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)


xtreg growthrate c.stdDem##c.educ L(1/4).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-4") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)



xtreg growthrate c.stdDem##c.educ L(1/5).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Lag 1-5") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

* Model 2 outcome
reg growthrate c.stdDem##c.educ L(1/3).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing, ///
    vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title("Table 9: Democracy and GDP Growth (Model 2)") ///
    ctitle("No FE") ///
    drop(educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, No, Year FE, No, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)
			
xtreg growthrate c.stdDem##c.educ L(1/3).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing, ///
    fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Country FE") ///
    drop(educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, No, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)
			
xtreg growthrate c.stdDem##c.educ L(1/3).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Country FE + Year FE") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)

			
*create table for two models with country and year FE
xtreg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title(Table 10:Baseline regression of two models) ///
	ctitle("Model 1") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)

xtreg growthrate c.stdDem##c.educ L(1/3).growthrate ///
    gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    ctitle("Model 2") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, ///
            Growth Lags, 3, Controls, Yes, ///
            Missing Indicators, Yes, ///
            SE clustered by country, Yes)

/* Robustness Check (add stdDem lag in model 1) */
* Test for lag
xtset country_id year
xtreg growthrate L(0/5).stdDem L(1/5).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
    title("Table 11: Test Growth Rate and stdDem Lag") ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/5).stdDem L(1/4).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/5).stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/4).stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/3).stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/2).stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", replace ///
	title(Table 11: Continue) ctitle((6)) ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
            Missing Indicators, Yes, SE clustered by country, Yes)
			
xtreg growthrate L(0/1).stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
	ctitle((7)) ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
	Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate stdDem L(1/3).growthrate ///
    educ gfcf tradeopen ///
    educ_missing gfcf_missing tradeopen_missing ///
    i.year, fe vce(cluster country_id)

outreg2 using "Myfile.doc", append ///
	ctitle((8)) ///
    drop(i.year educ_missing gfcf_missing tradeopen_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, ///
	Missing Indicators, Yes, SE clustered by country, Yes)
