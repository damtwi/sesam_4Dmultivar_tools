#!/bin/bash
#SBATCH --job-name=postpro
#SBATCH -e logs/postpro.e%j
#SBATCH -o logs/postpro.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=5:30:00            # Maximum execution time (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --partition=prepost
##SBATCH --qos=qos_cpu-dev

# -----------------------------------------------------------------------------
# Post-process the ensemble for each member.
# Reconstruct the ensemble fields from the reduced perturbations, then compute
# the sample mean and standard deviation using SESAM.
# -----------------------------------------------------------------------------


PARAM_TEMPLATE="param.bash"
date

# Process each ensemble member using its specific configuration
for i in $(seq -w $mem0 $mem1); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"

    # Create a member-specific parameter file
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"

    # Set the current member and its working directory
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"
    WDIR_SUB="$wdir/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"

    # Load the member-specific configuration and enter its working directory
    . ./${PARAM_FILE}
    cd $wdir

    smpensdir="${expt}SMPENS${upd_size}"
    rm -rf ${smpensdir}.nc.bas
    mkdir ${smpensdir}.nc.bas

    # Convert the prior ensemble mean and standard deviation to SESAM format
    $sesam -mode intf -invar ${ensdir}std#.nc -outvar ${ensdir}std.cpak
    $sesam -mode intf -invar ${ensdir}mean#.nc -outvar ${ensdir}mean.cpak

    # Save the configuration alongside the reconstructed ensemble
    cp ${sdir}/${PARAM_FILE} ${smpensdir}.nc.bas/.

    # Reconstruct each updated member from the reduced perturbation
    # by rescaling it with the prior standard deviation and adding the prior mean
    member=1
    while [ $member -le ${upd_size} ] ; do
        membertag4=`echo $member | awk '{printf("%04d", $1)}'`

        ifile="RED_1_${smpensdir}.cpak.bas/vct${membertag4}.cpak"
        ofile="${smpensdir}.nc.bas/vct#${membertag4}.nc"
        echo $ifile $ofile

        rm -f tmpred1.cpak
        $sesam -mode oper -invar $ifile -invarref ${ensdir}std.cpak -outvar tmpred1.cpak -typeoper x
        $sesam -mode oper -invar tmpred1.cpak -invarref ${ensdir}mean.cpak -outvar $ofile -typeoper +
        rm -f tmpred1.cpak

        let member=$member+1
    done

    # Convert the reconstructed ensemble to SESAM's ensemble format cpak
    mkdir ${smpensdir}.cpak.bas
    $sesam -mode intf -inxbas ${smpensdir}.nc.bas -outxbas ${smpensdir}.cpak.bas

    # Build the configuration file listing all reconstructed members
    rm -f list.cfg
    echo $upd_size > list.cfg
    let member=1
    while [ $member -le ${upd_size} ] ; do
        membertag4=`echo $member | awk '{printf("%04d", $1)}'`
        ifile="${smpensdir}.nc.bas/vct#${membertag4}.nc"
        echo $ifile >> list.cfg
        let member=$member+1
    done

    # Compute the sample standard deviation and mean of the reconstructed ensemble
    rm -f ${smpensdir}std*.nc
    rm -f ${smpensdir}mean*.nc
    $sesam -mode oper -incfg list.cfg -outvar ${smpensdir}std#.nc -typeoper std
    $sesam -mode oper -incfg list.cfg -outvar ${smpensdir}mean#.nc -typeoper mean

    # Remove temporary files and return to the submission directory
    rm -f list.cfg
    cd $sdir
done
date
