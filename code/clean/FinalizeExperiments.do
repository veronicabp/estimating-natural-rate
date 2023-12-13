*


****************************************
* Clean indices
****************************************
local tags "" "_bedrooms" "_linear" "_all" "_quarterly" "_window45" "_ec"
foreach tag in "`tags'" {
	
	if "`tag'"=="" | "`tag'"=="_window45" | "`tag'"=="_old" | "`tag'"=="_ec" local pattern "YMD"
	else local pattern "MDY"
	
	import delimited "$working/controls/controls`tag'.csv", clear varnames(1) case(preserve)
	rename date_trans date_trans_s 
	gen date_trans = date(date_trans_s, "`pattern'")
	drop date_trans_s
	save "$working/controls/clean`tag'.dta", replace
}

use  "$clean/leasehold_flats.dta", clear
keep if extension
drop *index*

foreach tag in "`tags'" {
	merge m:1 property_id date_trans using "$working/controls/clean`tag'.dta", nogen keep(master matched)
}

// Set would-have-been duration
gen T = whb_duration
gen T_at_ext = L_duration - datediff(L_date_trans, date_extended, "year")
gen T5 = round(T,5)
gen T10 = round(T,10)

gen k = extension_amount
gen k90 = round(extension_amount, 5)==90
gen k700p = extension_amount>700
gen k90u = extension_amount>30 & extension_amount<90 & !k90
gen k200u = extension_amount < 200

gen year2 = int(year/2)*2
gen year5 = int(year/5)*5
	
// Diff in diff
foreach tag in  "`tags'" {
	if inlist("`tag'", "", "_quarterly", "_window45", "_old", "_ec") {
		gen did`tag' = d_log_price - d_index`tag'
		gen diffs`tag' = log_price - index`tag'
		gen diffp`tag' = L_log_price - L_index`tag'
	}
	else {
		gen did`tag' = d_pres`tag' - d_index`tag'
		gen diffs`tag' = pres`tag' - index`tag'
		gen diffp`tag' = L_pres`tag' - L_index`tag'
	}
}

* Merge in hazard rate
replace whb_duration = round(whb_duration)
merge m:1 whb_duration using "$clean/hazard_rate.dta", nogen keep(match master)

gen Pi = cum_prob / 100
replace Pi = 0 if Pi == .
drop cum_prob

* Drop extreme outliers
winsor did, p(0.005) gen(did_win)
keep if did==did_win
drop did_win

* Drop properties at the very low end of the yield curve
keep if T>30

* Drop properties that were extended within a month of purchase since we don't know if these were extended before or after the transaction
drop if datediff(L_date_trans, date_extended, "month") <= 0

save "$clean/experiments_incflippers.dta", replace

* Drop flippers
drop if years_held <= 1

save "$clean/experiments.dta", replace
