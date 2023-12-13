from utils import *

def get_controls(row, purchase_controls=None, sale_controls=None, price_var='log_price', pduration_var='L_duration', sduration_var='whb_duration', restrict_quarter=False, restrict_month=False, restrictions=[0.1,0.5,1,5,10,20], margin=0.1, verbose=False):
	'''
	identify controls that are geographically close to a treated property, have a similar duration, and transacted at the same time 
	
	row : Series
		data for treated property
	purchase_controls : DataFrame
		data pool from which to pick purchase control properties 
	sale_controls : DataFrame 
		data pool from which to pick sale control properties 
	price_var : string
		outcome variable to report for controls
	pduration_var : string 
		purchase duration key 
	sduration_var : string 
		sale duration key 
	restrict_quarter : bool
		flag for whether to enforce that controls are purchased in the same quarter as the treated property
	restrictions : list (float)
		the radii within which to look for controls
	margin : float 
		the maximum difference between the treated and control duration 
	verbose : bool 
		flag for whether to print output 
	'''

	text = f'\n\n{row["property_id"]} with purchase duration {row["L_duration"]} and sale duration {row["duration"]}, held for {row["years_held"]}, purchased in {row["L_year"]} and sold in {row["year"]}.\n'
 
	postcode = row['postcode']
	lat_rad = row['lat_rad']
	lon_rad = row['lon_rad']
	outcode = row['outcode']

	output = []
	keys = ["property_id", "year", "L_year", "duration", "L_duration", "distance", price_var, "F1_extension"]

	# Remove *this* property from controls
	purchase_controls = purchase_controls[purchase_controls.property_id != row.property_id]
	sale_controls = sale_controls[sale_controls.property_id != row.property_id]

	# If not already sorted backwards,sort restrictions backwards
	restrictions.sort(reverse=True)
	purchase_controls["distance"] = purchase_controls.apply(lambda row: haversine(lat_rad, lon_rad, row["lat_rad"], row["lon_rad"]), axis=1)
	sale_controls["distance"] = sale_controls.apply(lambda row: haversine(lat_rad, lon_rad, row["lat_rad"], row["lon_rad"]), axis=1)

	#########################################################
	# Restrict data set to that relevant for this row
	#########################################################

	for i, restriction in enumerate(restrictions):
		text += str(restriction) + "\n"
		text += "-----------\n"

		purchase_controls = restrict_by_location(purchase_controls, restriction=restriction)
		sale_controls = restrict_by_location(sale_controls, restriction=restriction)

		purchase_data, sale_data, text = get_restricted_data(purchase_controls, sale_controls, row, margin=margin, pduration_var=pduration_var, sduration_var=sduration_var, restrict_quarter=restrict_quarter, restrict_month=restrict_month, text=text)

		for dataset in [purchase_data, sale_data]:
			if dataset[price_var].count() > 0:
				# Add index
				output.append(dataset[price_var].mean())
				# Add mean duration
				output.append(dataset['duration'].mean())
			else:
				output.append(None)
				output.append(None)


	text += "Output: " + str(output) + "\n"
	if verbose:
		print(text)
	return output

def apply_get_controls(inp, restrictions=[0.1,0.5,1,5,10,20], func=get_controls):
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
	new_cols = inp[3]
	price_var = inp[4]
	pduration_var = inp[5]
	sduration_var = inp[6]
	restrict_quarter = inp[7]
	restrict_month = inp[8]
	restrict_both_years = inp[9]
	margin = inp[10]

	df[new_cols] = df.progress_apply(lambda row: func(row, purchase_controls=purchase_controls, sale_controls=sale_controls, restrictions=restrictions, margin=margin, price_var=price_var, pduration_var=pduration_var, sduration_var=sduration_var, restrict_quarter=restrict_quarter, restrict_month=restrict_month), axis=1, result_type="expand")
	return df

def get_nearest_controls(df, restrictions=[0.1,0.5,1,5,10,20], tag="", verbose=False):
	'''
	for each property, identify the control for the closest radius
	
	df : DataFrame
		data set with treated properties and their controls
	restrictions : list (float)
		the radii within which to look for controls
	tag : string 
		tag to add to data labels 
	verbose : bool
		flag for whether to print output
	'''

	if verbose:
		print("All controls")
		print(df)

	# Create new columns with NaN values
	for col in ["L_index", "index", "radius", "miss", "duration_idx", "L_duration_idx"]:
		df[col] = pd.NA
	
	for n in restrictions:
		df["miss"] = df["index"].isna() | df["L_index"].isna()
		df.loc[df["miss"], "radius"] = n
		
		for col in ["index", "L_index", "duration_idx", "L_duration_idx"]:
			new_col = f"{col}_{n}_km"
			df.loc[df["miss"], col] = df[new_col]
				
	df["d_index"] = df["index"] - df["L_index"]
	
	#Rename the columns
	columns_to_rename = ["index", "L_index", "d_index", "radius", "duration_idx", "L_duration_idx"]
	for col in columns_to_rename:
		df.rename(columns={col: f"{col}{tag}"}, inplace=True)
	
	# Keep only specified columns
	columns_to_keep = ["property_id", "date_trans"] + [f"{col}{tag}" for col in columns_to_rename]
	df = df[columns_to_keep]


	if verbose:
		print("Nearest controls")
		print(df)

	return df

if __name__ == "__main__":

	print("Runnning...")

	input_folder = working_folder
	output_folder = os.path.join(working_folder, "controls")

	# Make output directory
	os.makedirs(output_folder, exist_ok=True)

	########################################################################
	file = os.path.join(input_folder, 'for_controls.csv')
	df = pd.read_csv(file)

	tags = ["_bedrooms","_all", "_linear"]
	price_vars=['log_price'] + [f'pres{tag}' for tag in tags]
	for i, tag in enumerate([""]+tags):
		print("Tag:",tag.replace("_", ""))
		print("----------------")
		extensions = wrapper(df, price_var=price_vars[i], func=apply_get_controls, restrict_quarter=False)

		# Get nearest controls for each extension 
		extensions = get_nearest_controls(extensions, tag=tag)

		# Save
		outfile=f"controls{tag}.csv"
		extensions.to_csv(os.path.join(output_folder, outfile), index=False)
		print(f"Saved to {outfile}:")

	# Control quarter 
	print('Control Quarter:')
	extensions = wrapper(df, price_var='log_price', func=apply_get_controls, restrict_quarter=True)
	extensions = get_nearest_controls(extensions, tag='_quarterly')

	outfile=f"controls_quarterly.csv"
	extensions.to_csv(os.path.join(output_folder, outfile), index=False)
	print(f"Saved to {outfile}:")

	########################################################################
