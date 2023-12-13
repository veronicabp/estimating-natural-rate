from utils import *


def get_control_properties(row, purchase_controls=None, sale_controls=None, pduration_var='L_duration', sduration_var='whb_duration', restrictions=[0.1, 0.5, 1,5,10,20], margin=0.1, verbose=False):
	'''
	identify control properties that are geographically close to a treated property, have a similar duration, and transacted at the same time 
	
	row : Series
		data for treated property
	purchase_controls : DataFrame
		data pool from which to pick purchase control properties 
	sale_controls : DataFrame 
		data pool from which to pick sale control properties 
	pduration_var : string 
		purchase duration key 
	sduration_var : string 
		sale duration key 
	restrictions : list (float)
		the radii within which to look for controls
	margin : float 
		the maximum difference between the treated and control duration 
	verbose : bool 
		flag for whether to print output 
	'''

	if verbose:
		print(f'\n\n{row["property_id"]} with purchase duration {row["L_duration"]} and sale duration {row["duration"]}, held for {row["years_held"]}, purchased in {row["L_year"]} and sold in {row["year"]}.')
	
	postcode = row['postcode']
	lat_rad = row['lat_rad']
	lon_rad = row['lon_rad']

	purchase_matches = []
	sale_matches = []
	keys = ["property_id", "year", "L_year", "duration", "L_duration", "distance"]

	# Remove *this* property from controls
	purchase_controls = purchase_controls[purchase_controls.property_id != row.property_id]
	sale_controls = sale_controls[sale_controls.property_id != row.property_id]

	# If not already sorted backwards,sort restrictions backwards
	restrictions.sort()
	purchase_controls["distance"] = purchase_controls.apply(lambda row: haversine(lat_rad, lon_rad, row["lat_rad"], row["lon_rad"]), axis=1)
	sale_controls["distance"] = sale_controls.apply(lambda row: haversine(lat_rad, lon_rad, row["lat_rad"], row["lon_rad"]), axis=1)
	#########################################################
	# Restrict data set to smallest non-empty one
	#########################################################
	found_controls = False
	for i, restriction in enumerate(restrictions):

		if verbose:
			print(restriction)
			print("-----------")

		purchase_controls_restricted = restrict_by_location(purchase_controls, restriction=restriction)
		sale_controls_restricted = restrict_by_location(sale_controls, restriction=restriction)
		purchase_data, sale_data, text = get_restricted_data(purchase_controls_restricted, sale_controls_restricted, row, margin=margin, pduration_var=pduration_var, sduration_var=sduration_var)

		if not found_controls and purchase_data.property_id.count() > 0 and sale_data.property_id.count() > 0:
			pids = list(purchase_data.property_id)
			dates = list(purchase_data.date_trans)
			new_matches = [(pids[i],dates[i]) for i in range(len(pids))]
			purchase_matches.extend(new_matches)

			pids = list(sale_data.property_id)
			dates = list(sale_data.date_trans)
			new_matches = [(pids[i],dates[i]) for i in range(len(pids))]
			sale_matches.extend(new_matches)
			found_controls = True 

			break

	if verbose:
		print("Purchase matches:",purchase_matches)
		print("Sale matches:", sale_matches)
	return purchase_matches, sale_matches

def apply_get_control_properties(inp, restrictions=[0.1, 0.5, 1,5,10,20], func=get_control_properties):
	'''
	wrapper for function to get control properties
	
	inp : list
		input parameters
	restrictions : list (float)
		the radii within which to look for controls
	func : func 
		function to apply
	'''

	df = inp[0]
	sale_controls = inp[1]
	purchase_controls = inp[2]
	margin = inp[9]

	matches_list = []
	for i, row in tqdm(df.iterrows()):
		purchase_matches, sale_matches = func(row, purchase_controls=purchase_controls, sale_controls=sale_controls, restrictions=restrictions, margin=margin)
		new_matches = pd.DataFrame({
			'property_id':[row.property_id for _ in range(len(purchase_matches + sale_matches))],
			'date_trans':[row.date_trans for _ in range(len(purchase_matches + sale_matches))],
			'purchase_controls_pid': [item[0] for item in purchase_matches] + ["" for _ in range(len(sale_matches))],
			'purchase_controls_date': [item[1] for item in purchase_matches] + ["" for _ in range(len(sale_matches))],
			'sale_controls_pid': ["" for _ in range(len(purchase_matches))] + [item[0] for item in sale_matches],
			'sale_controls_date': ["" for _ in range(len(purchase_matches))] + [item[1] for item in sale_matches]
			})
		matches_list.append(new_matches)
	matches = pd.concat(matches_list)
	return matches

if __name__ == "__main__":

	print("Runnning...")

	input_folder = working_folder
	output_folder = os.path.join(working_folder, "controls")

	########################################################################
	file = os.path.join(input_folder, 'for_controls.csv')
	df = pd.read_csv(file)
	extensions_and_controls = wrapper(df, func=apply_get_control_properties, parallelize=True, restrict_quarter=False)

	# Save
	outfile=f"control_properties.csv"
	extensions_and_controls.to_csv(os.path.join(output_folder, outfile), index=False)
	print(f"Saved to {outfile}:")
	########################################################################
