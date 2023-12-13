******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program cleans data on registered leases in the HMLR
* Lease data set.
******************************************************************

import delimited "$working/extracted_terms_open.csv", clear

rename uniqueidentifier unique_id 
rename term lease_details
rename osuprn uprn
rename associatedpropertydescription description
rename associatedpropertydescriptionid id
keep id lease_details description regorder uprn alienationclauseindicator county region number_years date_from date_registered date_to

* Convert to date type
gen date_to_d = date(date_to, "MDY")
gen date_from_d = date(date_from, "MDY")
gen date_registered_d = date(date_registered, "DMY")

drop date_to date_from date_registered
rename date*_d date*
format date*  %tdDD-NN-CCYY

* Drop missing 
drop if missing(lease_details)

* If missing lease start date, we can use lease end date to infer duration
replace date_from = date_to - number_years*365 if missing(date_from) & !missing(date_to) & !missing(number_years) & round(year(date_to) - number_years,10)==round(year(date_registered),10)

replace number_years = datediff(date_registered, date_to, "year") if missing(number_years) & missing(date_from) & !missing(date_to)
replace date_from = date_registered if missing(date_from) & !missing(date_to) 

drop if missing(date_from) | missing(number_years) | number_years < 0

**********************
* make merge key
**********************

gen merge_key = upper(description)

*remove commas/periods
replace merge_key = subinstr(merge_key,".","",.)
replace merge_key = subinstr(merge_key,",","",.)
replace merge_key = subinstr(merge_key,"'","",.)
replace merge_key = subinstr(merge_key,"(","",.)
replace merge_key = subinstr(merge_key,")","",.)
replace merge_key = subinstr(merge_key,"FLAT","",.)
replace merge_key = subinstr(merge_key,"APARTMENT","",.)
replace merge_key = strtrim(stritrim(merge_key))

*drop missing entries
drop if missing(merge_key)

***********************
* deal with duplicates
***********************
* drop in terms of all variables
keep id description merge_key date_registered number_years date_from alienationclauseindicator lease_details county region uprn
gduplicates drop merge_key number_years date_from, force

* If duplicates refer to a very long lease, only keep one of them 
gen duration2023 = number_years - datediff(date_from, date("January 1, 2023", "MDY"), "year")
gegen min_duration2023 = min(duration2023), by(merge_key)
drop if min_duration2023 > 300 & duration2023!=min_duration2023

* If duplicates refer to a very similar lease, keep one. If not, drop them.
gegen mean_duration2023 = mean(duration2023), by(merge_key)
gegen sd_duration2023 = sd(duration2023), by(merge_key)
drop if sd_duration2023 > 10 & sd_duration2023 != .
gduplicates drop merge_key, force

*******************************
* Some more cleaning
*******************************
// Extract postcode
gen postcode = regexs(0) if regexm(merge_key, "[A-Z][A-Z]?[0-9][0-9]?[A-Z]? [0-9][A-Z][A-Z]")
drop if missing(postcode)

gen merge_key_1 = merge_key 
gen merge_key_2 = merge_key 

save "$working/lease_data.dta", replace

* for merge:
keep merge_key* uprn postcode
gen address = strtrim(subinstr(merge_key, postcode, "", .))
export delimited "$working/lease_data_for_merge.csv", replace
