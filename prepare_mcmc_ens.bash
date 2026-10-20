#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"

# Boucle sur les membres de l'ensemble
for i in $(seq -w 1 2); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"

    # # launch the inversion script
    # jobid=$(sbatch --parsable \
    # 		   --job-name=redp_${xt} \
    # 		   -o logs/mcmc_${xt}.o%j \
    # 		   -e logs/mcmc_${xt}.e%j \
    # 		   update_mcmc_gpu_ens.bash "$PARAM_FILE")

    # launch the inversion script
    jobid=$(sbatch --parsable \
		   --job-name=redp_${xt} \
		   -o logs/mcmc_${xt}.o%j \
		   -e logs/mcmc_${xt}.e%j \
		   update_mcmc_gpu_ens.bash "$PARAM_FILE")

done
