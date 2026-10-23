#!/bin/bash
#SBATCH --job-name=drawsample
#SBATCH -e drawsample.e%j
#SBATCH -o drawsample.o%j
#SBATCH --ntasks=120
#SBATCH --ntasks-per-node=20
#SBATCH --time=02:00:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev


# =============================================================================
# Draw random localization sample fields with a prescribed spectrum.
#
# This script creates the ensemble of random fields whose spatial correlation 
# use for the localization in the MCMC algorithm. It follow the  scales set in param.bash.
#
# =============================================================================


module purge
module load intel-all/19.0.4
module load hdf5/1.8.21-mpi
module load netcdf/4.7.2-mpi
module load netcdf-fortran/4.5.2-mpi
module load netcdf-cxx4/4.3.1-mpi

. ./param.bash

cd $wdir

odirbas="RED_2_ENS${ens_size}.cpak.bas"
odirbastag="RED_2_ENS${ens_size}-${loc_dir_tag}.cpak.bas"

# Prepare sesamlist with localization scales
cp sesamlist sesamlist_loc
echo "LOC_TIME_SCALE=$loc_time_scale" >> sesamlist_loc
echo "LOC_RADIUS_IN_DEG=$loc_radius"  >> sesamlist_loc

# Sample random fields with required spectrum
rm -fr ${odirbas} ; mkdir ${odirbas}
srun $sesam -mode spct -inxbas ${odirbas} -outxbas ${odirbas} -typeoper R_${loc_lmax} -config sesamlist_loc

rm -fr ${odirbastag}
mv ${odirbas} ${odirbastag}
ln -sf ${odirbastag} ${odirbas}

rm -f sesamlist_loc
