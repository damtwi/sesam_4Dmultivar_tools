import gsw
from argopy import DataFetcher

# Define the geographical, depth and time limits
region = [
    1.0, 11.5,      # Longitude limits
    38.0, 46.0,     # Latitude limits
    0, 3000,        # Pressure limits (dbar)
    "2018-01-01", "2019-01-01"  # Time interval
]

# Retrieve Argo data from the ERDDAP data source
ds = DataFetcher(src="erddap").region(region).to_xarray()

# Compute depth from pressure (positive downward, in metres)
ds["DEPTH"] = (
    "N_POINTS",
    -gsw.z_from_p(ds["PRES"].values, ds["LATITUDE"].values),
    {
        "long_name": "Depth",
        "units": "m",
        "positive": "down",
    },
)

# Save the extracted data to a NetCDF file
output_file = "argo_2018_golfe_lion_depth.nc"
ds.to_netcdf(output_file)

print(f"Argo data saved to: {output_file}")
print(ds)
