#!/bin/bash
#SBATCH --job-name=checkscore
#SBATCH -e checkscore.e%j
#SBATCH -o checkscore.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=03:00:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev
#SBATCH --qos=qos_cpu-t3



# Copier param.bash en param{xt}.bash
PARAM_FILE=${1:-param.bash}
. ./$PARAM_FILE

cd $wdir
expt_ref="200-90-1500FullObs"
echo $expt_ref

rm -rf RMS_FILES
mkdir RMS_FILES
ln -sf /lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/Exp3D/rmspart*.nc RMS_FILES/.
diagensdir="${expt_ref}SMPENS${upd_size}"
# $sesam -mode intf -inxbas ${diagensdir}.nc.bas -outxbas ${diagensdir}.cpak.bas
$sesam -mode intf -invar xt#.nc -outvar xt_test.cpak
for idepth in $(seq 1 63); do
    rm -f rms_test.cpak
    $sesam -mode intf -invar RMS_FILES/rmspart${idepth}#.nc -outvar rms_test.cpak
    echo $idepth
    diagensdir="${expt_ref}SMPENS${upd_size}"
    echo "idepth=$idepth" >> ${diagensdir}_ens_rcrv_all.txt
    echo "idepth=$idepth" >> ${diagensdir}_ens_crps_all.txt
    $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper crps  -inpartvar rms_test.cpak  >> ${diagensdir}_ens_crps_all.txt
    $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper rcrv  -inpartvar rms_test.cpak  >> ${diagensdir}_ens_rcrv_all.txt

    diagensdir="ENS${upd_size}"
    echo "idepth=$idepth" >> ${diagensdir}_ens_rcrv_all.txt
    echo "idepth=$idepth" >> ${diagensdir}_ens_crps_all.txt
    $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper crps  -inpartvar rms_test.cpak  >> ${diagensdir}_ens_crps_all.txt
    $sesam -mode scor -inxbas ${diagensdir}.cpak.bas -invar xt_test.cpak -typeoper rcrv  -inpartvar rms_test.cpak  >> ${diagensdir}_ens_rcrv_all.txt
done

# cd $sdir
# python3 convert_tabs_crps.py --expmcmc ${expt} --repertory $wdir

# expt_ref="PRIOR"
# python3 convert_tabs_crps.py --expmcmc ${expt_ref} --repertory $wdir
