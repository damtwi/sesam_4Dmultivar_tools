#!/bin/bash
#SBATCH --time=00:05:00
#SBATCH -A egi@cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

# Chemins de base
PARAM_TEMPLATE="param0-300.bash"
#3 4 5 done, 1 and 2 error in fullobs
jobid=""
# Boucle sur les membres de l'ensemble
for i in 25 27 30; do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    
    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"
    
    # Modifier memxt et wdir à l'intérieur du param{xt}.bash
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"
    # wdir="$SCRATCH/SNOOPI/ExpEns" -> ajouter le sous-dossier xt
    # On suppose que le dossier parent $SCRATCH/SNOOPI/ExpEns existe
    WDIR_SUB="$SCRATCH/SNOOPI/ExpEns/$xt"    
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"
    
    # Reduce the prior ensemble & calculation of std/mean
    jobid=$(sbatch --parsable \
		   --job-name=redp_${xt} \
		   -o logs/redprior_${xt}.o%j \
		   -e logs/redprior_${xt}.e%j \
		   prepro_reduce_prior.bash "$PARAM_FILE")
    echo "PWD: $(pwd)"
    echo $jobid
    # Reduce the observation
    # --dependency=afterok:$jobid \
    jobid2=$(sbatch --parsable \
		    --dependency=afterok:$jobid \
		    --job-name=redobs_${xt} \
		    -o logs/redobs_${xt}.o%j \
		    -e logs/redobs_${xt}.e%j \
		    prepro_reduce_obs.bash "$PARAM_FILE")
    
    # # Extract obs from red1 & red2 ensemble
    # 		    # --dependency=afterok:$jobid2 \
    jobid3=$(sbatch --parsable \
		    --dependency=afterok:$jobid2 \
		    --job-name=redp_${xt} \
		    -o logs/red2_${xt}.o%j \
		    -e logs/red2_${xt}.e%j \
		    prepro_mcmc_ens.bash "$PARAM_FILE")    
    echo "### Member $xt ready ###"
    
done
