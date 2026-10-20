#!/bin/bash
#SBATCH --job-name=prepareobs
#SBATCH -e prepareobs.e%j
#SBATCH -o prepareobs.o%j
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:45:15            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

. ./param.bash

cd $wdir

cp sesamlist sesamlist_obs
for i in 2 3
do
    for j in 1 2 3
    do
        echo "OBS_DEP_MIN-${i}:${j}=1500." >> sesamlist_obs
        echo "OBS_DEP_MAX-${i}:${j}=2500." >> sesamlist_obs
    done
done

# for sat in $obs_satlist ; do
#     case "$sat" in
# 	h2ag) sat_tag="_h2ag" ;;
# 	tgli) sat_tag="_tgli" ;;
# 	sgli) sat_tag="_sgli" ;;
# 	tctd) sat_tag="_tctd" ;;
# 	sctd) sat_tag="_sctd" ;;
# 	*)    sat_tag="_${sat}_" ;;
#     esac
	
#     dbsfile="Obs_dbs/obs${sat_tag}.ncdbs"
#     # Generate observation file
#     rm -f ${obssat}${sat_tag}.cobs
#     $sesam -mode obsv -indbs ${dbsfile} -outobs ${obssat}#.cobs -affectobs $sat_tag -config sesamlist_obs    
# done

obsname="Obs_arg_z${zmin}-${zmax}"
if [ ! -d ${obsname} ] ; then
  mkdir ${obsname}
fi
rm ${obsname}/*
$sesam -mode obsv -indbs argo_2018_golfe_lion.adbs -outobs ${obsname}/obs#.cobs -affectobs _sarg -config sesamlist_obs
$sesam -mode obsv -indbs argo_2018_golfe_lion.adbs -outobs ${obsname}/obs#.cobs -affectobs _arg_ -config sesamlist_obs

obsname="Obs_gli_z${zmin}-${zmax}"
if [ ! -d ${obsname} ] ; then
  mkdir ${obsname}
fi
rm ${obsname}/*
$sesam -mode obsv -indbs all_gliders_2010_2020.ncdbs -outobs Obs_gli/obs#.cobs -affectobs "_gli_" -config sesamlist_obs
$sesam -mode obsv -indbs all_gliders_2010_2020.ncdbs -outobs Obs_gli/obs#.cobs -affectobs "_sgli" -config sesamlist_obs


bsname="Obs_ctd_z${zmin}-${zmax}"
if [ ! -d ${obsname} ] ; then
  mkdir ${obsname}
fi
rm ${obsname}/*
rm -rf "Obs_ctd24j/"*.cobs      	
$sesam -mode obsv -indbs MGE_24j_alldepth.adbs -outobs "Obs_ctd24j/"obs#.cobs -affectobs _sctd -config sesamlist_obs
$sesam -mode obsv -indbs MGE_24j_alldepth.adbs -outobs "Obs_ctd24j/"obs#.cobs -affectobs _ctd_ -config sesamlist_obs

# $sesam -mode obsv -indbs MGE_z80-300_24j.adbs -outobs ${obsname}/obs#.cobs -affectobs _ctd_ -config sesamlist_obs
$sesam  -mode obsv -inobs ${obsname}/obs#.cobs -configobs ${obsname}/obs#.cobs -outdta ${obsname}/obs.cdta
