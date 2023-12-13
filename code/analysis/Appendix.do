
*************************************
* Figure A.2: Rennovations
*************************************

use "$data/leasehold_flats.dta", clear
gen years_held_n = round(years_held)
binscatter2 d_bedrooms years_held_n if date_hedonics!=L_date_hedonics & years_held < 10, xtitle("Years Held") ytitle("Mean Change in Number of Bedrooms") line(connect) msymbol(O) 
graph export "$fig/renovations_by_years_held.png", replace

*************************************
* Figure A.3: Hazard Rate
*************************************

use "$data/leasehold_panel.dta", clear
scalar correction = 1.17

keep if L_duration<=125
collapse (sum) num_extensions=extended (count) n=extended, by(L_duration_bin)

gen hazard_rate = num_extension/n
gen se = sqrt(hazard_rate*(1-hazard_rate)/n)

replace hazard_rate = hazard_rate*100
replace se = se*100

gen ub = hazard_rate + 1.96*se
gen lb = hazard_rate - 1.96*se

twoway 	(line hazard_rate L_duration, lcolor(black)) ///
		(rarea ub lb L_duration, color(gray%30) lcolor(%0)) if se>0, ///
		xtitle("Duration") ytitle("% Extended") ///
		xline(80, lcolor(red) lpattern(dash)) ///
		legend(off)  ylabel(0(2)6)
graph export "$fig/hazard_rate.png", replace

replace hazard_rate = hazard_rate * correction // Scale up because we know we are missing some only-post extensions
replace ub = ub * correction
replace lb = lb * correction
twoway 	(line hazard_rate L_duration, lcolor(black)) ///
		(rarea ub lb L_duration, color(gray%30) lcolor(%0)) if se>0, ///
		xtitle("Duration") ytitle("% Extended") ///
		xline(80, lcolor(red) lpattern(dash)) ///
		legend(off) ylabel(0(2)6)
graph export "$fig/hazard_rate_corrected.png", replace

*************************************
* Figure A.4: Cumulative Hazard Rate
*************************************

use "$data/leasehold_panel.dta", clear
keep if year<2020
keep if L_duration<=125 & L_duration > 0
collapse (sum) num_extensions=extended (count) n=extended, by(L_duration)

gen hazard_rate = num_extension/n * correction
replace hazard_rate=0 if L_duration>125

* Baseline
gsort -L_duration
gen inv_hazard = 1-hazard
gen prod_inv_hazard = inv_hazard if _n==1
replace prod_inv_hazard = inv_hazard * prod_inv_hazard[_n-1] if _n>1
gen L_prod_inv_hazard = prod_inv_hazard[_n-1]
gen prob_E_AND_T = hazard * L_prod_inv_hazard
gen cum_prob = sum(prob_E_AND_T)
replace cum_prob = cum_prob * 100

twoway (line cum_prob L_duration, lcolor(black)), ///
		xtitle("Duration") ytitle("% Have Extended")
graph export "$fig/cumulative_hazard.png", replace


*************************************
* Figure A.5-A.7 + A.9 + ??: Histograms
*************************************

use "$data/leasehold_flats.dta", clear
histogram duration if duration<1000, xtitle("Duration") percent width(5)
graph export "$fig/sale_duration_histogram.png", replace

use "$working/lease_data.dta", clear
histogram number_years if number_years>50 & number_years<250, xtitle("Registered Lease Term") percent width(5) xlabel(99 "99" 125 "125" 189 "189" 215 "215")
graph export "$fig/lease_term_histogram.png", replace

gen diff = datediff(date_from, date_registered, "year")
histogram diff if diff>=0 & diff<50, xtitle("Years Between Initiation and Registration") percent width(1)
graph export "$fig/time_to_registration.png", replace

histogram diff if diff>=0 & diff<50 & round(number_years)==189, xtitle("Years Between Initiation and Registration") percent width(1)
graph export "$fig/time_to_registration_189.png", replace

histogram diff if diff>=0 & diff<50 & round(number_years)==215, xtitle("Years Between Initiation and Registration") percent width(1)
graph export "$fig/time_to_registration_215.png", replace

gen d = date_trans - date_rm
histogram d if d < 365*2 & d>0, xtitle("Days Between Last Listing and Transaction Date") percent width(7)
graph export "$fig/time_from_listing_histogram.png", replace


use "$data/experiments_incflippers.dta", clear

histogram years_held, xtitle("Years Between Transactions") percent xline(1) width(1)
graph export "$fig/years_held_histogram.png", replace

use "$data/experiments.dta", clear

histogram year, xtitle("") frequency ylabel(, format(%9.0gc))  discrete
graph export "$fig/date_histogram.png", replace

histogram extension_amount if extension_amount<1000, xtitle("") percent 
graph export "$fig/extension_amount_histogram.png", replace

histogram T_at_ext if k90 & T_at_ext<125, xtitle("Duration Before Extension") percent
graph export "$fig/extension_duration_histogram.png", replace

gen time_between = datediff(L_date_trans, date_registered, "year")
histogram time_between if k90, xtitle("Years Between Transaction And Extension") percent width(1)
graph export "$fig/time_to_extension_histgram.png", replace

*****************************************
* Figure A.??: Results Using Public Data
****************************************

use "$data/experiments.dta", clear

foreach tag in "" "_algorithm" {
	gen rK`tag' = .
	gen ub`tag' = .
	gen lb`tag' = .	
}
gen xaxis = _n+$year0-1 if _n+$year0-1 <= $year1

forv year=$year0(1)$year1 {
	// Baseline
	qui: nl $nlfunc if year==`year', initial(rK 3) variables(did T k)
	qui: replace rK = _b[/rK] if xaxis==`year'
	qui: replace ub = _b[/rK] + 1.96 * _se[/rK] if xaxis==`year'
	qui: replace lb = _b[/rK] - 1.96 * _se[/rK] if xaxis==`year'
	
	// Subset
	if `year' >=2005 {
		qui: nl $nlfunc if year==`year' & inlist(number_years, 189, 215), initial(rK 3) variables(did T k)
		qui: replace rK_algorithm = _b[/rK] if xaxis==`year'
	}
}

twoway 	(line rK rK_algorithm xaxis, lcolor(black "$accent1")) ///
		(rarea ub lb xaxis, color(gray%30) lcolor(%0)), ///
		legend(order(1 "Baseline" 2 "Using 189/215 Algorithm") ring(0) position(2)) ///
		xtitle("") ytitle("Natural Rate of Return of Capital (r{sub:K}*)") xlabel($year0(5)$year1)
graph export "$fig/natural_rate_timeseries_algorithm.png", replace


*************************************
* Figure A.8: Price to Rent
*************************************

*************************************
* Figure A.11: Holding Period 
*				Binscatter
*************************************

use "$data/experiments.dta", clear

binscatter2 did years_held if k90, nq(1000) xtitle("Years Held") ytitle("Price Difference After Extension vs. Control") absorb(year)
graph export "$fig/holding_period_binscatter.png", replace

*************************************
* Figure A.12: Hedonics Binscatters
*************************************

use "$data/leasehold_flats.dta", clear

foreach var of varlist bedrooms bathrooms livingrooms floorarea age log_rent {
	local lab: variable label `var'
	binscatter2 log_price `var', nq(1000) xtitle("`lab', Residualized") ytitle("Log(Price), Residualized") absorb(lpa_code)
	graph export "$fig/log_price_`var'_binscatter.png", replace
}

*************************************
* Figure A.??: Natural Rate 
* by Extension Amount
*************************************

use "$data/experiments.dta", clear

gen xaxis = _n+$year0-1 if _n+$year0-1 <= $year1
gen over80 = T>80

gen oth = !k90 & !k700p
gen all = 1

foreach tag in k90 k700p oth all {
	gen rK_`tag' = .
	gen ub_`tag' = .
	gen lb_`tag' = .	
}

forv year=$year0(1)$year1 {
	foreach var of varlist k90 k700p oth all {
		// Baseline
		qui: nl $nlfunc if year==`year' & `var', initial(rK 3) variables(did T k)
		qui: replace rK_`var' = _b[/rK] if xaxis==`year'
		qui: replace ub_`var' = _b[/rK] + 1.96 * _se[/rK] if xaxis==`year'
		qui: replace lb_`var' = _b[/rK] - 1.96 * _se[/rK] if xaxis==`year'
	}
}

twoway 	(line rK_all rK_k90 rK_k700p rK_oth xaxis, lpattern(solid dash shortdash dash_dot) lcolor("black" "$accent1" "$accent2" "$accent3")) ///
		(rarea ub_all lb_all xaxis, color(gray%30) lcolor(%0)), ///
		legend(order(1 "All" 2 "90 Year Extensions" 3 "700+ Year Extensions" 4 "Other Extensions") ring(0) position(2)) ///
		xtitle("") ytitle("Natural Rate of Return of Capital (r{sub:K}*)") xlabel($year0(5)$year1)
graph export "$fig/natural_rate_timeseries_by_k.png", replace

*************************************
* Table A.1: English Housing Survey
*************************************

use "$data/ehs.dta", clear

gen lh_str = "Leasehold" if leasehold 
replace lh_str = "Freehold" if !leasehold

eststo clear
estpost tabstat income age has_mortgage ltv, by(lh_str) statistics(mean semean) columns(statistics) nototal
esttab using "$tab/lh_fh_stats.tex", ///
	main(mean %9.2fc ) aux(semean %9.2fc) nostar unstack nonum stats(N, fmt(%9.0gc)) ///
	varlabels(income "Income" age "Age" ltv "LTV" has_mortgage "\% Have Mortgage" ) ///
	nonotes replace
	
*************************************
* Table A.4: Mortgage Stats
*************************************

eststo clear
estpost tabstat mortgagelength ltv has_mortgage varrate, by(length_at_purchase) statistics(mean semean) columns(statistics)
esttab using "$tab/mortgage_stats.tex", ///
	main(mean "1") aux(semean "1") nostar unstack nonum stats(N, fmt(%9.0gc)) ///
	varlabels(mortgagelength "Mortgage Length" ltv "LTV" has_mortgage "\% Have Mortgage" varrate "\% Adjustable Rate") ///
	nonotes addnotes("mean reported; standard error of mean in parentheses") ///
	replace

*************************************
* Figure A.22: Time on Market
*************************************

use "$data/leasehold_flats.dta", clear

reghdfe time_on_market i.bedrooms i.floorarea_50 i.age_50, absorb(i.year##i.quarter##i.outcode) residuals(tom_res)
gen duration_yr = int(duration)
gcollapse time_on_market=tom_res (semean) se=tom_res, by(duration_yr)
gen ub = time_on_market + 1.96*se
gen lb = time_on_market - 1.96*se
twoway  (scatter time_on_market duration) ///
		(rcap ub lb duration) if duration>=40 & duration<=100, ///
		legend(off) xtitle("Duration") ytitle("Time on Market, Residuals")  ///
		xlabel(40(20)100)
graph export "$fig/time_on_market.png", replace
*************************************
* Figure A.24: Liquidity Premium
*************************************

use "$data/experiments.dta", clear
keep if T<=80

nl $nlfunc, initial(rK 3) variables(did T k)
global rK = _b[/rK]

* Plot functional form 
global r_lp = 4
global lambda = 70 
global d = 1
twoway ( function did = ln(  ((1-exp(-($r_lp /100) * (x+90-$lambda ) ))/($r_lp /100)) ///
			+ ((1-exp(-(($r_lp +$d )/100) * $lambda )) * (exp(-($r_lp /100) * (x+90-$lambda ) )) / (($r_lp +$d )/100) ) ) ///
	   - ln(  ((1-exp(-($r_lp /100) * max(0, (x-$lambda ) ) ))/($r_lp /100)) ///
			+ ((1-exp(-(($r_lp +$d )/100) * min(x,$lambda ) )) * (exp(-($r_lp /100) * max(0, (x-$lambda )) ) ) / (($r_lp +$d )/100) ) ), ///
			range(20 150)) ///
		(function y=ln(1-exp(-($r_lp /100) * (x+90) )) - ln(1-exp(-($r_lp /100) * x)), range(20 150) lpattern(dash)), ///
		legend(order(1 "With Liquidity Premium" 2 "Without Liquidity Premium")) ///
		xtitle("Duration") ytitle("Price Difference After Extension vs. Control") ///
		xline($lambda)
graph export "$fig/liqudity_premium_predicted_values.png", replace

*************************************
* Figure A.25: Inflation
*************************************

use "$raw/LW/uk_inflation.dta", clear
append using "$raw/LW/us_inflation.dta"

twoway 	(line inflation date if country=="UK") ///
		(line inflation date if country=="US", lpattern(dash)), ///
		legend(order(1 "UK" 2 "US")) xtitle(" ") ytitle("Inflation Rate") xlabel(, format(%tdCCYY))
graph export "$fig/inflation_us_uk.png", replace

*************************************
* Figure A.26: LW Results
*************************************
foreach y in 2019 2021 {
	import delimited "$raw/LW/output.UK.`y'.csv", clear
	rename r rstar_se
	rename date date_s
	gen date=date(date_s, "YMD")

	gen ub_rstar = rstar + 1.96 * rstar_se
	gen lb_rstar = rstar - 1.96 * rstar_se
			
	twoway 	(line rstar date) ///
			(rarea ub lb date, color(%30)), ///
			legend(off) xtitle("Date") ytitle("r{superscript:*}") xlabel(, format(%tdCCYY))
	graph export "$fig/LW_`y'.png", replace	
}

*************************************
* Table A.??: Seasonality
*************************************
use "$clean/rK_nonseasonal.dta", clear
gen w = 1/var

eststo clear
eststo: reghdfe rK i.quarter [aw=w], absorb(year) vce(robust)
estadd local fe "\checkmark", replace
esttab using "$tab/seasonality.tex", ///
	nomtitle ///
	keep(2.quarter 3.quarter 4.quarter) ///
	varlabels(2.quarter "2nd Quarter" 3.quarter "3rd Quarter" 4.quarter "4th Quarter") ///
	stats(fe N, label("Year FE") fmt(%9.0gc)) ///
	 replace b(2) se(2)
	 
	 
*************************************
* Figure A.??: Risk Premium
*************************************
use "$clean/risk_premium.dta", clear
gen date = year + (quarter-1)/4 

twoway (line risk_premium date, lcolor("$accent1")) ///
		(line g_balanced date, lcolor("$accent2")), ///
		legend(order(1 "Long-Run Risk Premium" 2 "Long-Run Capital Gains")) ///
		xtitle("") ytitle("") ///
		xlabel(2000(5)2025) ylabel(0(1)6)
graph export "$fig/var_results.png", replace


*************************************
* Figure A.??: Sportelli Case
*************************************

// Discontinuity test
use "$data/leasehold_flats.dta", clear

replace duration = round(duration)
replace L_duration = round(L_duration)

drop if years_held <= 1
drop if extension
keep if L_year>=2003

gen d_log_price_ann = d_log_price100/years_held
gen crossed80 = duration<=80 & L_duration>82

eststo clear
local c = 80
qui eststo: reghdfe d_log_price_ann i.crossed80 if L_year>=2003 & L_year<=2006 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n) cluster(year L_year lpa_code_n)
qui: estadd local FE "\checkmark", replace
qui: estadd local period "2003-2006", replace

qui eststo: reghdfe d_log_price_ann i.crossed80 if L_year>2006 & L_year<=2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n) cluster(year L_year lpa_code_n)
qui: estadd local FE "\checkmark", replace
qui: estadd local period "2006-2010", replace

qui eststo: reghdfe d_log_price_ann i.crossed80 if L_year>2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n) cluster(year L_year lpa_code_n)
qui: estadd local FE "\checkmark", replace
qui: estadd local period "2010-2023", replace

esttab * using "$tab/discontinuity_at_80_sportelli.tex", ///
	nomtitle ///
	keep(1.crossed80) varlabels(1.crossed80 "Crossed Cutoff") ///
	stats(FE period N, label("Sale Year x Purchase Year x LA FE" "Period") fmt(%9.0gc)) ///
	 replace b(2) se(2)

// Hazard rate discontinuity
use "$data/leasehold_panel.dta", clear

gen period = 1 if year>=2003 & year<=2006
replace period = 2 if year>2006 & year<2010
replace period = 3 if year>=2010
collapse (mean) extended, by(L_duration_bin period)
replace extended = extended * 100
keep if L_duration<=150

twoway 	(line extended L_duration if period==1, lpattern(solid) lcolor("$accent2") lwidth(medthick)) ///
		(line extended L_duration if period==2, lpattern(solid) lcolor(grey) lwidth(medthick)) ///
		(line extended L_duration if period==3, lpattern(solid) lcolor("$accent1") lwidth(medthick)) if L_duration>10 & L_duration<=125, ///
		legend(order(1 "2003-2006" 2 "2006-2010" 3 "2010-2020") ring(0) position(2)) ///
		xtitle("Duration") ytitle("% Extended") ///
		xline(80, lcolor(red) lpattern(dash))
graph export "$fig/hazard_rate_2period_sportelli.png", replace
