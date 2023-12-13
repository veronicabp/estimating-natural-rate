******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program cleans data on property listings from Zoopla.
******************************************************************

**************************
* Convert to DTA
**************************
global FOLDER "$raw/zoopla/safeguarded-release-zoopla-uk-listings-2013to2021-09062021"
cap mkdir "$working/zoopla"

local files: dir "$FOLDER" files "*.csv"
foreach file of local files {
	local dtafile = subinstr("`file'",".csv",".dta",.)
	di "`dtafile'"
	qui: import delimited "$FOLDER/`file'", clear bindquote(strict) maxquotedrows(10000)
	qui: save "$working/zoopla/`dtafile'", replace
}

**************************
* Combine everything
**************************
clear 
local files: dir "$working/zoopla" files "*.dta"
foreach file of local files {
	append using "$working/zoopla/`file'", force
}


**************************
* Clean 
**************************
// Drop duplicates 
gduplicates drop listing_id, force

// Clean date
replace last_marketed_date = substr(last_marketed_date, 1, 10)
gen date_zoopla = date(last_marketed_date, "YMD")

// For each listing, get measure of how long the listing was on the market for
replace first_marketed_date = substr(first_marketed_date, 1, 10)
gen date_zoopla0 = date(first_marketed_date, "YMD")

gen dash_pos = strpos(price_change, "|")
gen price_zoopla0 = substr(price_change, 1, dash_pos-1)
destring price_zoopla0, replace
replace price_zoopla0 = price if missing(price_zoopla0)
drop dash_pos

gen listing_time_zoopla = date_zoopla - date_zoopla0
gen price_change_zoopla = 100 * (price-price_zoopla0)/price_zoopla0

// Make property id
rename property_id property_id_n
replace property_number = subinstr(property_number,".","",.)
replace property_number = subinstr(property_number,",","",.)
replace property_number = subinstr(property_number,"'","",.)
replace property_number = subinstr(property_number,"(","",.)
replace property_number = subinstr(property_number,")","",.)
replace property_number = subinstr(property_number,"*","",.)
replace property_number = subinstr(property_number,`"""',"",.)
replace property_number = subinstr(property_number,"FLAT","",.)
replace property_number = subinstr(property_number,"APARTMENT","",.)
replace property_number = strtrim(stritrim(upper(property_number)))

egen property_id = concat(property_number outcode incode), punct(" ")
rename property_id property_id_zoop

egen postcode = concat(outcode incode), punct(" ")

// Keep only relevant variables 
keep property_id_zoop date_zoopla listing_time_zoopla price_change_zoopla property_type agent_name listing_status postcode property_number num_bedrooms num_bathrooms num_floors num_recepts category price
drop if missing(property_id_zoop)
drop if missing(postcode)

rename num_bedrooms bedrooms_zoop
rename num_bathrooms bathrooms_zoop
rename num_floors floors
rename num_recepts receptions
rename price price_zoopla

preserve
	keep if listing_status=="rent"
	save "$working/zoopla_rent.dta", replace 
restore

preserve
	keep if listing_status=="sale"
	save "$working/zoopla_sales.dta", replace 
restore

// Make merge keys
keep property_id_zoop postcode property_number 
rename property_id_zoop property_id
duplicates drop 
save "$working/zoopla_for_merge.dta", replace
