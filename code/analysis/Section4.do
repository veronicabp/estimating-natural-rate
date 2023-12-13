******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program produces the figures and tables for Section 4.
******************************************************************

* Prepare data
use "$data/leasehold_flats.dta", clear

// Use the same sample of extensions as our main sample 
merge 1:1 property_id date_trans using "$data/experiments.dta"
keep if _merge==3 | !extension
keep if duration<=200 | extension
drop if years_held<=1

label var floorarea "Floor Area"
label var yearbuilt "Year Built"
label var log_rent "Log Rent"
label var bathrooms "Bathrooms"
label var bedrooms "Bedrooms"
label var livingrooms "Living Rooms"
label var age "Property Age"

gen year_hedonics = year(date_hedonics)
gen year_rent = year(date_rent)
gen L_year_hedonics = year(L_date_hedonics)
gen L_year_rent = year(L_date_rent)

*******************************
* Figure 5: Density plots
********************************

foreach var of varlist bedrooms bathrooms livingrooms floorarea age log_rent {
	cap drop `var'_res
	
	if "`var'" == "log_rent100" qui eststo: reghdfe `var', absorb(i.lpa_code_n##i.L_duration10yr) residuals(`var'_res)
	else qui reghdfe `var', absorb(i.lpa_code_n##i.L_duration10yr) residuals(`var'_res)
	
	local lab: variable label `var'
	local title "`lab', Residualized"
	
	twoway (kdensity `var'_res if extension, bwidth(1) kernel(gaussian) lcolor("$accent1")) ///
		 (kdensity `var'_res if !extension, bwidth(1) kernel(gaussian) lcolor(gs4) lpattern(dash)), ///
		ytitle("Density") ///
		xtitle("`title'") ///
		legend(order(1 "Extended" 2 "Not Extended"))
	graph export "$fig/`var'_kdensity.png", replace  
}

*******************************
* Table 2A: Balance Test
********************************

eststo clear
foreach var of varlist bedrooms bathrooms livingrooms floorarea age log_rent100  {
	eststo: reghdfe `var' i.extension, absorb(i.lpa_code_n##i.L_duration10yr) cluster(lpa_code_n)
	estadd local fe "\checkmark", replace
}

esttab using "$tab/balance_test.tex", ///
	keep(1.extension) varlabel(1.extension "Extension") ///
	s(fe N, label("Fixed Effects") fmt("%9.0fc")) ///
	mtitles("Num Bedrooms" "Num Bathrooms" "Num Living Rooms" "Floor Area" "Age" "Log Rental Price") ///
	se replace se(3) b(2) 
	
// Repeat only for 90 year extensions
eststo clear
foreach var of varlist bedrooms bathrooms livingrooms floorarea age log_rent100  {
	eststo: reghdfe `var' i.extension if (!extension | round(extension_amount,5)==90), absorb(i.lpa_code_n##i.L_duration10yr) cluster(lpa_code_n)
	estadd local fe "\checkmark", replace
}

esttab using "$tab/balance_test_k90.tex", ///
	keep(1.extension) varlabel(1.extension "Extension") ///
	s(fe N, label("Fixed Effects") fmt("%9.0fc")) ///
	mtitles("Num Bedrooms" "Num Bathrooms" "Num Living Rooms" "Floor Area" "Age" "Log Rental Price") ///
	se replace se(3) b(2) 

	
*************************************
* Table 2B: Placebo Test
*************************************

eststo clear
foreach var of varlist bedrooms bathrooms livingrooms floorarea {
	eststo: reghdfe d_`var' i.extension if year_hedonics!=L_year_hedonics, absorb(i.lpa_code_n##i.L_duration10yr##year_hedonics##L_year_hedonics) cluster(year_hedonics L_year_hedonics lpa_code_n)
	estadd local fe "\checkmark", replace
}
eststo: reghdfe d_log_rent100 i.extension if year_rent!=L_year_rent, absorb(i.lpa_code_n##i.L_duration10yr##year_rent##L_year_rent) cluster(year_rent L_year_rent lpa_code_n)
estadd local fe "\checkmark", replace

esttab using "$tab/placebo_test.tex", ///
	keep(1.extension) varlabel(1.extension "Extension") ///
	mtitles("$\Delta$ Num Bedrooms" "$\Delta$ Num Bathrooms"  "$\Delta$ Num Living Rooms"  "$\Delta$ Floor Area" "$\Delta$ Log(Rent)") ///
	s(fe  N, label("Fixed Effects") fmt("%9.0fc")) ///
	se(2) b(2) replace
	
// For 90 year extensions 
eststo clear
foreach var of varlist bedrooms bathrooms livingrooms floorarea {
	eststo: reghdfe d_`var' i.extension if year_hedonics!=L_year_hedonics & (!extension | round(extension_amount,5)==90), absorb(i.lpa_code_n##i.L_duration10yr##year_hedonics##L_year_hedonics) cluster(year_hedonics L_year_hedonics lpa_code_n)
	estadd local fe "\checkmark", replace
}
eststo: reghdfe d_log_rent100 i.extension if year_rent!=L_year_rent & (!extension | round(extension_amount,5)==90), absorb(i.lpa_code_n##i.L_duration10yr##year_rent##L_year_rent) cluster(year_rent L_year_rent lpa_code_n)
estadd local fe "\checkmark", replace

esttab using "$tab/placebo_test_k90.tex", ///
	keep(1.extension) varlabel(1.extension "Extension") ///
	mtitles("$\Delta$ Num Bedrooms" "$\Delta$ Num Bathrooms"  "$\Delta$ Num Living Rooms"  "$\Delta$ Floor Area" "$\Delta$ Log(Rent)") ///
	s(fe  N, label("Fixed Effects") fmt("%9.0fc")) ///
	se(2) b(2) replace

