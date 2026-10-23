import xarray as xr
import numpy as np
import pandas as pd

# --- Input and output files ---
input_file = "argo_2018_golfe_lion_depth.nc"
output_file = "argo_2018_golfe_lion.adbs"

# --- Read the NetCDF file ---
ds = xr.open_dataset(input_file)

lon = ds['LONGITUDE'].values
lat = ds['LATITUDE'].values
depth = ds['DEPTH'].values
time = ds['TIME'].values
temp = ds['TEMP'].values
psal = ds['PSAL'].values

# --- Define the reference time for conversion to days ---
origin = np.datetime64("1950-01-01T00:00:00")

# --- Convert NetCDF time to days since the reference time ---
# TIME was expressed in seconds since 1950-01-01 
time_days = (time.astype("datetime64[s]") - origin) / np.timedelta64(1, "D")

# --- Open the ASCII file for writing ---
header_lines = 1
with open(output_file, "w") as f:
    # Write the number of header lines
    f.write(f"{header_lines}\n")
    # Write the column names (optional)
    f.write("lon lat depth time temp psal\n")

    # Loop over all observation points
    for lo, la, d, t, tmp, sal in zip(lon, lat, depth, time_days, temp, psal):
        df = pd.DataFrame({
            "lon": [lo],
            "lat": [la],
            "depth": [d],
            "time": [t],
            "temp": [tmp],
        })
        df.to_csv(f, sep=' ', index=False, header=False, float_format="%.6f")

print(f"ASCII file created: {output_file}")
