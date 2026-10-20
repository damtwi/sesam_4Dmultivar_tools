#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"

# Boucle sur les membres de l'ensemble
for i in $(seq -w 1 10); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"

    jobid=$(sbatch --parsable \
		   --job-name=score_${xt} \
		   -o logs/score_${xt}.o%j \
		   -e logs/score_${xt}.e%j \
		   check_score_global_ens.bash "$PARAM_FILE")

done
