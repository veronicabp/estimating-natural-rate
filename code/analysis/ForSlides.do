* Set parameters
global fig "$fig/For_Slides"

* Event Study
use "$data/event_study/k90.dta", clear
gen hedonics = 0 
append using  "$data/event_study/lineark90.dta"
replace hedonics = 1 if hedonics==.

global xrange = 10

twoway 	(scatter diff time if hedonics==0, mcolor(gray*1.3)) ///
		(rcap ub lb time if hedonics==0, lcolor(gray*1.3)) if abs(time)<=$xrange, ///
		xtitle("Years From Extension") ytitle("Log(Price, Extended) - Log(Price, Control)") ///
		xline(0, lcolor(black)) yline(0, lcolor(black) lpattern(solid)) ///
		xlabel(-$xrange(1)$xrange) ylabel(-0.1(0.1)0.3) xlabel(-10(2)10, labsize(medium))  ///
		legend(order(1 "Baseline" 3 "") position(6))
graph export "$fig/event_study_1.png", replace

twoway 	(scatter diff time if hedonics==0, mcolor(gray*1.3)) ///
		(rcap ub lb time if hedonics==0, lcolor(gray*1.3)) ///
		(scatter diff time if hedonics==1, mcolor("$accent1")) ///
		(rcap ub lb time if hedonics==1, lcolor("$accent1")) if abs(time)<=$xrange, ///
		xtitle("Years From Extension") ytitle("Log(Price, Extended) - Log(Price, Control)") ///
		xline(0, lcolor(black)) yline(0, lcolor(black) lpattern(solid)) ///
		xlabel(-$xrange(1)$xrange) ylabel(-0.1(0.1)0.3) xlabel(-10(2)10, labsize(medium))  ///
		legend(order(1 "Baseline" 3 "Hedonics") position(6))
graph export "$fig/event_study_2.png", replace

twoway 	(scatter diff time if hedonics==0, mcolor(gray*1.3)) ///
		(rcap ub lb time if hedonics==0, lcolor(gray*1.3)) if time>-$xrange & time<0, ///
		xtitle("Years From Extension") ytitle("Log(Price, Extended) - Log(Price, Control)") ///
		xline(0, lcolor(black)) yline(0, lcolor(black) lpattern(solid)) ///
		xlabel(-$xrange(1)0) ylabel(-0.1(0.1)0.3) xlabel(-10(2)0, labsize(medium))  ///
		legend(order(1 "Baseline" 3 "") position(6))
graph export "$fig/event_study_cutoff.png", replace


* Time Series 
use "$clean/rK_yearly.dta", clear
gen yearly = 1
keep if year<=2022
append using "$clean/rK_monthly.dta"

keep if yearly==1 | xaxis12 >= 12*$year1
drop if rK==.

gen xaxis = xaxis12/12
sort xaxis

local x = $year1 + 1
local y = rK[_N] + 0.2

twoway 	(line rK xaxis) ///
		(rarea ub lb xaxis if xaxis12 < 12*$year1 + $month1 - 1, color(%30) lcolor(%0)) ///
		(scatter rK xaxis if xaxis12 >= 12*$year1 - 1, mcolor("$accent1") msymbol(O) msize(vsmall)) ///
		(scatter rK xaxis if xaxis12 == 12*$year1 + $month1 - 1, mcolor("$accent1") msymbol(O) msize(vsmall)), ///
		legend(order(3 "Monthly Real-Time Estimates") ring(0) position(2)) xtitle("") ytitle("Natural Rate of Capital (r{sub:K}*)", size(medlarge)) xlabel($year0(5)2024.5 , labsize(medium)) ///
		text(`y' `x' "$month1_str $year1", color($accent1) size(medium))
graph export "$fig/natural_rate_timeseries.png", replace

* Corrected Time-Series
use "$data/experiments.dta", clear
scalar alpha = 0.72

foreach tag in "" "_corrected" {
	gen rK`tag' = .
	gen ub`tag' = .
	gen lb`tag' = .	
}
gen xaxis12 =  $year0*12 + _n - 1 if $year0*12 + _n <= $year1 * 12 + $month1
gen over80 = T>80

local y1 = $year1 - 1
forv year=$year0(1)`y1' {
	// Baseline
	qui: nl $nlfunc if year==`year', initial(rK 3) variables(did T k)
	qui: replace rK = _b[/rK] if xaxis==`year' * 12
	qui: replace ub = _b[/rK] + 1.96 * _se[/rK] if xaxis==`year' * 12
	qui: replace lb = _b[/rK] - 1.96 * _se[/rK] if xaxis==`year' * 12
	
	// Corrected
	qui: nl (did = ln(1-exp(-$rK_func  *(T+k))) ///
			- ln(1-exp(-$rK_func * T) + ///
			(over80 * Pi * alpha) * (exp(-$rK_func * T) - exp(-$rK_func  * (T+90))) )) if year==`year', initial(rK 3) variables(did T k)

	qui: replace rK_corrected = _b[/rK] if xaxis==`year'*12
}

forv month = 1(1)$month1 {
	// Baseline
	qui: nl $nlfunc if year==$year1 & month==`month', initial(rK 3) variables(did T k)
	qui: replace rK = _b[/rK] if xaxis==$year1 * 12 + `month'
	qui: replace ub = _b[/rK] + 1.96 * _se[/rK] if xaxis==$year1 * 12 + `month'
	qui: replace lb = _b[/rK] - 1.96 * _se[/rK] if xaxis==$year1 * 12 + `month'
	
	// Corrected
	qui: nl (did = ln(1-exp(-$rK_func  *(T+k))) ///
			- ln(1-exp(-$rK_func * T) + ///
			(over80 * Pi * alpha) * (exp(-$rK_func * T) - exp(-$rK_func  * (T+90))) )) if year==$year1 & month==`month', initial(rK 3) variables(did T k)

	qui: replace rK_corrected = _b[/rK] if xaxis==$year1 * 12 + `month'
}

gen xaxis = xaxis12/12
drop if rK==.

local x = $year1 + 1
local y = rK[_N] + 0.2
twoway 	(line rK rK_corrected xaxis, lcolor(gs4 "$accent1")) ///
		(rarea ub lb xaxis if xaxis12 < 12*$year1 + $month1 - 1, color(gray%30) lcolor(%0)) ///
		(scatter rK xaxis if xaxis12 == 12*$year1 + $month1 - 1, mcolor(gs4) msymbol(O) msize(vsmall)), ///
		legend(order(1 "Baseline" 2 "Corrected for Option Value") ring(0) position(2)) xtitle("") ytitle("Natural Rate of Capital (r{sub:K}*)", size(medlarge)) xlabel($year0(5)2024.5 , labsize(medium)) ///
		text(`y' `x' "$month1_str $year1", color(gs4) size(medium))

graph export "$fig/natural_rate_timeseries_corrected.png", replace
