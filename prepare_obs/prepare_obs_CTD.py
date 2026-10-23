import xarray as xr
import numpy as np
import pandas as pd

def replace_year(t, year_new):
    """Replace only the year while preserving month, day, hour, minute, and second."""
    m = int(str(t)[5:7])
    d = int(str(t)[8:10])
    hh = int(str(t)[11:13])
    mm = int(str(t)[14:16])
    ss = int(str(t)[17:19])
    return np.datetime64(f"{year_new}-{m:02d}-{d:02d}T{hh:02d}:{mm:02d}:{ss:02d}")

# --- Parameters ---
time_file = "CTD_time.nc"  # CTD observation dates
input_file = "MGE_24j.nc"
output_file = "MGE_24j.adbs"
d_file = "path/to/your/grid_file.nc"

# --- Read the NetCDF files ---
ds = xr.open_dataset(input_file)
dst = xr.open_dataset(time_file)
temperature = 1.0

# --- Load the observation locations and reference year ---
lon = ds['LONGITUDE'].values.flatten()
lat = ds['LATITUDE'].values.flatten()
time = dst['TIME'].values
origin = np.datetime64("1950-01-01T00:00:00")  # Reference date for time conversion
depth = xr.open_dataset(d_file)["nav_lev"].values

print(depth)

# --- Generate observations over 10 years ---
time_dt = time.astype("datetime64[ns]")
header_lines = 1

with open(output_file, "w") as f:
    # Write the number of header lines
    f.write(f"{header_lines}\n")
    # Write the column names
    f.write("lon lat depth time temperature\n")

    all_years = []
    for year in range(2009, 2020):
        new_series = [replace_year(t, year) for t in time_dt]

        # Convert timestamps to days relative to the reference date
        time_days = 31 + (new_series - origin) / np.timedelta64(1, "D")
        print(len(time_days), len(lon))

        # Generate synthetic CTD observations for each year
        # Loop over each longitude, latitude, and observation time
        for lo, la, tim in zip(lon, lat, time_days):
            # Create a depth × time profile
            D = depth
            n = D.size
            df = pd.DataFrame({
                "lon": np.full(n, lo),
                "lat": np.full(n, la),
                "depth": D.ravel(),
                "time": np.full(n, tim),
                "temperature": np.full(n, temperature)
            })
            df.to_csv(f, sep=' ', index=False, header=False, float_format="%.6f")

        print(f"ASCII file created: {output_file}")
