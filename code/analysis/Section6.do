******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program produces the figures and tables for Section 6.
******************************************************************

*************************************
* Figure 12: Discontinuity Test
*************************************

use "$data/leasehold_flats.dta", clear

replace duration = round(duration)
replace L_duration = round(L_duration)

// Drop extensions and flippers
drop if years_held <= 1
drop if extension
keep if L_year>=2003

local lb = 60
local ub = 100

gen coeff_post = .
gen coeff_pre = .
gen cutoff = _n + `lb' - 1 if _n + `lb' - 1 <= `ub'

gen d_log_price_ann = d_log_price100/years_held

gen crossed=.
gen crossed80 = duration<=80 & L_duration>82
forv c = `lb'/`ub' {
	di `c'
	qui: if `c' != 80 replace crossed =  duration<=`c' & L_duration>`c'+2 & !crossed80
	qui: else replace crossed = crossed80
	
	qui: sum d_log_price_ann if crossed==1 & L_year<=2010 & duration >= `c'-10 & L_duration <=`c' + 10
	if r(N) > 20 {
		qui: reghdfe d_log_price_ann i.crossed if L_year<=2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n)
		qui: replace coeff_pre = _b[1.crossed] if cutoff==`c'	
	}
	
	qui: sum d_log_price_ann if crossed==1 & L_year>2010 & duration >= `c'-10 & L_duration <=`c' + 10
	if r(N) > 20 {
		qui: reghdfe d_log_price_ann i.crossed if L_year>2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n)
		qui: replace coeff_post = _b[1.crossed] if cutoff==`c'
	}
}

gen l1 = 1 
gen l2 = 2
twoway 	(scatter l1 coeff_pre, mcolor(gray) msymbol(Oh) msize(vlarge)) ///
		(scatter l2 coeff_post, mcolor(gray) msymbol(Oh) msize(vlarge)) ///
		(scatter l1 coeff_pre if cutoff==80, mcolor("$accent1") msymbol(O) msize(vlarge)) ///
		(scatter l2 coeff_post if cutoff==80, mcolor("$accent1") msymbol(O) msize(vlarge)) if cutoff>70, ///
		legend(order(3 "Discontinuity Experiment at 80" 1 "Placebo Experiments Away from 80") rows(2) ring(0) position(2)) ///
		ylabel(0 " " 1 "Pre-2010" 2 "Post 2010" 3 " ") xlabel(-1(0.5)1)  ///
		xtitle("Coefficient")
graph export "$fig/discontinuity_at_80.png", replace

*************************************
* Table 5: Discontinuity Test
************************************* 
eststo clear
local c = 80
qui eststo: reghdfe d_log_price_ann i.crossed80 if L_year<=2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n) cluster(year L_year lpa_code_n)
qui: estadd local FE "\checkmark", replace
qui: estadd local period "Pre 2010", replace

qui eststo: reghdfe d_log_price_ann i.crossed80 if L_year>2010 & duration >= `c'-10 & L_duration <=`c' + 10, absorb(year##L_year##lpa_code_n) cluster(year L_year lpa_code_n)
qui: estadd local FE "\checkmark", replace
qui: estadd local period "Post 2010", replace

esttab * using "$tab/discontinuity_at_80.tex", ///
	nomtitle ///
	keep(1.crossed80) varlabels(1.crossed80 "Crossed Cutoff") ///
	stats(FE period N, label("Sale Year x Purchase Year x LA FE" "Period") fmt(%9.0gc)) ///
	 replace b(2) se(2)

*************************************
* Figure 13: Hazard Rate
*************************************

use "$data/leasehold_panel.dta", clear

gen period = 1 if year<2010 
replace period = 2 if year>=2010 & year<2020
collapse (mean) extended, by(L_duration_bin period)
replace extended = extended * 100
keep if L_duration<=150

twoway 	(line extended L_duration if period==1, lpattern(solid) lcolor(grey) lwidth(medthick)) ///
		(line extended L_duration if period==2, lpattern(solid) lcolor("$accent1") lwidth(medthick)) if L_duration>10 & L_duration<=125, ///
		legend(order(1 "Pre 2010" 2 "Post 2010") ring(0) position(2)) ///
		xtitle("Duration") ytitle("% Extended") ///
		xline(80, lcolor(red) lpattern(dash))
graph export "$fig/hazard_rate_2period.png", replace

*************************************
* Figure 14: Option Value Correction
*************************************

use "$data/experiments.dta", clear
scalar alpha = 0.72

foreach tag in "" "_corrected" {
	gen rK`tag' = .
	gen ub`tag' = .
	gen lb`tag' = .	
}
gen xaxis = _n+$year0-1 if _n+$year0-1 <= $year1
gen over80 = T>80

forv year=$year0(1)$year1 {
	// Baseline
	qui: nl $nlfunc if year==`year', initial(rK 3) variables(did T k)
	qui: replace rK = _b[/rK] if xaxis==`year'
	qui: replace ub = _b[/rK] + 1.96 * _se[/rK] if xaxis==`year'
	qui: replace lb = _b[/rK] - 1.96 * _se[/rK] if xaxis==`year'
	
	// Corrected
	qui: nl (did = ln(1-exp(-$rK_func  *(T+k))) ///
			- ln(1-exp(-$rK_func * T) + ///
			(over80 * Pi * alpha) * (exp(-$rK_func * T) - exp(-$rK_func  * (T+90))) )) if year==`year', initial(rK 3) variables(did T k)

	qui: replace rK_corrected = _b[/rK] if xaxis==`year'
}

twoway 	(line rK rK_corrected xaxis, lcolor(black "$accent1")) ///
		(rarea ub lb xaxis, color(gray%30) lcolor(%0)), ///
		legend(order(1 "Baseline" 2 "Corrected for Option Value") ring(0) position(2)) ///
		xtitle("") ytitle("Natural Rate of Return of Capital (r{sub:K}*)") xlabel($year0(5)$year1)
graph export "$fig/natural_rate_timeseries_corrected.png", replace
