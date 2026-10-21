#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"

# Boucle sur les membres de l'ensemble
for i in $(seq -w $mem0 $mem1); do    
    xt=$(printf "%02d" $((10#$i)))
    
    # Copy the parameter template
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"

    # Set the current ensemble member
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"

    # Create a member-specific working directory
    WDIR_SUB="$SCRATCH/SNOOPI/ExpEns/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"
    echo "#### member $xt ####"
    
    # Submit the pseudo-observation preparation job
    sbatch --job-name=obs_xt${xt} \
	   -o logs/obs_${xt}.o%j \
	   -e logs/obs_${xt}.e%j \
	   prepare_pseudoobs_ens.bash "$PARAM_FILE"

    # ./cp_pseudoobs_ens.bash "$PARAM_FILE"
    echo "### Member $xt ready ###"
done
