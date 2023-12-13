******************************************************************
* Code for: "Measuring the Natural Rate With Natural Experiments"
* Backer-Peral, Hazell, Mian (2023)
* 
* This program cleans data on property listings from Rightmove.
******************************************************************

global FOLDER "$raw/rightmove"
cap mkdir "$working/rightmove"

// Merge all files

foreach subfolder in "" "UK 2012-2016 Sale and Rental" "UK 2017 - 2022 Rental" "UK 2017 - 2022 Sale" {
	di "`subfolder'"
	local files: dir "$FOLDER/`subfolder'" files "*.csv"
	foreach file of local files {
		di "`file'"
		
		if "`file'" == "area_upload.csv"  continue 
		
		local dtafile = subinstr("`file'",".csv",".dta",.)
		
		// Check if file already exists
		cap confirm file "$working/rightmove/`subfolder'-`dtafile'"
		if _rc == 0 continue
		
		qui: import delimited "$FOLDER/`subfolder'/`file'", clear bindquote(strict) maxquotedrows(10000)		
	if c(k)!=0 & _N!=0{
		// Make format consisting
		qui: gen a_=.
		foreach var of varlist *_* {
			local new_name = subinstr("`var'", "_", "", .)
			rename `var' `new_name' 
		}
		
		// For pre-2012 properties, we need to reformat the date_hmlr
		qui: replace firstlistingdate = substr(firstlistingdate, 1, 10) if areaname=="UK"
		
		*If there are multiple entries per listing, for each listing, we just want the first and last listing dates and their prices
		capture confirm variable changedate
		if !_rc {
			// Convert dates to numeric
			qui: gen datelist = date(changedate, "YMD")
			
			gsort listingid datelist
			qui: gegen datelist0 = first(datelist), by(listingid)
			gsort listingid -datelist
			qui: gegen datelist1 = first(datelist), by(listingid)
			
			qui: gen listprice0 = listingprice if datelist==datelist0
			qui: gen listprice1 = listingprice if datelist==datelist1
			qui: gegen listprice0=mean(listprice0), by(listingid) replace
			qui: gegen listprice1=mean(listprice1), by(listingid) replace
			
			cap gduplicates drop listingid, force
		}
		else {
			qui: gen datelist0 = ""
			qui: gen datelist1 = ""
			qui: gen listprice0 = ""
			qui: gen listprice1 = ""
		}
		qui: ds uprn, not
		qui: tostring `r(varlist)', replace force
		qui: destring uprn, replace force
		
		qui: save "$working/rightmove/`subfolder'-`dtafile'", replace
	}
	}
}

* Combine everything
clear 
local files: dir "$working/rightmove" files "*.dta"
foreach file of local files {
	di "`file'"
	append using "$working/rightmove/`file'"
}

egen property_id = concat(address1 postcode), punct(" ")
replace property_id = subinstr(property_id, ".", " ", .)
replace property_id = subinstr(property_id, ",", " ", .)
replace property_id = subinstr(property_id, "'", " ", .)
replace property_id = subinstr(property_id, "#", " ", .)
replace property_id = subinstr(property_id, `"""', " ", .)
replace property_id = subinstr(property_id," - ","-", .)
replace property_id = upper(strtrim(stritrim(property_id)))

save "$working/rightmove_merged_raw.dta", replace
export delimited "$working/rightmove_merged_raw.csv", replace

preserve
	keep if propertytype=="Flat / Apartment"
	keep property_id postcode uprn address1 address2 address3
	gduplicates drop
	export delimited "$working/rightmove_keys_flats.csv", replace
restore

// For now, let's work with sales of flats 
use "$working/rightmove_merged_raw.dta", clear
drop if missing(postcode)
drop if missing(address1)

gen list_date_1st = date(firstlistingdate, "YMD")
gen archive_date = date(archivedate, "YMD")
gen date_hmlr = date(hmlrdate, "YMD")

foreach var of varlist listingid chimneyid bedrooms listingprice floorarea bathrooms livingrooms yearbuilt hmlrprice datelist datelist0 datelist1 listprice0 listprice1 letrentfrequency {
	di "`var'"
	gen `var'_n = real(`var')
	drop `var'
	rename `var'_n `var'
}

gen date_rm = datelist1
replace date_rm = archive_date if missing(date_rm)
replace date_rm = list_date_1st if missing(date_rm)
replace date_rm = date_hmlr if missing(date_rm)

rename postcode postcode_rm
rename property_id property_id_rm

// Annualize rental prices 
gen annualized_listingprice = listingprice * letrentfrequency if transtype=="Rent" & !missing(letrentfrequency)
// If missing frequency, assume it is monthly
replace annualized_listingprice = listingprice * 12 if transtype=="Rent" & missing(letrentfrequency)
replace listingprice = annualized_listingprice if transtype=="Rent"

// Keep only relevant variables
keep transtype listingid latitude longitude propertytype listingprice bedrooms newbuildflag retirementflag sharedownershipflag auctionflag furnishedflag postcode floorarea bathrooms livingrooms yearbuilt parking currentenergyrating hmlrprice heatingtype condition list_date_1st date_hmlr property_id archive_date address* uprn datelist? listprice? date_rm

// Drop if address information is missing
drop if postcode==property_id
gduplicates drop property_id date_rm, force

preserve
	keep if transtype=="Sale"
	save "$working/rightmove_sales.dta", replace
	
	keep if propertytype=="Flat / Apartment" | propertytype=="Flat"
	save "$working/rightmove_sales_flats.dta", replace
restore


preserve
	keep if transtype!="Sale"
	save "$working/rightmove_rents.dta", replace
	
	keep if propertytype=="Flat / Apartment" | propertytype=="Flat"
	save "$working/rightmove_rents_flats.dta", replace
restore

// Save merge keys
preserve
	keep property_id_rm propertytype postcode uprn address1
	gduplicates drop
	rename postcode_rm postcode
	rename property_id_rm property_id
	save "$working/rightmove_for_merge.dta", replace
	
	keep if propertytype=="Flat / Apartment" | propertytype=="Flat"
	gduplicates drop
	save "$working/rightmove_for_merge_flats.dta", replace
restore
