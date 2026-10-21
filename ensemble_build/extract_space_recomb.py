import argparse
import netCDF4 as nc
import numpy as np
import os

def extract_time_block(netcdf_file, variable_name, variable_dim):
    """
    Extracts a filtered time block from a NetCDF file.

    Args:
        netcdf_file (str): Path to the NetCDF file.
        variable_name (str): Name of the variable.
        variable_dim (int): Number of dimensions of the variable (2 or 3).

    Returns:
        block: numpy array containing the filtered data block.
    """
    with nc.Dataset(netcdf_file, 'r') as ds:
        if variable_dim == 2:
            block = ds.variables[variable_name][:, :, :]
        elif variable_dim == 3:
            block = ds.variables[variable_name][:, :, :, :]
        else:
            raise ValueError("Bad variable dimension in extract_time_block.")
    return block


def open_output_netcdf(output_file, grid_file, variable_name, variable_dim, total_time_size):
    """
    Initializes the final NetCDF file for the reconstructed filtered field.

    Args:
        output_file (str): Path for output file.
        grid_file (str): Reference NetCDF file for dimensions/coordinates.
        variable_name (str): Variable name.
        variable_dim (int): Number of dimensions (2 or 3).
        total_time_size (int): Total time dimension length.

    Returns:
        nc_file: Opened NetCDF dataset ready to write.
    """
    ref = nc.Dataset(grid_file, 'r')

    nc_file = nc.Dataset(output_file, 'w', format='NETCDF4')

    # Create dimensions
    nc_file.createDimension('time_counter', total_time_size)
    if variable_dim == 2:
        nc_file.createDimension('y', len(ref.dimensions['y']))
        nc_file.createDimension('x', len(ref.dimensions['x']))
    elif variable_dim == 3:
        nc_file.createDimension('deptht', len(ref.dimensions['deptht']))
        nc_file.createDimension('y', len(ref.dimensions['y']))
        nc_file.createDimension('x', len(ref.dimensions['x']))

    # Create variables
    time_var = nc_file.createVariable('time_counter', 'f8', ('time_counter',))
    lat_var = nc_file.createVariable('nav_lat', 'f4', ('y', 'x'))
    lon_var = nc_file.createVariable('nav_lon', 'f4', ('y', 'x'))
    if variable_dim == 3:
        depth_var = nc_file.createVariable('deptht', 'f4', ('deptht',))

    # Create main variable
    if variable_dim == 2:
        var = nc_file.createVariable(variable_name, 'f4', ('time_counter', 'y', 'x'), fill_value=1.e20)
    elif variable_dim == 3:
        var = nc_file.createVariable(variable_name, 'f4', ('time_counter', 'deptht', 'y', 'x'), fill_value=1.e20)

    var.setncattr('missing_value', 1.e20)

    # Copy coordinates
    if 'time_counter' in ref.variables:
        time_var[:] = np.zeros(total_time_size)  # Will fill later
    lat_var[:, :] = ref.variables['nav_lat'][:, :]
    lon_var[:, :] = ref.variables['nav_lon'][:, :]
    if variable_dim == 3:
        depth_var[:] = ref.variables['deptht'][:]

    ref.close()
    return nc_file


def save_time_block(nc_file, variable_name, variable_dim, t0, t1, block, time_values):
    """
    Saves a filtered time block into the reconstructed NetCDF file.

    Args:
        nc_file: Opened NetCDF dataset.
        variable_name (str): Name of variable.
        variable_dim (int): Dimensionality.
        t0 (int): Start index in time.
        t1 (int): End index in time.
        block: numpy array of data.
        time_values: corresponding time values.
    """
    print(f"Writing block {t0}:{t1}")
    if variable_dim == 2:
        nc_file.variables[variable_name][t0:t1, :, :] = block
    elif variable_dim == 3:
        nc_file.variables[variable_name][t0:t1, :, :, :] = block

    nc_file.variables['time_counter'][t0:t1] = time_values


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reconstruct low-frequency field from temporally chunked, spatially filtered NetCDF files.")
    parser.add_argument('netcdf_files', nargs='+', help='List of the NetCDF files to recomb.')
    parser.add_argument('--variable_name', required=True, help='Variable name in the NetCDF files.')
    parser.add_argument('--grid_file', type=str, required=True, help='reference file for lat-lon coordinate')
    parser.add_argument('--variable_dim', type=int, required=True, help='Variable dimensionality (2 or 3).')
    parser.add_argument('--output_file', required=True, help='Path to the reconstructed output NetCDF file.')
    args = parser.parse_args()

    # Sort input files to ensure time order
    files = sorted(args.netcdf_files)
    # Estimate total time length
    total_time = 0
    for f in files:
        with nc.Dataset(f, 'r') as ds:
            print(f,ds.dimensions)
            total_time += ds.dimensions['time'].size
    print(total_time)
    # Initialize output file using the first one as reference
    nc_out = open_output_netcdf(args.output_file, args.grid_file, args.variable_name, args.variable_dim, total_time)

    # Rebuild field
    t_start = 0
    for f in files:
        with nc.Dataset(f, 'r') as ds:
            ntime = len(ds.dimensions['time'])
            block = ds.variables[args.variable_name][:]
            time_vals = ds.variables['time'][:] if 'time' in ds.variables else np.arange(ntime)
        t_end = t_start + ntime
        save_time_block(nc_out, args.variable_name, args.variable_dim, t_start, t_end, block, time_vals)
        t_start = t_end

    nc_out.close()
    print(f"Reconstruction done: {args.output_file}")
