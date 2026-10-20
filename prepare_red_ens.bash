#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"
jobid=""
# Boucle sur les membres de l'ensemble
for i in $(seq -w 30 30); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"


    # Reduce the prior ensemble & calculation of std/mean
    jobid=$(sbatch --parsable \
		   --job-name=redp_${xt} \
		   -o logs/redprior_${xt}.o%j \
		   -e logs/redprior_${xt}.e%j \
		   prepro_reduce_prior.bash "$PARAM_FILE")
    
    echo "PWD: $(pwd)"
    echo $jobid
    # Reduce the observation
    jobid2=$(sbatch --parsable \
		    --dependency=afterok:$jobid \
		    --job-name=redo_${xt} \
		    -o logs/redobs_${xt}.o%j \
		    -e logs/redobs_${xt}.e%j \
		    prepro_reduce_obs.bash "$PARAM_FILE")
    
    # Extract obs from red1 & red2 ensemble
    jobid3=$(sbatch --parsable \
		    --dependency=afterok:$jobid2 \
		    --job-name=redp_${xt} \
		    -o logs/red2_${xt}.o%j \
		    -e logs/red2_${xt}.e%j \
		    prepro_mcmc_ens.bash "$PARAM_FILE")
    
    echo "### Member $xt ready ###"
done
