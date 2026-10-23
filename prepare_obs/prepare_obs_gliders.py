import xarray as xr
import pandas as pd
import numpy as np

# Open dataset (no need to decode time, already decoded)
ds = xr.open_dataset("2018_all_gliders_with_depth.nc")

# Remove NaT if present
ds = ds.dropna(dim="TIME")

# Extract 2018 time template
template_time = pd.to_datetime(ds.TIME.values)

# Years to duplicate
years = np.arange(2009, 2020)

datasets = []

for year in years:
    new_time = pd.to_datetime([
        t.replace(year=year) for t in template_time
    ])
    
    ds_copy = ds.copy()
    ds_copy = ds_copy.assign_coords(TIME=("TIME", new_time))
    datasets.append(ds_copy)

# Concatenate along TIME
ds_out = xr.concat(datasets, dim="TIME")

# Sort by time (important)
ds_out = ds_out.sortby("TIME")

# Re-encode TIME properly
ds_out.TIME.encoding = {
    "units": "days since 1950-01-01",
    "calendar": "gregorian"
}

# Save
ds_out.to_netcdf("all_gliders_2010_2020.ncdbs")
