#!/bin/bash
#SBATCH --job-name=checkscore
#SBATCH -e logs/checkscore.e%j
#SBATCH -o logs/checkscore.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=0:45:00            # Maximum execution time (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
##SBATCH --qos=qos_cpu-dev
#SBATCH --qos=qos_cpu-dev



# =============================================================================
# Compute probabilistic scores for the posterior and prior ensembles.
#
# For each Nature Run, this script:
#   1. Loads the member-specific configuration.
#   2. Converts the Nature Run reference field to SESAM format.
#   3. Computes CRPS and RCRV scores at each vertical level.
#   4. Evaluates both the MCMC-updated ensemble and the reference ensemble.
#   5. Converts the score outputs into tabular files for further analysis.
#
# The scores are computed over predefined spatial partitions at each depth.
# =============================================================================



PARAM_TEMPLATE="param.bash"

jobid=""
# Loop over all Nature Runs defined by the member range in param.bash
for i in $(seq -w $mem0 $mem1); do
    date

    # Load the main configuration to initialize the working directory and parameters
    ./"${PARAM_TEMPLATE}"

    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"

    # Create a member-specific parameter file
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"

    # Set the current Nature Run identifier and its working directory
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"
    WDIR_SUB="$wdir/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"

    # Load the member-specific configuration and enter its working directory
    . ./${PARAM_FILE}
    cd $wdir

    # Convert the Nature Run reference field to SESAM format
    $sesam -mode intf -invar xt#.nc -outvar xt_prior.cpak

    # Define the updated ensemble directory and reset the score output files
    diagensdir="${expt}SMPENS${upd_size}"
    rm ${diagensdir}_ens_crps_all.txt
    rm ${diagensdir}_ens_rcrv_all.txt

    # Loop over all 75 vertical levels
    for idepth in $(seq 1 75); do
        # Link the spatial partitions associated with the current depth
        ln -s /lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/ExpEns/01/rms_test${idepth}*.cpak .
        echo $idepth

        # Record the current depth in the posterior score files
        echo "idepth=$idepth" >> ${diagensdir}_ens_rcrv_all.txt
        echo "idepth=$idepth" >> ${diagensdir}_ens_crps_all.txt

        # Compute CRPS and RCRV for the MCMC-updated ensemble
        $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_prior.cpak -typeoper crps -inpartvar rms_test${idepth}.cpak >> ${diagensdir}_ens_crps_all.txt
        $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_prior.cpak -typeoper rcrv -inpartvar rms_test${idepth}.cpak >> ${diagensdir}_ens_rcrv_all.txt

        # Evaluate the reference ensemble using the same Nature Run
        diagensdir="ENS${upd_size}"
        echo "idepth=$idepth" >> ${diagensdir}_ens_rcrv_all.txt
        echo "idepth=$idepth" >> ${diagensdir}_ens_crps_all.txt
        $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper crps -inpartvar rms_test.cpak >> ${diagensdir}_ens_crps_all.txt
        $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper rcrv -inpartvar rms_test.cpak >> ${diagensdir}_ens_rcrv_all.txt

        date
    done

    # convert the score outputs to tables
    cd $sdir
    python3 convert_tabs_crps.py --expmcmc ${expt} --repertory $wdir

    # Convert also the prior ensemble scores for comparison
    expt_ref="PRIOR"
    python3 convert_tabs_crps.py --expmcmc ${expt_ref} --repertory $wdir

done
