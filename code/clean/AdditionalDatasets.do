******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program creates additional datasets for analysis. 
* Specifically, it:
* 		> Reshapes experiment data for the event study
*		> Estimates the natural rate using all variations of 
*			controls 
*		> Estimates a yearly, quarterly, and monthly natural rate
*			time series
*		> Calculates the long-run housing risk premium using a VAR
******************************************************************


*************************************
* Reshape for Event Study
*************************************

cap mkdir "$clean/event_study"
foreach sample in "" "linear" {
	use "$clean/experiments.dta", clear
	
	if "`sample'" == "" {
		global price_var log_price
		global index_var index
	}
	else {
		global price_var pres_`sample'
		global index_var index_`sample'
	}
	
	cap gen all = 1 	
	foreach var of varlist all k90 {
			cap gen y2003t2010_`var' = year>2003 & year<=2010 & `var'
			cap gen y2010t2018_`var' = year>2010 & year<=2018  & `var'
			cap gen post2018_`var' = year>2018 & `var'
				
			cap gen T40t60_`var' = T>40 & T<=60  & `var'
			cap gen T60t80_`var' = T>60 & T<=80  & `var'
			cap gen T80p_`var' = T>80 & `var'
	}

	cap gen k200u_m90 = k200 & !k90	
	foreach var of varlist all k90 k700p k90u k200u_m90 y2003t2010* y2010t2018* post2018* T40t60* T60t80* T80p* {
		preserve
			keep if `var'
			local tag "`sample'`var'"
			
			gen extension0 = L_$price_var
			gen extension1 = $price_var

			gen control0 = L_$index_var
			gen control1 = $index_var

			gen time0 = datediff(date_extended, L_date_trans, "year") - 0.5
			gen time1 = datediff(date_extended, date_trans, "year") + 0.5

			keep property_id date_trans years_held extension? control? time?
			reshape long extension control time, i(property_id date_trans) j(period)

			gen diff = extension-control 
			gen extension_res = extension - (extension + control)/2
			gen control_res = control - (extension + control)/2

			drop if missing(diff)

			collapse diff (semean) se=diff, by(time)

			gen ub = diff + 1.96*se
			gen lb = diff - 1.96*se
			
			save "$clean/event_study/`tag'.dta", replace
		restore
		
	}
}

*************************************
* Extensions + Controls
*************************************

use "$clean/leasehold_flats.dta", clear
keep if duration <= 200 | extension
local vars 	duration L_duration log_price* L_log_price* d_log_price* pres* d_pres* L_pres* ///
			bedrooms bathrooms livingrooms floorarea age log_rent date_rm date_rent date_hedonics ///
			L_bedrooms L_bathrooms L_livingrooms L_floorarea L_log_rent L_date_rm L_date_rent L_date_hedonics
			
keep property_id date_trans L_date_trans `vars'
rename property_id purchase_controls_pid 
rename date_trans purchase_controls_date
rename L_date_trans purchase_controls_L_date

foreach var of varlist `vars' {
	rename `var' `var'_pctr
}

save "$working/purchase_controls.dta", replace
rename purchase_* sale_* 
rename *_pctr *_sctr
save "$working/sale_controls.dta", replace

import delimited "$working/controls/control_properties.csv", clear varnames(1)

foreach var of varlist date_trans purchase_controls_date sale_controls_date {
	rename `var' `var'_s
	gen `var' = date(`var', "MDY")
	drop `var'_s
}
format date* %tdDD-NN-CCYY

merge m:1 property_id date_trans using "$clean/leasehold_flats.dta", keep(match) nogen
keep property_id date_trans L_date_trans year L_year date_from date_registered number_years years_held duration L_duration ///
		sale_controls* purchase_controls* region area district postcode lpa_code `vars'
merge m:1 sale_controls_pid sale_controls_date using "$working/sale_controls.dta", keep(master match) nogen
merge m:1 purchase_controls_pid purchase_controls_date using "$working/purchase_controls.dta", keep(master match) nogen

gsort property_id date_trans
by property_id date_trans: egen log_price_ctrl = mean(log_price_sctr)
by property_id date_trans: egen L_log_price_ctrl = mean(log_price_pctr)
gen did = (log_price - L_log_price) - (log_price_ctrl - L_log_price_ctrl)
gen diffs = log_price - log_price_ctrl
gen diffp = L_log_price - L_log_price_ctrl

foreach control in "linear" "all" "quad" "all_gms" {
	qui: gegen pres_`control'_ctrl = mean(pres_`control'_sctr), by(property_id date_trans)
	qui: gegen L_pres_`control'_ctrl = mean(pres_`control'_pctr), by(property_id date_trans)
	
	qui gen did_`control' = (pres_`control' - L_pres_`control') - (pres_`control'_ctrl - L_pres_`control'_ctrl)
	
	qui gen diffs_`control' = pres_`control' - pres_`control'_ctrl
	qui gen diffp_`control' = L_pres_`control' - L_pres_`control'_ctrl
}

foreach var of varlist pres? pres?? pres??? {
	local control = subinstr("`var'","pres","",.)
	
	di "`control'"
	qui gegen `var'_ctrl = mean(`var'_sctr), by(property_id date_trans)
	qui gegen L_`var'_ctrl = mean(`var'_pctr), by(property_id date_trans)
	
	qui gen did_`control' = (`var' - L_`var') - (`var'_ctrl - L_`var'_ctrl)
	
	qui gen diffs_`control' = `var' - `var'_ctrl
	qui gen diffp_`control' = L_`var' - L_`var'_ctrl
}

save "$clean/extensions_and_controls.dta", replace

*************************************
* Estimate Stability
*************************************

use "$clean/extensions_and_controls.dta", clear

gegen tag=tag(property_id)
keep if tag==1
keep if year>=2003

cap drop _merge
merge 1:1 date_trans property_id using "$clean/leasehold_flats.dta", nogen keep(match)

gen T = whb_duration
gen k = extension_amount

gen rK = .
gen controls = ""

local count = 1
foreach var of varlist did* {
	qui nl (`var' = ln(1-exp(-({rK=3}/100)*(T+k))) - ln(1-exp(-({rK=3}/100)*T)))
		
	local tag = subinstr("`var'", "did_", "", .)
	if "`var'"=="did" local tag = "none"
	
	replace rK = _b[/rK] if _n==`count'
	replace controls = "`tag'" if _n==`count'
	
	local count = `count'+1
}

keep rK controls 
drop if missing(rK)
save "$clean/quasi_experimental_stability.dta", replace

********************************************
* Cross-Sectional Stability
********************************************

use "$clean/flats.dta", clear
keep if year>=2003

// For each group, get the mean freehold price
gegen g=group(outcode year quarter)
gegen pct_fh = mean(freehold), by(g)
drop if pct_fh==0 | pct_fh==1

foreach var of varlist log_price pres* {
	qui: gen `var'_fh = `var' if freehold
	qui: gegen `var'_fh = mean(`var'_fh), by(g) replace
	qui: gen `var'_discount = `var' - `var'_fh if leasehold
}	

* Calculate rate of return for all variations of hedonics
gen rK = .
gen controls = ""

local count = 1
foreach var of varlist pres*discount log_price_discount  {
	di "`var'"
	qui: sum `var'
	if r(N)==0 continue
	qui: nl ( `var' = ln(1-exp(-({rK}/100) * duration)) ), initial(rK 4) variables(`var' duration) vce(robust)
		
		local tag = subinstr("`var'", "pres_", "", .)
		local tag = subinstr("`tag'", "_discount", "", .)
		if "`var'"=="log_price_discount" local tag = "none"
		
		qui: replace rK = _b[/rK] if _n==`count'
		qui: replace controls = "`tag'" if _n==`count'
		local count = `count'+1
}

keep rK controls 
drop if missing(rK)
save "$clean/cross_sectional_stability.dta", replace


********************************************
* r_K time series
********************************************
use "$clean/experiments.dta", clear
foreach freq in "yearly" "quarterly" "monthly" {
	foreach tag in "" "_q" {
		gen rK_`freq'`tag' = .
		gen ub_`freq'`tag' = .
		gen lb_`freq'`tag' = .
	}
}

gen xaxis12 = $year0*12 + _n - 1 if $year0*12 + _n <= $year1 * 12 + $month1
gen xaxis = (xaxis12)/12
gen q = mod(int((_n-1)/3), 4) + 1

forv year=$year0 / $year1 {
	di `year'

	qui: nl $nlfunc if year==`year', initial(rK 3) variables(did T k) vce(robust)
	qui: replace rK_yearly = _b[/rK] if int(xaxis)==`year'
	qui: replace ub_yearly = _b[/rK] + 1.96*_se[/rK] if int(xaxis)==`year'
	qui: replace lb_yearly = _b[/rK] - 1.96*_se[/rK] if int(xaxis)==`year' 
	
	forv quarter = 1/4 {
		
		qui: sum did if year==`year' & quarter==`quarter'
		if r(N)<=50 continue
		
		qui: nl $nlfunc if year==`year' & quarter==`quarter', initial(rK 3) variables(did T k) vce(robust)
		qui: replace rK_quarterly = _b[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		qui: replace ub_quarterly = _b[/rK] + 1.96*_se[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		qui: replace lb_quarterly = _b[/rK] - 1.96*_se[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		
		// Use quarterly controls to test seasonality
		qui: nl (did_quarterly = ln(1-exp(- ({rK}/100) * (T+k))) - ln(1-exp(-({rK}/100) * T))) if year==`year' & quarter==`quarter', ///
				initial(rK 3) variables(did T k) vce(robust)
		qui: replace rK_quarterly_q = _b[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		qui: replace ub_quarterly_q = _b[/rK] + 1.96*_se[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		qui: replace lb_quarterly_q = _b[/rK] - 1.96*_se[/rK] if int(xaxis)==`year' & q==`quarter' & abs(_b[/rK]) < 10
		
		forv month = 1/3 {
			local month = (`quarter'-1)*3 + `month'
			di " `month'"
			
			local date = `year'*12 + `month' - 1
			
			qui: sum did if year==`year' & month==`month'
			if r(N)<=50 {
// 				di "Insufficient obs."
				continue
			}
			
			qui: nl $nlfunc if year==`year' & month==`month', initial(rK 3) variables(did T k)
			qui: replace rK_monthly = _b[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			qui: replace ub_monthly = _b[/rK] + 1.96*_se[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			qui: replace lb_monthly = _b[/rK] - 1.96*_se[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			
			qui: nl (did_quarterly = ln(1-exp(- ({rK}/100) * (T+k))) - ln(1-exp(-({rK}/100) * T))) if year==`year' & month==`month', ///
					initial(rK 3) variables(did T k) vce(robust)
			qui: replace rK_monthly_q = _b[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			qui: replace ub_monthly_q = _b[/rK] + 1.96*_se[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			qui: replace lb_monthly_q = _b[/rK] - 1.96*_se[/rK] if xaxis12==`date' & abs(_b[/rK]) < 10
			
		}
	}
}

keep xaxis12 xaxis q rK* ub* lb*
drop if xaxis==.

gen year = int(xaxis)
gen month = round((xaxis-year)*12) + 1
rename q quarter

foreach freq in "year" "quarter" "month" {
	preserve
		keep rK_`freq'ly ?b_`freq'ly year quarter month xaxis12
		rename *_`freq'ly * 
		duplicates drop rK year, force
		
		gen var = ((ub-rK)/1.96)^2
		
		if "`freq'" == "month" {
			merge 1:1 year month using "$clean/uk_interest_rates.dta", nogen
		}
		
		save "$clean/rK_`freq'ly.dta", replace
	restore
}

preserve
	local freq quarter
	keep rK_`freq'ly_q ?b_`freq'ly_q year quarter month xaxis12
	
	rename *_q * 
	rename *_`freq'ly * 
	
	duplicates drop rK year, force
	gen var`freq' = ((ub-rK)/1.96)^2
	
	save "$clean/rK_nonseasonal.dta", replace
restore


*************************************
* Calculate housing risk premium
*************************************
import delimited "$raw/fred/UKNGDP.csv", clear 
rename (date ukngdp) (d gdp) 
gen date = date(d, "YMD")
gen year = year(date)
gen quarter = quarter(date)

tempfile gdp
save `gdp'

import delimited "$raw/oecd/house_prices.csv", clear 
keep if location=="GBR" & frequency=="Q"

gen date = dofq(quarterly(time, "YQ"))
gen year = year(date)
gen quarter = quarter(date)
keep if date <= 22919

keep value year quarter date subject 
reshape wide value, i(year quarter date) j(subject) string 
rename (valueNOMINAL valueRENT) (price_index rent_index)
keep year quarter date price_index rent_index

* Use 2022 levels to back out all previous levels of price/rent
scalar price2022Q4 = 295000
scalar rent2022Q4 = 209 * 52

gsort -date
foreach var in price rent {
	gen `var' = `var'2022Q4 if _n==1
	replace `var' = `var'[_n-1] * `var'_index[_n]/`var'_index[_n-1] if _n>1
}

gen rent_price = rent/price

merge 1:1 year quarter using `gdp', keep(match) nogen

tempfile temp
save `temp'

use "$clean/uk_interest_rates.dta", clear 
gen quarter = quarter(date)
collapse uk10y15 uk10y, by(year quarter)

merge 1:1 year quarter using `temp', keep(match) nogen
format date %tdNN-CCYY

cap drop d
gen d = qofd(date)
tsset d

* Define variables
sort year
gen g = (rent - rent[_n-1])/rent[_n-1]
gen r = uk10y15/100
gen d_gdp = (gdp-gdp[_n-1])/gdp[_n-1]

var g rent_price d_gdp

// Compute 30y ahead forecast for every year
local T = 30*4
forv y=160/251 {
	fcast compute f`y'_, step(`T') dynamic(`y')
}

// For each, compute mean balanced growth 
gen g_balanced = .
gen rtp_balanced = .
forv y=160/251 {
	sum f`y'_g
	replace g_balanced = r(mean) if d==`y'
	
	sum f`y'_rent_price
	replace rtp_balanced = r(mean) if d==`y'
}

gen risk_premium = 100 * (rtp_balanced + g_balanced - r)
replace g_balanced = 100 * g_balanced

keep risk_premium g_balanced year quarter 
drop if missing(risk_premium)
save "$clean/risk_premium.dta", replace
