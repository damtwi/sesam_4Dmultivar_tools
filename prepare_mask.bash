#!/bin/bash

. ./param.bash

cd $wdir

# python resampled.py "${datadir}/${membertag3}ENS04_votemper_concat.nc" "${datadir}/${membertag3}ENS04_sossheig_temp.nc"
    # Extraction spatiale et temporelle
bigfile="/lustre/fsn1/projects/rech/egi/utw56cf/mesh_mask_MED12_v75.nc"
rm "grid_sossheig.nc"
ofile="grid_sossheig.nc"
ncks -O \
     -d x,${imin},${imax} \
     -d y,${jmin},${jmax} \
     -v time_counter,nav_lon,nav_lat \
     $bigfile $ofile
ncrename -d t,time_counter $ofile
ncks -A -v sossheig,time_counter mask_sossheig.nc $ofile
# ncks -A -v nav_lon,nav_lat mesh_mask_MED12_v75.nc grid.nc

# ncks -A -v time_counter "mask_sossheig.nc" $ofile
# ncks -A -v time_counter "mask_sossheig.nc" $ofile


