******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program produces the figures and tables for Section 5.
******************************************************************

*************************************
* Figure 6: Histogram of remaining 
* 			sale duration
*************************************

use "$data/experiments.dta", clear

histogram duration_idx if k90 & duration_idx<160, color(gs4%70) percent width(5) start(0) ///
addplot(histogram duration if k90 & duration<250, color("$accent1"%70) percent width(5) start(0)) ///
 xtitle("Duration") legend(order(1 "Control" 2 "Extended"))
graph export "$fig/duration_histogram.png", replace

*************************************
* Figure 7: Event Study
*************************************

foreach tag in "all" "k90" "k700p" "k200u_m90" "y2003t2010_k90" "y2010t2018_k90" "post2018_k90" "T40t60_k90" "T60t80_k90" "T80p_k90"  {
	use "$data/event_study/`tag'.dta", clear
	gen hedonics = 0 
	append using  "$data/event_study/linear`tag'.dta"
	replace hedonics = 1 if hedonics==.

	global xrange = 10
	
	twoway 	(scatter diff time if hedonics==0, mcolor(gray*1.3)) ///
			(rcap ub lb time if hedonics==0, lcolor(gray*1.3)) ///
			(scatter diff time if hedonics==1, mcolor("$accent1")) ///
			(rcap ub lb time if hedonics==1, lcolor("$accent1")) if abs(time)<=$xrange & ub<=0.35 & lb>=-0.1, ///
			xtitle("Years From Extension") ytitle("Log(Price, Extended) - Log(Price, Control)") ///
			xline(0, lcolor(black)) yline(0, lcolor(black) lpattern(solid)) ///
			xlabel(-$xrange(1)$xrange) ylabel(-0.1(0.1)0.3) xlabel(-10(2)10)  ///
			legend(order(1 "Baseline" 3 "Hedonics") position(6))
	graph export "$fig/event_study_`tag'.png", replace
}


*************************************
* Figure 8: Diff-in-diff binscatter
*************************************

use "$data/experiments.dta", clear

foreach sample of varlist k90 k700p {
	preserve 
		keep if `sample' & T<100
		
		nl $nlfunc, initial(rK 3) variables(did T k)
		global rK = _b[/rK]
		
		if "`sample'" == "k90" local k=90
		else local k=900
	
		binscatter2 did T, nq(100) savedata("$working/binned") replace
		import delimited "$working/binned.csv", clear case(preserve)
		drop __000001

		twoway (scatter did T if T<=120, mcolor("$accent1") msymbol(Oh)) ///
			   (function did = ( ln(1-exp(-$rK /100 * (x+`k'))) - ln(1-exp(-$rK /100 * x)) ) , ///
					range(30 120) lcolor(black) lwidth(medthick)), ///
			   legend(order(2 "Predicted Values From Asset Pricing Function") ring(0) position(2)) xlabel(30(30)120) ///
			   xtitle("Duration Before Extension") ///
			   ytitle("Price Difference After Extension vs. Control") 
		graph export "$fig/yield_curve_`sample'.png", replace
	restore
}

*************************************
* Figure 9: Yield Curve Dynamics
*************************************

use "$data/experiments.dta", clear
keep if k90

cap drop period
gen period = 1 if year<=2008
replace period = 2 if year > 2008 & year <= 2016
replace period = 3 if year > 2016 

forv p=1/3 {
	qui: nl $nlfunc if period==`p', initial(rK 3) variables(did T k)
	global rK`p' = _b[/rK]
}

collapse did (count) n=did, by(T10 period)
local gap = 2
replace T = T-`gap' if period==1
replace T = T+`gap' if period==3

local gap=2
local gr ""
forv p=1/3 {
	if `p'==1 local color "dkorange" 
	if `p'==2 local color "midblue" 
	if `p'==3 local color "lavender" 
	
	qui: sum n if period==`p'
	local num_obs=r(max)
	
	forv i=0(10)`num_obs' {
		local pct = round(100 * `i'/(`num_obs')) + 5 
		if `pct'>100 local pct = 100
		local gr "`gr' (bar did T if period==`p' & n>=`i' & n<`i'+10, bcolor(`color'%`pct') barwidth(`gap'))"
	}
}
twoway	(function y=ln(1-exp(-($rK1 /100) * ((x+`gap')+90) )) - ln(1-exp(-($rK1 /100) * (x+`gap'))), ///
			range(30 100) lpattern(dash) lcolor(dkorange)) ///
		(function y=ln(1-exp(-($rK2 /100) * (x+90) )) - ln(1-exp(-($rK2 /100) * x)), ///
			range(30 100) lpattern(dash) lcolor(midblue)) ///
		(function y=ln(1-exp(-($rK3 /100) * ((x-`gap')+90) )) - ln(1-exp(-($rK3 /100) * (x-`gap'))), ///
			range(30 100) lpattern(dash) lcolor(lavender)) ///
		`gr' ///
		if T>=40 & T<=100 & did>=0 & did<=0.7, ///
		xlabel(40(10)100) ///
		legend(order(1 "Pre 2008" 2 "2008-2016" 3 "Post 2016")) ///
		xtitle("Duration") ytitle("Price Difference After Extension vs. Control") 
graph export "$fig/yield_curve_3period_k90.png", replace

*************************************
* Figure 10: Real time estimates
*************************************

use "$data/rK_monthly.dta", clear
gen xaxis=xaxis12/12
drop if rK==.

twoway 	(line 		rK xaxis									, yaxis(1) lpattern(solid) lcolor(gs10)) ///
		(rarea 		ub lb xaxis if xaxis12<$year1 * 12 + $month1 - 1	, yaxis(1) color(gs10%30) lcolor(%0)) ///
		(scatter 	rK xaxis									, yaxis(1) mcolor(black) msymbol(O)) ///
		(scatter 	rK xaxis if xaxis12==$year1 * 12 + $month1 - 1	, yaxis(1) mcolor("$accent1") msymbol(O)) ///
		(scatter 	rK xaxis if xaxis12==2021 * 12						, yaxis(1) mcolor("$accent2") msymbol(O)) ///
		(line 		uk10y20_real xaxis										, yaxis(2) lcolor(gs4) lpattern(shortdash)) ///
																if xaxis12 >= 2016*12 & xaxis12<=$year1 * 12 + $month1, ///
		legend(order(3 "r{sub:K}* (Left Axis)" 6 "10 Year 20 Real Forward Rate (Right Axis)") ring(0) position(11)) ///
		xtitle("") ytitle("", axis(1)) ytitle("", axis(2)) ///
		ylabel(2(1)6, axis(1)) ylabel(-2(1)2, axis(2)) ///
		xlabel(2016 "2016, Q1" 2018 "2018, Q1" 2020 "2020, Q1" 2022 "2022, Q1" 2024 "2024, Q1" 2024.25 " ") ///
		text(2.55 2023.8 "$month1_str $year1", color("$accent1") size(small)) ///
		text(3.2 2021 "Pandemic Shock", color("$accent2") size(small))
graph export "$fig/realtime_updates_monthly.png", replace

*************************************
* Figure 11: Estimate Stability
*************************************

use "$data/quasi_experimental_stability.dta", clear
gen cs = 0 
append using "$data/cross_sectional_stability.dta"
replace cs = 1 if missing(cs)

drop if !cs & controls=="all_gms"
gen special = inlist(controls, "none", "linear", "all", "quad", "all_gms")

* Drop very extreme values in cross-sectional code, which are cases in which the model did not converge
drop if rK > 10

gen yaxis = 1 if cs 
replace yaxis = 0.75 if !cs

egen rK_max = max(rK), by(cs)
egen rK_min = min(rK), by(cs)

gen gms_estimate = 1.9 if _n==1
gen yaxis_gms_estimate = 1 if _n==1

* Make the max/min line go to the end of the dot
replace rK_max = rK_max + 0.07
replace rK_min = rK_min - 0.07

twoway 	(scatter yaxis rK if !special & cs, mcolor(gs4%5) msymbol(o) msize(huge) lcolor(black)) ///
		(scatter yaxis rK if !special & !cs, mcolor(gs4%1) msymbol(o) msize(huge) lcolor(black)) ///
		(rcap rK_max rK_min yaxis if cs, lcolor(black) lpattern(dash) horizontal) ///
		(rcap rK_max rK_min yaxis if !cs, lcolor(black) lpattern(solid) horizontal) ///
		(scatter yaxis rK if controls=="quad" & cs, mcolor("0 150 255") msymbol(O) msize(large) mlcolor(black)) ///
		(scatter yaxis rK if controls=="linear" & cs, mcolor("0 200 255") msymbol(O) msize(large) mlcolor(black)) ///
		(scatter yaxis rK if controls=="none" & cs, mcolor("0 255 255") msymbol(O) msize(large) mlcolor(black)) ///	
		(scatter yaxis rK if controls=="all" & cs, mcolor("0 0 255") msymbol(O) msize(large) mlcolor(black)) ///
		(scatter yaxis rK if controls=="quad" & !cs, mcolor("0 150 255") msymbol(O) msize(small) mlcolor(black)) ///
		(scatter yaxis rK if controls=="linear" & !cs, mcolor("0 200 255") msymbol(O) msize(small) mlcolor(black)) ///
		(scatter yaxis rK if controls=="none" & !cs, mcolor("0 255 255") msymbol(O) msize(small) mlcolor(black)) ///	
		(scatter yaxis rK if controls=="all" & !cs, mcolor("0 0 255") msymbol(O) msize(small) mlcolor(black) mlcolor(black)) ///
		(scatter yaxis_gms_estimate gms_estimate, msymbol(S) mcolor(black)  msize(medium)) ///
		(scatter yaxis_gms_estimate gms_estimate, msymbol(X) mcolor(gold)  msize(medium)) ///
		(scatter yaxis rK if controls=="all_gms" & cs, msymbol(S) mcolor(black)  msize(medium)) ///
		(scatter yaxis rK if controls=="all_gms" & cs, mcolor(red) msymbol(X) msize(medium)), ///
		legend(order(7 "No Controls" 6 "Linear" 5 "Quadratic" 8 "Fixed Effects") position(0) bplacement(seast) cols(1) size(*0.8)) ///
		yscale(range(0.6(0.1)1.2)) ///
		xtitle("Estimated r{sub:K}*") ytitle("") ///
		ylabel(0.5 " " 0.75 `""Quasi" "Experimental""' 1 `""Cross" " Sectional""' 1.25 " ") ////
		xlabel(0(1)7)  ///
		text(1.06 1.9 "Giglio, Maggiori & Stroebel (2015)" "Published Results", color(gold*1.5) size(vsmall)) ///
		text(.94 2.3 "Giglio, Maggiori & Stroebel (2015)" "Replication On Our Sample", color(cranberry*1.5) size(vsmall))
graph export "$fig/rK_stability.png", replace

*************************************
* Table: Natural Rate Estimates
*************************************

use "$data/experiments.dta", clear
gen all = 1 

foreach sample of varlist all k90 {
	preserve 
	keep if `sample'==1
	estimates clear

	// Baseline (no hedonics, hedonics sample, hedonics)
	nl (did = ln(1-exp(-({rK=3}/100)*(T+k))) - ln(1-exp(-({rK=3}/100)*T))), vce(robust)
	matrix b_nh = e(b)
	matrix V_nh = e(V)

	nl (did = ln(1-exp(-({rK=3}/100)*(T+k))) - ln(1-exp(-({rK=3}/100)*T))) if !missing(did_linear), vce(robust)
	matrix b_hs = e(b)
	matrix V_hs = e(V)

	nl (did_linear = ln(1-exp(-({rK=3}/100)*(T+k))) - ln(1-exp(-({rK=3}/100)*T))), vce(robust)
	matrix b_h = e(b)
	matrix V_h = e(V)

	matrix b = (b_nh, b_hs, b_h)
	matrix V = (V_nh,0,0 \ 0,V_hs,0 \ 0,0,V_h)

	matrix coleq b = " "
	matrix coleq V = " "

	matrix colnames b = "No Hedonics" "No Hedonics (Hedonics Sample)" "Hedonics"
	matrix colnames V = "No Hedonics" "No Hedonics, (Hedonics Sample)" "Hedonics"

	regress did T T T, nocons

	erepost b = b V = V, rename
	estimates store baseline

	* Flexible yield curve
	local rK_param "{rK} + {b1}*(T)"
	nl (did = ln(1-exp(-((`rK_param')/100)*(T+k))) - ///
			ln(1-exp(-((`rK_param')/100)*T))), ///
		initial(rK 0.1 b1 0.1) variables(did T) vce(robust)
		
	// For multiple points along the yield curve, calculate implied rK + standard error
	forv T=50(10)80 {
		// Store rK(T)
		local b`T'_nh = _b[/rK] + _b[/b1] * (`T')
		local v`T'_nh = e(V)[1,1] + 2*e(V)[1,2]*(`T') + e(V)[2,2]*(`T')^2
	}

	// Hedonics Sample
	nl (did = ln(1-exp(-((`rK_param')/100)*(T+k))) - ///
			ln(1-exp(-((`rK_param')/100)*T))) if !missing(did_linear), ///
		initial(rK 0.1 b1 0.1) variables(did T) vce(robust)
	forv T=50(10)80 {
		// Store rK(T)
		local b`T'_hs = _b[/rK] + _b[/b1] * (`T')
		local v`T'_hs = e(V)[1,1] + 2*e(V)[1,2]*(`T') + e(V)[2,2]*(`T')^2
	}

	// Hedonics
	nl (did_linear = 	ln(1-exp(-((`rK_param')/100)*(T+k))) - ///
				ln(1-exp(-((`rK_param')/100)*T))), ///
		initial(rK 0.1 b1 0.1) variables(did_linear T) vce(robust)
	forv T=50(10)80 {
		// Store rK(T)
		local b`T'_h = _b[/rK] + _b[/b1] * (`T')
		local v`T'_h = e(V)[1,1] + 2*e(V)[1,2]*(`T') + e(V)[2,2]*(`T')^2
		
		di `b`T'_h'
		di `v`T'_h'
	}

	// Store estimates
	forv T = 50(10)80 {
		di "`T'"
		di "`b`T'_nh'"
		di "`v`T'_nh'"
		di "`v`T'_hs'"
		di "`v`T'_h'"
		
		matrix b = (`b`T'_nh', `b`T'_hs', `b`T'_h')
		matrix V = (`v`T'_nh', 0, 0 \ 0, `v`T'_hs',	0 \ 0, 0, `v`T'_h')
		
		matrix list b 
		matrix list V

		matrix coleq b = " "
		matrix coleq V = " "

		matrix colnames b = "No Hedonics" "No Hedonics (Hedonics Sample)" "Hedonics"
		matrix colnames V = "No Hedonics" "No Hedonics, (Hedonics Sample)" "Hedonics"

		regress did T T T, nocons

		erepost b = b V = V, rename
		estimates store T`T'
	}

	// Add sample size
	count if !missing(did)
	local n = r(N)
	count if !missing(did_linear)
	local n_h = r(N)

	matrix b = (`n', `n_h', `n_h')
	matrix V = I(3)*0

	matrix coleq b = " "
	matrix coleq V = " "

	matrix colnames b = "No Hedonics" "No Hedonics (Hedonics Sample)" "Hedonics"
	matrix colnames V = "No Hedonics" "No Hedonics, (Hedonics Sample)" "Hedonics"

	regress did T T T, nocons
	erepost b=b V=V, rename
	estimates store N

	esttab * using "$tab/rK_`sample'.tex", ///
		varlabels(, blist("No Hedonics (Hedonics Sample)" "\hline " ///
								"Hedonics" "\hline ")) ///
		mgroups("Constant $\rstark$" "Flexible $\rstark$" "N", pattern(1 1 0 0 0 1) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) ///
			span erepeat(\cmidrule(lr){@span})) ///
		mtitle("" "$ T=50$" "$ T=60$" "$ T=70$" "$ T=80$" "") ///
		noobs se replace substitute("(.)" "" ".00") b(%12.2fc) se(2)
	restore
}

