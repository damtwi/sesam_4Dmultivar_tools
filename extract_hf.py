"""
Apply a temporal Lanczos filter to NetCDF fields and save the high- and
low-frequency components.

The script processes one variable at a time, extracting a selected latitude
range and splitting the longitude domain into blocks.

Parallelization:
    - With MPI enabled, the longitude domain is distributed across MPI ranks.
    - Each rank further subdivides its assigned domain into `num_blocks`
      smaller blocks to limit memory usage.
    - Blocks processed by the same rank are concatenated along longitude.
    - Each rank writes its own HF and LF NetCDF files, identified by a
      four-digit rank suffix in the output filename.

Outputs:
    <output_prefix><rank><filter>_<window_size>hf.nc
    <output_prefix><rank><filter>_<window_size>lf.nc

    HF contains the high-frequency residual (original minus low-pass filtered
    field), with filter-edge samples removed.
    LF contains the low-pass filtered field, with filter-edge samples removed
    and the time series subsampled according to `num_timesteps`.

    When `num_timesteps == -1`, LF is sampled at the available dates closest
    to the 15th of each month. Otherwise, every `num_timesteps`-th sample
    is retained.

Note:
    The output latitude, longitude and depth coordinates are array indices,
    not the original geographic coordinates or physical depth values.
    Rank-specific files must be concatenated along longitude to reconstruct
    the complete spatial domain.
"""

import cftime
import argparse
import netCDF4 as nc
import numpy as np
from scipy.signal import lfilter, windows
import time
from scipy.signal import butter, filtfilt


def load_dates_one_simulation(netcdf_files):
    time_all = []
    units = None
    calendar = None

    for f in netcdf_files:
        with nc.Dataset(f) as ds:
            time_all.extend(ds.variables["time_counter"][:])
            units = ds.variables["time_counter"].units
            calendar = ds.variables["time_counter"].calendar

    time_all = np.array(time_all)
    dates = cftime.num2date(time_all, units=units, calendar=calendar)
    return time_all, np.array(dates)

def get_midmonth_indices(dates):
    indices = []
    months = np.array([d.month for d in dates])
    years  = np.array([d.year  for d in dates])

    for y in np.unique(years):
        for m in range(1, 13):
            # indices pour ce mois
            idx = np.where((years == y) & (months == m))[0]
            if len(idx) == 0:
                continue

            # jour du mois
            days = np.array([d.day for d in dates[idx]])

            # cherche la date observée la plus proche du 15
            nearest = idx[np.argmin(np.abs(days - 15))]

            indices.append(nearest)

    return np.array(indices)

def lanczos_filter(N, fc):
    """
    Crée un filtre de Lanczos de longueur N avec une fréquence de coupure fc (en Hz).
    N doit être impair.
    """
    n = np.arange(-(N//2), N//2 + 1)
    h = np.sinc(2 * fc * n)  # sinc(x) = sin(pi*x)/(pi*x)
    lanczos_window = np.sinc(n / (N//2 + 1))
    h *= lanczos_window
    h /= np.sum(h)  # normalisation
    return h

def butter_lowpass(cutoff, fs, order=5):
    return butter(order, cutoff, fs=fs, btype='low', analog=False)

def butter_lowpass_filter(data, cutoff, fs=1.0, order=5):
    b, a = butter(order, cutoff / (0.5 * fs), btype='low', analog=False)
    y = filtfilt(b, a, data, axis=0)
    return y

def get_lanczos_window(window_size):
    """Generate a Lanczos window of the specified size."""
    half_n = (window_size - 1) / 2
    n = np.arange(window_size)
    return np.sinc((n - half_n) / half_n) * np.sinc((n - half_n) / half_n / 2)

def extract_time_series(netcdf_files, variable_name, variable_dim,
                        lat_index_start, lat_index_end,
                        lon_index_start, lon_index_end,
                        clim_ok=False):
    """
    Extracts a contiguous block of time series from one or several NetCDF files
    and optionally removes the monthly climatology.

    Args:
        netcdf_files (list): List of paths to the NetCDF files.
        variable_name (str): Name of the variable in the NetCDF file.
        variable_dim (int): Dimension of the variable (2 or 3).
        lat_index_start (int): Starting latitude index.
        lat_index_end (int): Ending latitude index.
        lon_index_start (int): Starting longitude index.
        lon_index_end (int): Ending longitude index.
        clim_ok (bool): If True, remove monthly climatology (default=True).

    Returns:
        tuple: (time_values, output_series)
            - output_series = anomalies if clim_ok=True
            - output_series = raw time series if clim_ok=False
    """
    
    time_values = []
    time_series = []

    for netcdf_file in netcdf_files:
        # Open the NetCDF file
        nc_data = nc.Dataset(netcdf_file, 'r')
        # Extract time values
        time_values.extend(nc_data.variables['time_counter'][:])
        # Extract time series based on provided indices
        if variable_dim==2:
          time_series.extend(nc_data.variables[variable_name][:, lat_index_start-1:lat_index_end, lon_index_start-1:lon_index_end])
        elif variable_dim==3:
          time_series.extend(nc_data.variables[variable_name][:, :, lat_index_start-1:lat_index_end, lon_index_start-1:lon_index_end])
        else:
          raise ValueError("Bad variable dimension in extract_time_series.")
    # print("extract ok")
    time_series = np.array(time_series)
    time_values = np.array(time_values)

    # If climatology removal is disabled, return directly
    if not clim_ok:
        return time_values, time_series

 
    # --- Compute monthly climatology ---
    months = np.array([d.month for d in dates])
    climato = np.zeros((12,) + time_series.shape[1:], dtype=time_series.dtype)

    for month in range(1, 13):
        mask = (months == month)
        if mask.any():
            climato[month - 1] = time_series[mask].mean(axis=0)

    # --- Compute anomalies ---
    anomalies = np.empty_like(time_series)
    for i, month in enumerate(months):
        anomalies[i] = time_series[i] - climato[month - 1]

    return time_values, anomalies


def apply_lanczos_filter(time_values, time_series, window_size, num_timesteps):
    """
    Applies a zero-phase Lanczos filter in time, removes edge effects, and subsamples the time series.
    
    Args:
        time_values (ndarray): Array of time values.
        time_series (ndarray): Array of time series values.
        window_size (int): Size of the Lanczos window (should be odd).
        num_timesteps (int): Number of timesteps between subsamples.
    
    Returns:
        tuple: (subsampled_time_values, residual, subsampled_filtered_series)
    """

    # Generate the Lanczos window
    lanczos_window = get_lanczos_window(window_size)
    
    # Normalize window to have unity gain
    lanczos_window /= np.sum(lanczos_window)
    
    # Apply zero-phase filtering with filtfilt
    filtered_time_series = filtfilt(lanczos_window, [1.0], time_series, axis=0)
    
    # Compute residual (original - filtered)
    residual_time_series = time_series - filtered_time_series
    
    # Remove edges to avoid filter artifacts
    edge = window_size // 2
    filtered_time_series = filtered_time_series[edge:-edge]
    residual_time_series = residual_time_series[edge:-edge]
    time_values_trimmed = time_values[edge:-edge]

    if num_timesteps == -1:
        global output_indices

        # On garde uniquement les indices valables après découpe
        valid = (output_indices >= edge) & (output_indices < len(time_values) - edge)
        
        # On convertit les indices bruts en indices dans la série filtrée
        output_indices_adj = output_indices[valid] - edge
        subsampled_time_series = filtered_time_series[output_indices_adj]
        subsampled_time_values = time_values_trimmed[output_indices_adj]
    else:
        subsampled_time_series = filtered_time_series[::num_timesteps]
        subsampled_time_values = time_values_trimmed[::num_timesteps]
    
    # Subsample the filtered series and residual
    subsampled_residual = residual_time_series[:]
    subsampled_time_residual = time_values_trimmed[:]
    
    return subsampled_time_values, subsampled_residual, subsampled_time_series, subsampled_time_residual



def save_to_netcdf(filename, time_values, time_series, variable_name, variable_dim):
    """
    Saves time values and time series to a NetCDF file.
    
    Args:
    filename (str): Name of the NetCDF file to save.
    time_values (ndarray): Array of time values.
    time_series (ndarray): Array of time series values.
    variable_name (str): Name of the variable.
    variable_dim (int): dimension of the variable.
    """
    with nc.Dataset(filename, 'w', format='NETCDF4') as nc_file:
        # Create dimensions
        nc_file.createDimension('time', len(time_values))
        if variable_dim==2:
          nc_file.createDimension('lat', time_series.shape[1])
          nc_file.createDimension('lon', time_series.shape[2])
        elif variable_dim==3:
          nc_file.createDimension('depth', time_series.shape[1])
          nc_file.createDimension('lat', time_series.shape[2])
          nc_file.createDimension('lon', time_series.shape[3])

        # Create variables
        time_var = nc_file.createVariable('time', 'f8', ('time',))
        if variable_dim==3:
          depth_var = nc_file.createVariable('depth', 'f4', ('depth',))
        lat_var = nc_file.createVariable('lat', 'f4', ('lat',))
        lon_var = nc_file.createVariable('lon', 'f4', ('lon',))
        if variable_dim==2:
          variable_var = nc_file.createVariable(variable_name, 'f4', ('time', 'lat', 'lon',))
        elif variable_dim==3:
          variable_var = nc_file.createVariable(variable_name, 'f4', ('time', 'depth', 'lat', 'lon',))

        # Write data to variables
        time_var[:] = time_values
        variable_var[:] = time_series
        if variable_dim==2:
          lat_var[:] = np.arange(time_series.shape[1])
          lon_var[:] = np.arange(time_series.shape[2])
        elif variable_dim==3:
          depth_var[:] = np.arange(time_series.shape[1])
          lat_var[:] = np.arange(time_series.shape[2])
          lon_var[:] = np.arange(time_series.shape[3])

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Extract time series from a series of NetCDF files, apply Lanczos filter, and save to NetCDF file.')
    parser.add_argument('netcdf_files', nargs='+', type=str, help='List of paths to the NetCDF files')
    parser.add_argument('--variable_name', type=str, required=True, help='Name of the variable in the NetCDF file')
    parser.add_argument('--variable_dim', type=int, required=True, help='Dimension of the variable in the NetCDF file')
    parser.add_argument('--lat_index_start', type=int, required=True, help='Starting index of the latitude coordinate')
    parser.add_argument('--lat_index_end', type=int, required=True, help='Ending index of the latitude coordinate')
    parser.add_argument('--lon_index_start', type=int, required=True, help='Starting index of the longitude coordinate')
    parser.add_argument('--lon_index_end', type=int, required=True, help='Ending index of the longitude coordinate')
    parser.add_argument('--window_size', type=int, required=True, help='Size of window used in Lanczos filter')
    parser.add_argument('--num_timesteps', type=int, required=True, help='Number of timesteps between subsamples')
    parser.add_argument('--num_blocks', type=int, required=False, help='Number of longitue blocks (by processor if MPI)')
    parser.add_argument('--use_mpi', action='store_true', help='Use MPI parallelization')
    parser.add_argument('--filters', type=str, help='filter you want to use (lanczos or butterworth')
    parser.add_argument('--output_file', type=str, required=True, help='Name of the output NetCDF file')
    args = parser.parse_args()
    # Set default number of blocks
    if args.num_blocks is None:
       args.num_blocks = 1

    # Get information from MPI
    if args.use_mpi:
       from mpi4py import MPI
       mpicomm = MPI.COMM_WORLD
       mpirank = mpicomm.Get_rank()
       mpisize = mpicomm.Get_size()
    else:
       mpirank = 0
       mpisize = 1
       
    # Initial execution time
    time_start = time.time()
    # Perform extraction by blocks of longitudes
    if args.use_mpi:
       # total block to be extracted by current processors
       mpiblocksize = 1 + (args.lon_index_end - args.lon_index_start)//mpisize
       lon0 = args.lon_index_start + mpirank*mpiblocksize
       lon1 = min(lon0 + mpiblocksize - 1,args.lon_index_end)
       # further subdivide it in smaller blocks
       blocksize = 1 + (mpiblocksize-1)//args.num_blocks
       print(f"[rank {mpirank}] lon0={lon0}, lon1={lon1}, blocksize={blocksize}")
    else:
       # total block to be extracted by the single processor
       lon0 = args.lon_index_start
       lon1 = args.lon_index_end
       # subdivide it in smaller blocks
       blocksize = 1 + (lon1-lon0)//args.num_blocks

    time_values_all, dates = load_dates_one_simulation(args.netcdf_files)
    output_indices = get_midmonth_indices(dates)

    subsampled_time_values = None  # initialise avant la boucle
    for lon_block0 in range(lon0, lon1+1, blocksize):
        lon_block1 = min(lon_block0+blocksize-1, lon1)
        print('indices', lon_block0, lon_block1, mpirank)

        # Extract time series
        time_values, time_series = extract_time_series(
            args.netcdf_files, args.variable_name, args.variable_dim,
            args.lat_index_start, args.lat_index_end, lon_block0, lon_block1)
        
        # Apply Lanczos filter and subsample
        subsampled_time_values_tmp, subsampled_time_series, filtered_LF,subsampled_time_residual = apply_lanczos_filter(
            time_values, time_series, args.window_size, args.num_timesteps)

        # Save time values only once (identical for all lon blocks)
        if subsampled_time_values is None:
            subsampled_time_values = subsampled_time_values_tmp

        # Concatenate blocks
        if lon_block0 == lon0:
            all_subsampled_time_series = subsampled_time_series
            all_subsampled_time_seriesLF = filtered_LF
        else:
            all_subsampled_time_series = np.concatenate(
                (all_subsampled_time_series, subsampled_time_series), axis=-1)
            all_subsampled_time_seriesLF = np.concatenate(
                (all_subsampled_time_seriesLF, filtered_LF), axis=-1)

        print('time:', time.time() - time_start, ', proc:', mpirank)

    # Save after loop
    if args.use_mpi:
        args.output_file = args.output_file + f'{mpirank:0>4}'

    save_to_netcdf(
        args.output_file + f"{args.filters}_{args.window_size}hf.nc",
        subsampled_time_residual, all_subsampled_time_series, args.variable_name, args.variable_dim)
    save_to_netcdf(
        args.output_file + f"{args.filters}_{args.window_size}lf.nc",
        subsampled_time_values, all_subsampled_time_seriesLF, args.variable_name, args.variable_dim)
