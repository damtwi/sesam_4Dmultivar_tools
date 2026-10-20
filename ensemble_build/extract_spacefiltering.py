import argparse
import netCDF4 as nc
import numpy as np
from scipy.ndimage import gaussian_filter

"""
Apply a Gaussian spatial filter to time-dependent NetCDF fields.

The script processes 2D surface fields or 3D fields (including depth),
handling missing values to avoid bias near coastlines. Time indices are
distributed across MPI ranks and further split into smaller blocks to
limit memory usage.

Each rank writes a filtered NetCDF file containing its assigned time
indices. The output filename includes the spatial filter window and,
when MPI is enabled, the rank identifier.
"""


def apply_gaussian_spatial_filter(time_values, time_series, variable_dim, sigma=10.):
    """
    Apply Gaussian spatial filter along lat/lon (and depth if 3D),
    ignoring NaN values. Missing data are temporarily set to zero but
    normalization by the filtered mask avoids bias near coastlines.
    The original NaN mask is restored after filtering.
    """
    filtered = np.zeros_like(time_series)

    if variable_dim == 3:
        for t in range(time_series.shape[0]):
            for d in range(time_series.shape[1]):
                field = time_series[t, d, :, :].copy()
                original_mask = ~np.isfinite(field)  # True where NaN (land)
                mask = np.isfinite(field)
                field[~mask] = 0.0

                filtered_data = gaussian_filter(field, sigma=sigma)
                filtered_mask = gaussian_filter(mask.astype(float), sigma=sigma)

                with np.errstate(invalid='ignore', divide='ignore'):
                    result = filtered_data / filtered_mask

                # Restore NaN on land and in places where mask weight < threshold
                result[original_mask | (filtered_mask < 1e-6) | (result > 1e20)] = np.nan
                filtered[t, d, :, :] = result

    elif variable_dim == 2:
        for t in range(time_series.shape[0]):
            field = time_series[t, :, :].copy()
            original_mask = ~np.isfinite(field)
            mask = np.isfinite(field)
            field[~mask] = 0.0

            filtered_data = gaussian_filter(field, sigma=sigma)
            filtered_mask = gaussian_filter(mask.astype(float), sigma=sigma)

            with np.errstate(invalid='ignore', divide='ignore'):
                result = filtered_data / filtered_mask

            result[original_mask | (filtered_mask < 1e-6)] = np.nan
            filtered[t, :, :] = result

    else:
        raise ValueError("Unsupported dimension")

    return time_values, filtered


# def apply_gaussian_spatial_filter(time_values, time_series, variable_dim, sigma=10.):
#     """
#     Apply Gaussian spatial filter along lat/lon (and depth if 3D),
#     ignoring NaN values. Missing data are temporarily set to zero but
#     the normalization by the filtered mask ensures no bias is introduced
#     near coastlines or masked regions.
#     """

#     filtered = np.zeros_like(time_series)

#     if variable_dim == 3:
#         for t in range(time_series.shape[0]):
#             for d in range(time_series.shape[1]):
#                 field = time_series[t, d, :, :].copy()
#                 mask = np.isfinite(field)
#                 field[~mask] = 0.0

#                 filtered_data = gaussian_filter(field, sigma=sigma)
#                 filtered_mask = gaussian_filter(mask.astype(float), sigma=sigma)

#                 with np.errstate(invalid='ignore', divide='ignore'):
#                     filtered[t, d, :, :] = filtered_data / filtered_mask
#                 filtered[t, d, filtered_mask < 1e-6] = np.nan

#     elif variable_dim == 2:
#         for t in range(time_series.shape[0]):
#             field = time_series[t, :, :].copy()
#             mask = np.isfinite(field)
#             field[~mask] = 0.0

#             filtered_data = gaussian_filter(field, sigma=sigma)
#             filtered_mask = gaussian_filter(mask.astype(float), sigma=sigma)

#             with np.errstate(invalid='ignore', divide='ignore'):
#                 filtered[t, :, :] = filtered_data / filtered_mask
#             filtered[t, filtered_mask < 1e-6] = np.nan

#     else:
#         raise ValueError("Unsupported dimension")

#     return time_values, filtered


def extract_time_series(netcdf_files, variable_name, variable_dim, time_block0, time_block1, fill_value=1e20):
    """
    Extract contiguous block from NetCDF files while preserving dimensions.
    Mask _FillValue or missing_value entries as NaN.
    """
    time_series_list = []
    time_values_list = []

    for netcdf_file in netcdf_files:
        with nc.Dataset(netcdf_file, 'r') as nc_data:
            # Extract time slice
            time_values_chunk = nc_data.variables['time_counter'][time_block0:time_block1+1]
            time_values_list.append(time_values_chunk)

            # Extract variable depending on its dimensionality
            var = nc_data.variables[variable_name]
            if variable_dim == 2:
                chunk = var[time_block0:time_block1+1, :, :]
            elif variable_dim == 3:
                chunk = var[time_block0:time_block1+1, :, :, :]
            else:
                raise ValueError("Unsupported variable dimension.")

            # Convert to float and mask invalid values
            chunk = np.array(chunk, dtype=np.float32)
            invalid_mask = (chunk >= fill_value) | ~np.isfinite(chunk)
            chunk[invalid_mask] = np.nan

            time_series_list.append(chunk)

    # Concatenate along the time axis
    time_series = np.concatenate(time_series_list, axis=0)
    time_values = np.concatenate(time_values_list, axis=0)

    return time_values, time_series

def save_to_netcdf(filename, time_values, time_series, variable_name, variable_dim):
    """
    Save filtered time series to NetCDF preserving dimensions.
    """
    with nc.Dataset(filename, 'w', format='NETCDF4') as nc_file:
        nc_file.createDimension('time', len(time_values))
        time_var = nc_file.createVariable('time', 'f8', ('time',))
        time_var[:] = time_values

        # Determine shape
        if variable_dim == 3 and time_series.ndim == 4:
            nc_file.createDimension('depth', time_series.shape[1])
            nc_file.createDimension('lat', time_series.shape[2])
            nc_file.createDimension('lon', time_series.shape[3])
            var = nc_file.createVariable(variable_name, 'f4', ('time','depth','lat','lon'))
        elif variable_dim == 2 and time_series.ndim == 3:
            nc_file.createDimension('lat', time_series.shape[1])
            nc_file.createDimension('lon', time_series.shape[2])
            var = nc_file.createVariable(variable_name, 'f4', ('time','lat','lon'))
        else:
            raise ValueError(f"Unexpected shape {time_series.shape} for variable_dim={variable_dim}")

        var[:] = time_series

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('netcdf_files', nargs='+', type=str)
    parser.add_argument('--variable_name', type=str, required=True)
    parser.add_argument('--variable_dim', type=int, required=True)
    parser.add_argument('--window_size', type=int, required=True)
    parser.add_argument('--total_timesteps', type=int, required=True)
    parser.add_argument('--num_blocks', type=int, required=False, default=1)
    parser.add_argument('--use_mpi', action='store_true')
    parser.add_argument('--output_file', type=str, required=True)
    args = parser.parse_args()

    if args.use_mpi:
        from mpi4py import MPI
        mpicomm = MPI.COMM_WORLD
        mpirank = mpicomm.Get_rank()
        mpisize = mpicomm.Get_size()
    else:
        mpirank = 0
        mpisize = 1

    # Determine block size
    mpiblocksize = 1 + (args.total_timesteps - 1) // mpisize if args.use_mpi else args.total_timesteps
    time_block0_global = mpirank * mpiblocksize if args.use_mpi else 0
    time_block1_global = min(time_block0_global + mpiblocksize - 1, args.total_timesteps - 1)
    blocksize = 1 + (mpiblocksize - 1) // args.num_blocks

    print('Blocksize info:', args.total_timesteps, time_block0_global, time_block1_global, blocksize, mpirank)

    lon0 = time_block0_global
    all_subsampled_time_series = None
    all_subsampled_time_values = None

    for tb0 in range(time_block0_global, time_block1_global + 1, blocksize):
        tb1 = min(tb0 + blocksize - 1, time_block1_global)
        print('Processing time indices:', tb0, tb1, mpirank)

        time_values, time_series = extract_time_series(args.netcdf_files, args.variable_name, args.variable_dim, tb0, tb1)
        # --- skip empty slices ---
        if time_values is None or len(time_values) == 0:
            print(f"empty block : tb0={tb0}, tb1={tb1}, rank={mpirank}")
            continue

        time_values, filtered_series = apply_gaussian_spatial_filter(time_values, time_series, args.variable_dim, sigma=args.window_size)

        if all_subsampled_time_series is None:
            all_subsampled_time_series = filtered_series
            all_subsampled_time_values = time_values
        else:
            all_subsampled_time_series = np.concatenate((all_subsampled_time_series, filtered_series), axis=0)
            all_subsampled_time_values = np.concatenate((all_subsampled_time_values, time_values), axis=0)

    # Adjust output filename for MPI
    output_file = args.output_file + (f"{mpirank:04}" if args.use_mpi else "")
    save_to_netcdf(output_file + f"_{args.window_size}splf.nc", all_subsampled_time_values, all_subsampled_time_series, args.variable_name, args.variable_dim)
