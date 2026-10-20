import argparse
import netCDF4 as nc
import numpy as np
"""
Recombine rank-specific NetCDF files into a single file covering the full
longitude domain for each variable and ensemble member.

Grid coordinates are copied from a reference NetCDF file. The time dimension
is adjusted according to the variable dimensionality and the filtering
configuration.
"""


def extract_block(netcdf_file, variable_name, variable_dim):
    """
    Extracts a contiguous block of time series 
    from a series of successive 4D NetCDF files based on provided indices.
    
    Args:
    netcdf_file (list): NetCDF file with block to extract.
    variable_name (str): Name of the variable in the NetCDF file.
    variable_dim (int): Dimension of variable in the NetCDF file (2 or 3).
    
    Returns:
    block: extrcated block of data
    """
    # Open the NetCDF file
    nc_data = nc.Dataset(netcdf_file, 'r')

    # Extract time series based on provided indices
    if variable_dim==2:
      block = nc_data.variables[variable_name][:, :, :]
    elif variable_dim==3:
      block = nc_data.variables[variable_name][1:-1, :, :, :]
    else:
      raise ValueError("Bad variable dimension in extract_time_series.")

    # Close the NetCDF file
    nc_data.close()

    return block

def open_netcdf(ofile, grid_file, variable_name, variable_dim,
                longitude_size, lanczos_window, freq):
    """
    Args:
    filename (str): Output file prefix for the recombined NetCDF file.
    grid_file (str): Reference NetCDF file providing grid coordinates.
    variable_name (str): Name of the variable to recombine.
    variable_dim (int): Variable dimensionality (2 for surface fields, 3 for 3D fields).
    longitude_size (int): Number of longitude points in the output domain.
    lanczos_window (str): Lanczos filter window identifier used in input filenames.
    freq (str): Filter frequency identifier used in input filenames (e.g. "hf" or "lf").
    
    Returns:
    netCDF4.Dataset: Open output NetCDF dataset to be filled with the recombined blocks.
    """

    # --- Open reference files ---
    nc_file = nc.Dataset(ofile + "lanczos_" + lanczos_window + freq + ".nc",
                         'w', format='NETCDF4')
    nc_file_ref = nc.Dataset(ofile + '0000lanczos_' + lanczos_window + freq + ".nc",
                             'r', format='NETCDF4')
    nc_file_glo = nc.Dataset(grid_file, 'r', format='NETCDF4')

    # --- Determine new time dimension ---
    time_len_ref = nc_file_ref.dimensions['time'].size

    if variable_dim == 2:
        # SSH → remove first 2 steps
        new_time = time_len_ref 
    elif variable_dim == 3:
        # 3D fields → remove first step
        new_time = time_len_ref - 2
    else:
        raise ValueError("variable_dim must be 2 or 3")

    # --- Create dimensions ---
    nc_file.createDimension('time_counter', new_time)

    if variable_dim == 2:
        nc_file.createDimension('y', nc_file_ref.dimensions['lat'].size)
        nc_file.createDimension('x', longitude_size)

    elif variable_dim == 3:
        nc_file.createDimension('deptht', nc_file_ref.dimensions['depth'].size)
        nc_file.createDimension('y', nc_file_ref.dimensions['lat'].size)
        nc_file.createDimension('x', longitude_size)

    # --- Create variables ---
    time_var = nc_file.createVariable('time_counter', 'f8', ('time_counter',))

    if variable_dim == 3:
        depth_var = nc_file.createVariable('deptht', 'f4', ('deptht',))

    lat_var = nc_file.createVariable('nav_lat', 'f4', ('y', 'x'))
    lon_var = nc_file.createVariable('nav_lon', 'f4', ('y', 'x'))

    if variable_dim == 2:
        var = nc_file.createVariable(
            variable_name, 'f4',
            ('time_counter', 'y', 'x'),
            fill_value=1.e+20
        )
    else:
        var = nc_file.createVariable(
            variable_name, 'f4',
            ('time_counter', 'deptht', 'y', 'x'),
            fill_value=1.e+20
        )
    var.setncattr('missing_value', 1.e+20)

    # --- Fill coordinate values ---
    time_var[:] = nc_file_ref.variables['time'][:] 
    lat_var[:, :] = nc_file_glo.variables['nav_lat'][:, :]
    lon_var[:, :] = nc_file_glo.variables['nav_lon'][:, :]

    if variable_dim == 3:
        depth_var[:] = nc_file_glo.variables['deptht'][:]

    return nc_file



def save_block(nc_file, variable_name, variable_dim, lon_index_start, lon_index_end, block):
    """
    Saves block and time series to a NetCDF file.
    
    Args:
    nc_file : NetCDF dataset
    variable_name (str): Name of the variable.
    variable_dim (int): dimension of the variable.
    lon_index_start (int): Starting index of the longitude coordinate.
    lon_index_end (int): Ending index of the longitude coordinate.
    block: block of data to write.
    """
    # print(lon_index_start,lon_index_end)
    # Write block in file
    if variable_dim==2:
      for lonblock in range(lon_index_end-lon_index_start+1):
          lon = lon_index_start-1+lonblock
          nc_file.variables[variable_name][:, :, lon] = block[:,:,lonblock]
    elif variable_dim==3:
      for lonblock in range(lon_index_end-lon_index_start+1):
        lon = lon_index_start-1+lonblock
        nc_file.variables[variable_name][:, :, :, lon] = block[:,:,:,lonblock]

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Extract time series from a series of NetCDF files, apply Lanczos filter, and save to NetCDF file.')
    parser.add_argument('--variable_name', type=str, required=True, help='Name of the variable in the NetCDF file')
    parser.add_argument('--variable_dim', type=int, required=True, help='Dimension of the variable in the NetCDF file')
    parser.add_argument('--lon_index_start', type=int, required=True, help='Starting index of the longitude coordinate')
    parser.add_argument('--lon_index_end', type=int, required=True, help='Ending index of the longitude coordinate')
    parser.add_argument('--grid_file', type=str, required=True, help='reference file for lat-lon coordinate')
    parser.add_argument('--num_blocks', type=int, required=True, help='Number of longitue blocks (by processor if MPI)')
    parser.add_argument('--inout_path', type=str, required=True, help='prefix of the output & input NetCDF file')
    parser.add_argument('--freq', type=str, required=True, help='Name of the freq to save')
    parser.add_argument('--window', type=str, required=True, help='lanczos window')
    args = parser.parse_args()
    
    # Number of blocks
    mpisize = args.num_blocks
    # Block size
    mpiblocksize = 1 + (args.lon_index_end - args.lon_index_start)//mpisize
    lanczos_window=args.window
    # Initialize output NetCDF file
    ofile = args.inout_path
    longitude_size = args.lon_index_end - args.lon_index_start + 1
    print("lon size:",longitude_size)
    grid_file = args.grid_file
    nc_file = open_netcdf(ofile, grid_file, args.variable_name, args.variable_dim, longitude_size,lanczos_window,args.freq)

    # Loop on blocks, read and write blocks of longitudes
    for mpirank in range(mpisize):

       lon0 = args.lon_index_start + mpirank*mpiblocksize
       lon1 = min(lon0 + mpiblocksize - 1,args.lon_index_end)

       print('Block:',mpirank,lon0,lon1)

       # Extract block
       ifile = ofile + f'{mpirank:0>4}lanczos_'+lanczos_window+args.freq+".nc"
       block = extract_block(ifile, args.variable_name, args.variable_dim)

       # Save block
       save_block(nc_file, args.variable_name, args.variable_dim, lon0, lon1, block)

    # Close the NetCDF file
    nc_file.close()

