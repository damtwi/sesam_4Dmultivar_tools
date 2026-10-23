#!/bin/bash
#SBATCH --time=00:05:00
#SBATCH -A egi@cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

# =============================================================================
# Submit sequential preprocessing jobs for each ensemble member.
#
# For each member in [mem0, mem1], this script:
#   1. Submits the prior ensemble reduction and statistics calculation.
#   2. Submits the observation reduction after the prior job completes.
#   3. Submits the ensemble observation reduction after the observation job
#      completes.
# =============================================================================

# Base paths
PARAM_TEMPLATE="param.bash"
jobid=""
# Loop over ensemble members
for i in $(seq -w $mem0 $mem1); do    
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"

    #to load the wdir
    ./"${PARAM_TEMPLATE}"

    # Copy param.bash to param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"

    # Update memxt and wdir in param{xt}.bash
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"
    # Append the member index to wdir="$SCRATCH/SNOOPI/ExpEns"
    # Assumes that the parent directory $SCRATCH/SNOOPI/ExpEns exists
    WDIR_SUB="$wdir/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"

    # Reduce the prior ensemble and calculate the standard deviation and mean
    jobid=$(sbatch --parsable \
		   --job-name=redp_${xt} \
		   -o logs/redprior_${xt}.o%j \
		   -e logs/redprior_${xt}.e%j \
		   prepro_reduce_prior.bash "$PARAM_FILE")
    echo "PWD: $(pwd)"
    echo $jobid
    # Reduce the observations
    jobid2=$(sbatch --parsable \
		    --dependency=afterok:$jobid \
		    --job-name=redobs_${xt} \
		    -o logs/redobs_${xt}.o%j \
		    -e logs/redobs_${xt}.e%j \
		    prepro_reduce_pseudoobs.bash "$PARAM_FILE")

    # Extract observations from the red1 and red2 ensembles
    # !the param.bash is read inside prepro_obs_ens.bash
    jobid3=$(sbatch --parsable \
		    --dependency=afterok:$jobid2 \
		    --job-name=redp_${xt} \
		    -o logs/red2_${xt}.o%j \
		    -e logs/red2_${xt}.e%j \
		    prepro_obs_ens.bash "$PARAM_FILE")    
    echo "### Member $xt ready ###"

done
