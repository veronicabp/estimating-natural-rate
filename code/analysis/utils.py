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
data_folder = os.path.join("..", "..", "data")
working_folder =  os.path.join(data_folder, "working")
raw_folder =  os.path.join(data_folder, "raw")
clean_folder =  os.path.join(data_folder, "clean")

overleaf = "/Users/veronicabackerperal/Dropbox (Princeton)/Apps/Overleaf/UK Duration"
figures_folder = os.path.join(overleaf, 'figures')
tables_folder = os.path.join(overleaf, 'tables')