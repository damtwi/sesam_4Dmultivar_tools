import xarray as xr
import numpy as np
# wdir="/lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/Exp3Dso/"
# Liste des variables à traiter
variables = ['vosaline', 'votemper', 'sossheig']
# variables = [ 'sossheig']

# Dictionnaire pour stocker les DataArrays de bruit
noise_dict = {}
alpha=1
for var in variables:
    noise_dict = {}
    print(var)
    # Charger le fichier NetCDF correspondant à la std temporelle
    ds_std = xr.open_dataset(f"ENS0030std_{var}_hf.nc")
    
    # Extraire la std
    std_var = ds_std[var]  # shape = (time_counter, deptht, y, x)
    
    # Générer un bruit gaussien aléatoire centré sur 0
    noise = xr.DataArray(
        np.random.normal(loc=0.0, scale=alpha * std_var),
        dims=std_var.dims,
        coords=std_var.coords,
        name=f"{var}"
    )
    
    noise_dict[f"{var}"] = noise

    # Créer un nouveau Dataset à partir des DataArrays
    ds_noise = xr.Dataset(noise_dict)

    # # Ajouter éventuellement les coordonnées de temps et profondeur (provenant de l'un des fichiers)
    # ds_noise['time_counter'] = ds_std['time_counter']
    # ds_noise['deptht'] = ds_std['deptht']
    # ds_noise['nav_lat'] = ds_std['nav_lat']
    # ds_noise['nav_lon'] = ds_std['nav_lon']
    
    # Sauvegarder dans un nouveau NetCDF
    ds_noise.to_netcdf(f"noise_basin3d_{var}_hf.nc")
