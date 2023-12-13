* Calculate Interest Rate Forwards
do InterestRates

* Clean Transaction Data
do PricePaid 

* Clean Lease Data
python: exec(open('ExtractLeaseTerms.py').read())
do RegisteredLeases

* Clean Hedonics 
do CleanRightmove
do CleanZoopla

* Merge Data
python: exec(open('MergeHMLR.py').read())
do MergeHMLR
python: exec(open('MergeHMLRHedonics.py').read())

* Finalize 
do FinalizeData
python: exec(open('GetControls.py').read())
python: exec(open('GetControlProperties.py').read())
do HazardRate
do FinalizeExperiments
do EnglishHousingSurvey
do AdditionalDatasets
