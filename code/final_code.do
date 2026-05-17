
clear all
set more off
version 18


/* 0. Project directories */
/* Before running this code, set the working directory to the repository root.
   Replace the path (/your/path/to) below with your local path. */

cd "/your/path/to/Economietric-empirical-paper"

global ROOT "`c(pwd)'"

global RAW     "$ROOT/data/raw"
global CLEAN   "$ROOT/data/clean"
global TABLES  "$ROOT/output/tables"
global FIGURES "$ROOT/output/figures"
global LOGS    "$ROOT/output/logs"

foreach dir in "$CLEAN" "$TABLES" "$FIGURES" "$LOGS" {
    capture mkdir "`dir'"
}

capture log close
log using "$LOGS/final code.log", replace text


/* 1. Required user-written packages */

cap which outreg2
if _rc ssc install outreg2, replace

cap which binscatter
if _rc ssc install binscatter, replace

cap which asdoc
if _rc ssc install asdoc, replace

/* 2. data clean programs */
/* 2.1 clean program for datasets from world bank */
capture program drop clean_wb
program define clean_wb
    syntax using/, OUTfile(string) VARNAME(string)

    import delimited using `"`using'"', varnames(nonames) clear stringcols(_all)

    * World Bank downloads have column labels in the first row when imported
    drop in 1

    rename v3 country
    rename v4 code
    drop v1 v2
    drop if missing(code)

    local start_year = 1960
    local end_year   = 2025
    local first_col  = 5
    local last_col   = `first_col' + (`end_year' - `start_year')

    local yr = `start_year'
    forvalues j = `first_col'/`last_col' {
        capture confirm variable v`j'
        if !_rc {
            rename v`j' y`yr'
            local ++yr
        }
    }
	/* reshape dataset */
    reshape long y, i(code) j(year)
    rename y `varname'
    replace `varname' = "" if `varname' == ".."
    destring `varname', replace force

    keep country code year `varname'
    order country code year `varname'
    sort code year
    isid code year
    save `"`outfile'"', replace
end

/* 2.2 clean program for democracy index dataset */
capture program drop clean_dem
program define clean_dem
    syntax using/, OUTfile(string) PRIORITY(integer)

    import delimited using `"`using'"', varnames(1) case(lower) clear

    rename entity country
    destring year, replace force
    destring democracy, replace force
    drop if missing(code)

    gen source_priority = `priority'
    keep country code year democracy source_priority
    order country code year democracy source_priority
    sort code year source_priority
    save `"`outfile'"', replace
end

/* 3. Create dta file */

clean_wb using "$RAW/REAL GDP.csv", outfile("$CLEAN/real_gdp.dta") varname(rgdppc)
clean_wb using "$RAW/Tradeopenness.csv", outfile("$CLEAN/tradeopenness.dta") varname(tradeopen)
clean_wb using "$RAW/GFCF.csv", outfile("$CLEAN/gfcf.dta") varname(gfcf)

clean_dem using "$RAW/democracy-index-polity.csv", outfile("$CLEAN/democracy.dta") priority(1)

capture confirm file "$RAW/democracy-index-polity extend.csv"
if !_rc {
    clean_dem using "$RAW/democracy-index-polity extend.csv", outfile("$CLEAN/democracy_extension.dta") priority(2)

    use "$CLEAN/democracy.dta", clear
    append using "$CLEAN/democracy_extension.dta"
    sort code year source_priority
    by code year: keep if _n == 1
    drop source_priority
    isid code year
    save "$CLEAN/democracy.dta", replace
}
else {
    use "$CLEAN/democracy.dta", clear
    drop source_priority
    isid code year
    save "$CLEAN/democracy.dta", replace
}

import delimited using "$RAW/mean-years-of-schooling-long-run.csv", varnames(1) case(lower) clear
rename entity country
rename averageyearsofschooling educ
destring year, replace force
destring educ, replace force
drop if missing(code)
keep country code year educ
order country code year educ
sort code year
isid code year
save "$CLEAN/education.dta", replace

/* 4. Merge country-year panel */

use "$CLEAN/real_gdp.dta", clear
isid code year

merge 1:1 code year using "$CLEAN/tradeopenness.dta", keep(master match) keepusing(tradeopen)
tab _merge
assert inlist(_merge, 1, 3)
drop _merge
isid code year

merge 1:1 code year using "$CLEAN/gfcf.dta", keep(master match) keepusing(gfcf)
tab _merge
assert inlist(_merge, 1, 3)
drop _merge
isid code year

merge 1:1 code year using "$CLEAN/democracy.dta", keep(master match) keepusing(democracy)
tab _merge
assert inlist(_merge, 1, 3)
drop _merge
isid code year

merge 1:1 code year using "$CLEAN/education.dta", keep(master match) keepusing(educ)
tab _merge
assert inlist(_merge, 1, 3)
drop _merge
isid code year

encode code, gen(country_id)
order country country_id code year rgdppc democracy tradeopen gfcf educ
save "$CLEAN/final_merged_panel_raw.dta", replace

/* 5. Sample restrictions and variable construction */
/* time restriction from 1960 ~ 2015 */
keep if inrange(year, 1960, 2015)

* Drop observations which miss main variable (real gdp per capita & democracy index) of this project.
drop if missing(rgdppc) | missing(democracy)

/* drop Cambodia observations before 1989 because I need gdp lag in the regression and there has a break between 1978 and 1989 */
drop if code == "KHM" & year < 1989

/* drop countries with extensive missing values in the control variables */
drop if inlist(code, "SOM", "BDI", "LBR", "MMR", "MWI", "NGA")

/* filling education missing value by linear interpolation */
sort code year
bysort code: ipolate educ year, gen(educ_ipolated)
replace educ = educ_ipolated if missing(educ) & !missing(educ_ipolated)
drop educ_ipolated

* generate missing value indicators.
gen tradeopen_missing = missing(tradeopen)
gen gfcf_missing = missing(gfcf)
gen educ_missing = missing(educ)
replace tradeopen = 0 if missing(tradeopen)
replace gfcf = 0 if missing(gfcf)
replace educ = 0 if missing(educ)

/* generate ln real gdp per capita and growth rate */
xtset country_id year
gen ln_gdp_pc  = ln(rgdppc)
gen growthrate = D.ln_gdp_pc * 100

/* generate standardize democracy index */
egen stdDem = std(democracy)

/* label every variable */
label variable country              "Country"
label variable code                 "Country code"
label variable country_id           "Country code"
label variable year                 "Year"
label variable rgdppc               "Real GDP per capita (constant 2015 USD)"
label variable ln_gdp_pc            "Log of real GDP per capita (constant 2015 USD)"
label variable growthrate           "Real GDP per capita growth rate"
label variable democracy            "Democracy index ranges from -10 to 10"
label variable stdDem               "Standardized Democracy Index"
label variable tradeopen            "Trade openness: (exports + imports) as % of GDP"
label variable gfcf                 "Gross fixed capital formation (% of GDP), proxy for investment"
label variable educ                 "Average years of schooling from Barro-Lee dataset"
label variable tradeopen_missing "=1 if the origin value of tradeopen is missing"
label variable gfcf_missing "=1 if the origin value of gfcf is missing"
label variable educ_missing "=1 if the origin value of educ is missing"

order country country_id code year rgdppc ln_gdp_pc growthrate democracy stdDem ///
      gfcf gfcf_missing tradeopen tradeopen_missing educ_missing

compress
save "$CLEAN/final_country_year_panel.dta", replace

/* 6. Descriptive tables and figures */
/* table of variable definition */
local def_table "$TABLES/table_1_variable_definitions.doc"
describe
asdoc describe, title(Table 1: Description of variables) save(`def_table') replace

/* table of summary statistics */
local sum_table "$TABLES/table_2_summary_statistics.doc"
asdoc tabstat ln_gdp_pc growthrate stdDem gfcf ///
    gfcf_missing tradeopen tradeopen_missing educ educ_missing, ///
    stat(mean sd min max N) format(%9.3f) ///
    title(Table 2: Summary Statistics) ///
    save(`sum_table') replace

/* detail info. about growth rate and stdDem */
local detail_table "$TABLES/table_3_detail_statistics.doc"
sum growthrate stdDem, detail
asdoc summarize growthrate stdDem, detail ///
    title(Table 3: Detail information about Growth rate and stdDem)  ///
    save(`detail_table') replace

binscatter growthrate stdDem, ///
    nquantiles(15) ///
    ytitle("Real GDP per Capita Growth rate") ///
    xtitle("Standardized democracy index") ///
    title("Figure 1: Growth Rate and Democracy") ///
    note("Each point represents the mean within a bin of the democracy index.")
graph export "$FIGURES/figure_1_binscatter_growth_democracy.png", replace width(2000)

twoway (lpoly growthrate stdDem), ///
    ytitle("Real GDP per Capita Growth rate") ///
    xtitle("Standardized democracy index") ///
	title("Figure 2: Nonlinear Fit: Growth rate and Democracy")  ///
    note("Local polynomial fit shows the nonlinear relationship.")
graph export "$FIGURES/figure_2_lpoly_growth_democracy.png", replace width(2000)

/* unit root test for growthrate and ln_gdp_pc */
* ln_gdp_pc
xtunitroot fisher ln_gdp_pc, dfuller lags(1)

putdocx clear
putdocx begin

putdocx paragraph
putdocx text ("Table 4: Fisher-Type Panel Unit-Root Test for Log Real GDP per Capita"), bold

putdocx table tbl4 = (5,3), layout(autofitcontents)

putdocx table tbl4(1,1) = ("Test statistic")
putdocx table tbl4(1,2) = ("Statistic")
putdocx table tbl4(1,3) = ("p-value")

putdocx table tbl4(2,1) = ("Inverse chi-squared P")
putdocx table tbl4(2,2) = (r(P)), nformat(%9.3f)
putdocx table tbl4(2,3) = (r(p_P)), nformat(%9.3f)

putdocx table tbl4(3,1) = ("Inverse normal Z")
putdocx table tbl4(3,2) = (r(Z)), nformat(%9.3f)
putdocx table tbl4(3,3) = (r(p_Z)), nformat(%9.3f)

putdocx table tbl4(4,1) = ("Inverse logit L*")
putdocx table tbl4(4,2) = (r(L)), nformat(%9.3f)
putdocx table tbl4(4,3) = (r(p_L)), nformat(%9.3f)

putdocx table tbl4(5,1) = ("Modified inverse chi-squared Pm")
putdocx table tbl4(5,2) = (r(Pm)), nformat(%9.3f)
putdocx table tbl4(5,3) = (r(p_Pm)), nformat(%9.3f)

putdocx paragraph
putdocx text ("Notes: "), bold
putdocx text ("Notes: The test fails to reject the null hypothesis that all panels contain unit roots.")

putdocx table tbl4(.,.), border(all, nil)
putdocx table tbl4(1,.), border(top, single)
putdocx table tbl4(1,.), border(bottom, single)
putdocx table tbl4(5,.), border(bottom, single)
putdocx table tbl4(1,.), bold
putdocx table tbl4(.,2), halign(right)
putdocx table tbl4(.,3), halign(right)

putdocx save "$TABLES/table_4_unit_root_lngdp.docx", replace


*growth rate
xtunitroot fisher growthrate, dfuller lags(1)

putdocx clear
putdocx begin

putdocx paragraph
putdocx text ("Table 5: Fisher-Type Panel Unit-Root Test for Real GDP Growth Rate"), bold

putdocx table tbl4 = (5,3), layout(autofitcontents)

putdocx table tbl4(1,1) = ("Test statistic")
putdocx table tbl4(1,2) = ("Statistic")
putdocx table tbl4(1,3) = ("p-value")

putdocx table tbl4(2,1) = ("Inverse chi-squared P")
putdocx table tbl4(2,2) = (r(P)), nformat(%9.3f)
putdocx table tbl4(2,3) = (r(p_P)), nformat(%9.3f)

putdocx table tbl4(3,1) = ("Inverse normal Z")
putdocx table tbl4(3,2) = (r(Z)), nformat(%9.3f)
putdocx table tbl4(3,3) = (r(p_Z)), nformat(%9.3f)

putdocx table tbl4(4,1) = ("Inverse logit L*")
putdocx table tbl4(4,2) = (r(L)), nformat(%9.3f)
putdocx table tbl4(4,3) = (r(p_L)), nformat(%9.3f)

putdocx table tbl4(5,1) = ("Modified inverse chi-squared Pm")
putdocx table tbl4(5,2) = (r(Pm)), nformat(%9.3f)
putdocx table tbl4(5,3) = (r(p_Pm)), nformat(%9.3f)

putdocx paragraph
putdocx text ("Notes: "), bold
putdocx text ("The test rejects the null hypothesis that all panels contain unit roots.")

putdocx table tbl4(.,.), border(all, nil)
putdocx table tbl4(1,.), border(top, single)
putdocx table tbl4(1,.), border(bottom, single)
putdocx table tbl4(5,.), border(bottom, single)
putdocx table tbl4(1,.), bold
putdocx table tbl4(.,2), halign(right)
putdocx table tbl4(.,3), halign(right)

putdocx save "$TABLES/table_5_unit_root_growthrate.docx", replace

/* 7. Regression setup */
local control_zero educ_missing gfcf_missing tradeopen_missing
local control educ gfcf tradeopen
local control_noneduc gfcf tradeopen
xtset country_id year

/* 8. Model outcome */
/* Model 1 */
*Lag-length checks

xtreg growthrate stdDem L.growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_6_model_1_lag_checks.doc", replace ///
    title("Table 6: Growth Lag Checks") ///
    ctitle("Lag 1") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

forvalues lag = 2/6 {
    xtreg growthrate stdDem L(1/`lag').growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
    outreg2 using "$TABLES/table_6_model_1_lag_checks.doc", append ///
        ctitle("Lag 1-`lag'") ///
        drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
        addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)
}

*Model 1 outcome

reg growthrate stdDem L(1/3).growthrate `control' `control_zero' , vce(cluster country_id)
outreg2 using "$TABLES/table_7_model_1.doc", replace ///
    title("Table 7: Democracy and GDP Growth") ///
    ctitle("No FE") ///
    drop(tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, No, Year FE, No, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate stdDem L(1/3).growthrate `control' `control_zero' , fe vce(cluster country_id)
outreg2 using "$TABLES/table_7_model_1.doc", append ///
    ctitle("Country FE") ///
    drop(tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, No, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)
 
xtreg growthrate stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_7_model_1.doc", append ///
    ctitle("Country FE + Year FE") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

/* Model 2 */
*Lag-length checks

xtreg growthrate c.stdDem##c.educ L.growthrate `control_noneduc' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_8_model_2_lag_checks.doc", replace ///
    title("Table 8: Growth Lag Checks (Model 2)") ///
    ctitle("Lag 1") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

forvalues lag = 2/5 {
    xtreg growthrate c.stdDem##c.educ L(1/`lag').growthrate `control_noneduc' `control_zero' i.year, fe vce(cluster country_id)
    outreg2 using "$TABLES/table_8_model_2_lag_checks.doc", append ///
        ctitle("Lag 1-`lag'") ///
        drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
        addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)
}

*Model 2 outcome
reg growthrate c.stdDem##c.educ L(1/3).growthrate `control_noneduc' `control_zero', vce(cluster country_id)
outreg2 using "$TABLES/table_9_model_2.doc", replace ///
    title("Table 9: Democracy and GDP Growth (Model 2)") ///
    ctitle("No FE") ///
    drop(tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, No, Year FE, No, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate c.stdDem##c.educ L(1/3).growthrate `control_noneduc' `control_zero', fe vce(cluster country_id)
outreg2 using "$TABLES/table_9_model_2.doc", append ///
    ctitle("Country FE") ///
    drop(tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, No, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate c.stdDem##c.educ L(1/3).growthrate `control_noneduc' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_9_model_2.doc", append ///
    ctitle("Country FE + Year FE") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

* Compare modle 1 and model 2 with country and year FE.
xtreg growthrate stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_10_model_comparison.doc", replace ///
    title("Table 10: Baseline regression of two models") ///
    ctitle("Model 1") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate c.stdDem##c.educ L(1/3).growthrate `control_noneduc' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_10_model_comparison.doc", append ///
    ctitle("Model 2") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Growth Lags, 3, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

/* 9. Robustness Check (add stdDem lag in model 1) */
* Test for lag

xtreg growthrate L(0/5).stdDem L(1/5).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness.doc", replace ///
    title("Table 11: Growth Rate and stdDem Lag Chekcs") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/5).stdDem L(1/4).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness.doc", append ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/5).stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness.doc", append ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/4).stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness.doc", append ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/3).stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness_cont.doc", replace ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/2).stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness_cont.doc", append ///
    title ("Table 11: Continue") ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate L(0/1).stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness_cont.doc", append ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

xtreg growthrate stdDem L(1/3).growthrate `control' `control_zero' i.year, fe vce(cluster country_id)
outreg2 using "$TABLES/table_11_democracy_lag_robustness_cont.doc", append ///
    drop(i.year tradeopen_missing gfcf_missing educ_missing) ///
    addtext(Country FE, Yes, Year FE, Yes, Controls, Yes, Missing Indicators, Yes, SE clustered by country, Yes)

log close
