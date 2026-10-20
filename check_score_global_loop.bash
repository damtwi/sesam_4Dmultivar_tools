#!/bin/bash
#SBATCH --job-name=checkscore
#SBATCH -e logs/checkscore.e%j
#SBATCH -o logs/checkscore.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=0:45:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
##SBATCH --qos=qos_cpu-dev
#SBATCH --qos=qos_cpu-dev


PARAM_TEMPLATE="param.bash"
jobid=""
for i in $(seq -w 1 30); do
    date

    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    
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
    $sesam -mode intf -invar xt#.nc -outvar xt_prior.cpak

    diagensdir="${expt}SMPENS${upd_size}"
    rm ${diagensdir}_ens_crps_all.txt
    rm ${diagensdir}_ens_rcrv_all.txt
    for idepth in $(seq 1 65); do
	ln -s /lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/ExpEns/01/rms_test${idepth}*.cpak .
	# $sesam -mode intf -invar /lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/ExpEns/rmspart${idepth}#.nc -outvar rms_test${idepth}.cpak
	
	echo $idepth
	
	echo "idepth=$idepth" >> ${diagensdir}_ens_rcrv_all.txt
	echo "idepth=$idepth" >> ${diagensdir}_ens_crps_all.txt
	$sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_prior.cpak -typeoper crps  -inpartvar rms_test${idepth}.cpak  >> ${diagensdir}_ens_crps_all.txt
	$sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_prior.cpak -typeoper rcrv  -inpartvar rms_test${idepth}.cpak  >> ${diagensdir}_ens_rcrv_all.txt
	
    date

    done
    
    cd $sdir
    python3 convert_tabs_crps.py --expmcmc ${expt} --repertory $wdir
done 
