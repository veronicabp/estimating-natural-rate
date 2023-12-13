import os 
import pandas as pd
from tqdm import tqdm
import numpy as np
from multiprocessing import Pool
from math import ceil
pd.options.mode.chained_assignment = None
tqdm.pandas()

import warnings
warnings.simplefilter(action='ignore', category=UserWarning)


##################################################################
# Set Paths
##################################################################
origin_folder = "/Users/veronicabackerperal/Dropbox (Princeton)/Research/natural-rate"
folder = os.path.join(origin_folder, 'natural-rate-replication')
data_folder = os.path.join(folder, 'data')
working_folder =  os.path.join(data_folder, "working")
raw_folder =  os.path.join(data_folder, "raw")
clean_folder =  os.path.join(data_folder, "clean")

##################################################################
# Functions
##################################################################
def split_into_chunks(grouped_data, threshold_size):
	'''
	split data set into smaller chunks of data

	grouped_data : dictionary
		data set separated by categories 
	threshold_size : int 
		maximum number of rows per data chunk
	'''
	chunks = []
	for key, group in grouped_data.items():
		if len(group) > threshold_size:
			n_chunks = ceil(len(group) / threshold_size)
			for chunk in np.array_split(group, n_chunks):
				chunks.append((key, chunk))
		else:
			chunks.append((key, group))
	return chunks

def haversine(lat1, lon1, lat2, lon2):
	'''
	calculate the Haversine distance between two points on the earth in kilometers.

	lat1 : float 
		first latitude coordinate 
	lon1 : float 
		first longitude coordinate
	lat2 : float 
		second latitude coordinate 
	lon2 : float 
		second longitude coordinate
	'''
	dlat = lat2 - lat1
	dlon = lon2 - lon1
	a = np.sin(dlat/2.0)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2.0)**2
	c = 2 * np.arcsin(np.sqrt(a))
	r = 6371  # Radius of earth in kilometers
	return c * r

def restrict_by_duration(data, duration=None, margin=0.1):
	'''
	get subset of a data set that is within a certain margin of a specific lease duration 

	data : DataFrame
		data to restrict 
	margin : float
		maximum acceptable difference between duration (as a share)
	duration : float
		duration to match
	'''
	return data.loc[abs(data["duration"]-duration)<= margin*duration]

def restrict_by_location(data, restriction=1):
	'''
	get subset of a data set that is within a certain radius of a specific point

	data : DataFrame
		data to restrict 
	restriction : float
		maximum acceptable distance
	'''
	return data.loc[data["distance"]<restriction]

def restrict_by_year(data, year=None, L_year=None, both=False):
	'''
	get subset of a data set that is transacted in a certain year

	data : DataFrame
		data to restrict 
	year : int
		year in which data must transact
	'''

	if both:
		return data.loc[(data["year"]==year)&(data["L_year"]==L_year)]
	else:
		return data.loc[data["year"]==year]
	

def restrict_by_quarter(data, quarter):
	'''
	get subset of a data set that is transacted in a certain quarter

	data : DataFrame
		data to restrict 
	quarter : int
		quarter in which data must transact
	'''
	return data.loc[data["quarter"]==quarter]

def restrict_by_month(data, month):
	'''
	get subset of a data set that is transacted in a certain quarter

	data : DataFrame
		data to restrict 
	month : int
		month in which data must transact
	'''
	return data.loc[data["month"]==month]

def get_restricted_data(purchase_controls, sale_controls, row, pduration_var='L_duration', sduration_var='whb_duration', margin=0.1, restrict_quarter=False, restrict_month=False, keys=["property_id", "year", "L_year", "quarter", "duration", "L_duration", "distance", "log_price", "L_log_price"] , text=""):
	'''
	restrict data so that it has a similar duration and transaction times as the treated property

	purchase_controls : DataFrame
		data pool from which to pick purchase control properties 
	sale_controls : DataFrame 
		data pool from which to pick sale control properties 
	row : Series
		data for treated property
	pduration_var : string 
		purchase duration key 
	sduration_var : string 
		sale duration key 
	restrict_quarter : bool
		flag for whether to enforce that controls are purchased in the same quarter as the treated property
	margin : float 
		the maximum difference between the treated and control duration 
	text : string 
		text to output in verbose setting
	'''
	purchase_data = restrict_by_year(purchase_controls, year=row["L_year"])
	purchase_data = restrict_by_duration(purchase_data, margin=margin, duration=row[pduration_var])

	if restrict_quarter:
		purchase_data = restrict_by_quarter(purchase_data, quarter=row["L_quarter"])

	if restrict_month:
		purchase_data = restrict_by_month(purchase_data, month=row["L_month"])

	text += "\n\nPurchase controls:\n"
	text += str(purchase_data[keys]) + "\n\n"

	sale_data = restrict_by_year(sale_controls, year=row["year"])
	sale_data = restrict_by_duration(sale_data, margin=margin, duration=row[sduration_var])
	
	if restrict_quarter:
		sale_data = restrict_by_quarter(sale_data, quarter=row["quarter"])

	if restrict_month:
		sale_data = restrict_by_month(sale_data, month=row["month"])

	text += "\n\nSale controls:\n"
	text += str(sale_data[keys]) + "\n\n"

	return purchase_data, sale_data, text

def wrapper(df, price_var='log_price', real_time=None, pduration_var='L_duration', sduration_var='whb_duration', restrict_quarter=False, restrict_month=False, restrictions=[0.1,0.5,1,5,10,20], margin=0.1, extension_var='extension', func=None, parallelize=True, restrict_both_years=False, necessary_fields = list(set(["property_id", "date_trans", "postcode", "lat_rad", "lon_rad", "duration", "L_duration","year", "L_year", "quarter", "L_quarter", "area", "duration10yr", "outcode", "log_price", "L_log_price"]))):
	'''
	set up data to get controls
	
	df : DataFrame
		data with all properties
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
	extension_var : string 
		flag identifying extended properties
	func : func
		function to apply to data
	necessary_fields : list (string)
		data fields to keep (to make data lighter)
	'''

	# Drop if missing main price variable
	df = df[~df[price_var].isna()]
	df[price_var] = df[price_var].astype(float)

	df["lat_rad"] = np.deg2rad(df["latitude"])
	df["lon_rad"] = np.deg2rad(df["longitude"])

	extensions = df.loc[df[extension_var]==1]
	controls = df.loc[df[extension_var]==0]

	# If we're doing the real-time updates, we only need the last year 
	if real_time:
		extensions = extensions[extensions.year==real_time]

	# Restrict controls to the durations that are relevant to us
	min_dur = extensions['whb_duration'].min()
	max_dur = extensions[extensions.extension==1]['L_duration'].max() 

	print("Shortest extension would-have-been duration:", min_dur)
	print("Longest extension purchase duration:", max_dur)

	controls = controls.loc[controls['duration']>0]
	if extension_var in ['extension_misspre', 'official_extension_misspre']:
		controls = controls.loc[controls['duration']<=max_dur+20]

	print("\n\nExtensions:")
	print(extensions[['property_id', 'year', 'L_year', 'duration', 'L_duration']])

	print("\n\nControls:")
	print(controls[['property_id', 'year', 'L_year', 'duration', 'L_duration']])

	# Keep only necessary fields to speed up the process
	necessary_fields = list(set(necessary_fields + [price_var]))
	controls = controls[necessary_fields]

	# Sort restrictions backwards:
	restrictions.sort(reverse=True)

	prefixes=["L_", ""]
	new_cols = [f"{prefix}{var}_{restriction}_km" for restriction in restrictions for prefix in prefixes for var in ["index", "duration_idx"]]

	print("Creating price index:")
	if parallelize:
		num_processes = int(os.cpu_count())
		pool = Pool(num_processes)
		print("Number of cores:", num_processes)

		# Split and group by year
		threshold_size = np.minimum(len(extensions)/num_processes, 500) # Adjust this based on your desired chunk size
		extensions_grouped = split_into_chunks({name: group for name, group in extensions.groupby(['year', 'L_year', 'area'])}, threshold_size)
		controls_grouped = {name: group for name, group in controls.groupby(['year', 'area'])}

		dfs = []
		count = 0
		for name, group in extensions_grouped:
			sale_year = name[0]
			purchase_year = name[1]
			area = name[2]

			if (sale_year, area) not in controls_grouped or (purchase_year, area) not in controls_grouped:
				count += 1
				continue

			inp = (group, controls_grouped[(sale_year, area)], controls_grouped[(purchase_year, area)], new_cols, price_var, pduration_var, sduration_var, restrict_quarter, restrict_month, restrict_both_years, margin)
			dfs.append(inp)
		print(f'Missing controls for {count}.')

		extensions = pd.concat(pool.map(func, dfs, chunksize=1))

	else:
		inp = (extensions, controls, controls, new_cols, price_var, pduration_var, sduration_var, restrict_quarter, restrict_month, restrict_both_years, margin)
		extensions = func(inp, restrictions=restrictions)

	return extensions
