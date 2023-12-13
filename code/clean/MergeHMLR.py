from fuzzy_merge import *
from utils import *

if __name__ == "__main__":
	'''
	Fuzzy merge of HMLR data 
	'''

	# HMLR merge
	print("Importing price data")
	transaction_file = os.path.join(working_folder, "price_data_for_merge.csv")
	transaction_data = pd.read_csv(transaction_file)
	print("Number of rows:", len(transaction_data.index))

	print("\nImporting lease data")
	lease_file = os.path.join(working_folder, "lease_data_for_merge.csv")
	lease_data = pd.read_csv(lease_file)
	print("Number of rows:", len(lease_data.index))

	pid1 = 'property_id'
	pid2 = 'merge_key'
	output_file = os.path.join(working_folder, "hmlr_merge_keys.dta")
	match, _, _ = fuzzy_merge(transaction_data, lease_data, pid1=pid1, pid2=pid2, to_tokenize1="address", to_tokenize2="address", exact_ids=["merge_key_1", "merge_key_2"], output_vars=['property_id','merge_key','merged_on'])

	print(match)

	############################
	# Drop duplicates matches
	############################
	len_before = len(match.index)
	match = match.drop_duplicates(keep="first")
	# print(f"Dropped {len_before - len(match.index)} entries.")
	len_before = len(match.index)

	for pid in [pid1, pid2]:
		# print()
		# print(pid)
		# print('--------')
		if pid == pid1:
			other_pid = pid2
		else:
			other_pid = pid1
			
		match['dup'] = match[pid].duplicated(keep=False)
		match['max_common_words'] = match.groupby(pid)['common_words'].transform('max')
		match = match[match.common_words==match.max_common_words]
		
		# print(f"Dropped {len_before - len(match.index)} entries by using common words.")
		len_before = len(match.index)

		i = 2
		match['dup'] = match[pid].duplicated(keep=False)
		match = match[(match.dup==False)|(match[pid].str.split().str[:i].apply(' '.join)==match[other_pid].str.split().str[:i].apply(' '.join))]

		# print(f"Dropped {len_before - len(match.index)} entries by using start of the sentence.")
		len_before = len(match.index)
			
		match = match.drop_duplicates(subset=[pid], keep=False)
		
		# print(f"Dropped {len_before - len(match.index)} remaining duplicates of {pid}.")
		len_before = len(match.index)

	# Export 
	match.to_stata(output_file, write_index=False)