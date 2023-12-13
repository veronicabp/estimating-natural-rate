******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program produces the figures and tables for Section 1.
******************************************************************

*************************************
* Figure 1: Dynamics of natural rate
*************************************
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
		legend(order(3 "Monthly Real-Time Estimates") ring(0) position(2)) xtitle("") ytitle("Natural Rate of Return of Capital (r{sub:K}*)") xlabel($year0(5)2024.5) ///
		text(`y' `x' "$month1_str $year1", color($accent1))
graph export "$fig/natural_rate_timeseries.png", replace

