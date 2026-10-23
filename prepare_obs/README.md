# prepare_obs

This directory contains the tools used to prepare in-situ ocean observations
before they are assimilated or compared with model outputs. The scripts
download, reshape and convert several kinds of observations (Argo floats,
gliders, CTD and satellite altimetry) into the file formats expected by the
SESAM/SAM model tools.

## Contents

### Python scripts

- `get_Argo.py`: downloads Argo data from the ERDDAP server with `argopy` & computes depth from pressure.
- `prepare_obs_Argo.py`: Writes the Argo profiles to the ASCII file for SESAM.
- `prepare_obs_gliders.py`: takes the 2018 glider dataset, duplicates its
  profiles over the years 2009 to 2020.
- `prepare_obs_CTD.py`: builds synthetic CTD observations from a NetCDF file
  and a grid file, repeating the same profiles for each year from 2009 to
  2020.

### Shell scripts

- `prepare_obs_database.bash`: Subsample satellite observation and concatenates it into a single observation database.
- `prepare_obs.bash`: Extract observations and compute observation operator for SESAM.
