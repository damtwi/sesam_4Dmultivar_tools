#!/bin/bash
#SBATCH --job-name=mcmcsampler
#SBATCH -e logs/mcmc2_.e%j
#SBATCH -o logs/mcmc2_.o%j
#SBATCH --nodes=12
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --time=10:00:00
#SBATCH -A egi@v100

module purge
module load nvidia-compilers/24.3
module load cuda/12.2.0  # not needed before, worked with cuda/12.4.1
module load openmpi/4.0.5-cuda
module load netcdf-fortran/4.5.3-mpi-cuda
#module load hdf5/1.14.5-mpi-cuda
module load hdf5/1.12.0-mpi-cuda

PARAM_TEMPLATE="param0-300.bash"
date
# Boucle sur les membres de l'ensemble
for i in 1 3 5 7 9; do    
    xt=$(printf "%02d" $((10#$i)))    
    echo "#### member $xt ####"

    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"                                                                                                                                                                            

    # Modifier memxt et wdir à l'intérieur du param{xt}.bash
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"

    # On suppose que le dossier parent $SCRATCH/SNOOPI/ExpEns existe
    WDIR_SUB="$SCRATCH/SNOOPI/ExpEns/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"   
    . ./${PARAM_FILE}
    cd $wdir

    # Update sesamlist with MCMC parameters
    cp sesamlist sesamlist_mcmc
    echo "MCMC_ADAP_TYPE=0"                         >> sesamlist_mcmc
    echo "MCMC_SCALE_MULTIPLICITY-1=${scal_mult_1}" >> sesamlist_mcmc
    echo "MCMC_SCALE_MULTIPLICITY-2=${scal_mult_2}" >> sesamlist_mcmc
    echo "MCMC_CONTROL_PRINT=1000"                  >> sesamlist_mcmc
    echo "MCMC_CONVERGENCE_CHECK=1000"              >> sesamlist_mcmc
    
    odir="RED_@_${expt}SMPENS${upd_size}.cpak.bas"
    odirobs="RED_@_${expt}SMPENS${upd_size}.cobs.bas"
    odir1="RED_1_${expt}SMPENS${upd_size}.cpak.bas"
    odirobs1="RED_1_${expt}SMPENS${upd_size}.cobs.bas"
    odir2="RED_2_ENS${upd_size}.cpak.bas"
    odir2_real="RED_2_ENS${upd_size}-${loc_dir_tag}.cpak.bas"
    
    rm -fr ${odir1} ; mkdir ${odir1}
    rm -fr ${odirobs1} ; mkdir ${odirobs1}
    rm -fr ${odir2}
    ln -sf /lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/Exp3D/${odir2_real} ${odir2}
    cp $sdir/${PARAM_FILE} $odir1
    echo "${odirobs},${odirobs1},$sdir,RED_@_ENS${ens_size}.cpak.bas,$niter,${ens_size},${odirobs}"
    srun /gpfslocalsup/pub/idrtools/bind_gpu.sh \
	 $sesam_gpu -mode mcmc -inxbas RED_@_ENS${ens_size}.cpak.bas -outxbas ${odir} -iterate $niter \
         -inobs redobs#.cobs -configobs redobs#.cobs -oestd redobs_oestd#.cobs \
         -inobas RED_@_ENS${ens_size}.cobs.bas -outobas ${odirobs} \
         -config sesamlist_mcmc
    cd ${sdir}
done
date
