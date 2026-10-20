#!/bin/bash
#SBATCH --job-name=postpro
#SBATCH -e logs/postpro.e%j
#SBATCH -o logs/postpro.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=5:30:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --partition=prepost
##SBATCH --qos=qos_cpu-dev
PARAM_TEMPLATE="param0-300.bash"
date
let i=2
for i in 11 13 15 17 19; do    

    xt=$(printf "%02d" $((10#$i)))    
    echo "#### member $xt ####"
    
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
        
    smpensdir="${expt}SMPENS${upd_size}"
    rm -rf ${smpensdir}.nc.bas
    mkdir ${smpensdir}.nc.bas
    
    $sesam -mode intf -invar ${ensdir}std#.nc -outvar ${ensdir}std.cpak
    $sesam -mode intf -invar ${ensdir}mean#.nc -outvar ${ensdir}mean.cpak
    
    cp ${sdir}/${PARAM_FILE} ${smpensdir}.nc.bas/.
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
    

    mkdir ${smpensdir}.cpak.bas
    $sesam -mode intf -inxbas ${smpensdir}.nc.bas -outxbas ${smpensdir}.cpak.bas
    # Compute sample mean and standard deviation
    rm -f list.cfg
    echo $upd_size > list.cfg
    let member=1
    while [ $member -le ${upd_size} ] ; do
	membertag4=`echo $member | awk '{printf("%04d", $1)}'`
	ifile="${smpensdir}.nc.bas/vct#${membertag4}.nc"
	echo $ifile >> list.cfg
	let member=$member+1
    done
    
    rm -f ${smpensdir}std*.nc
    rm -f ${smpensdir}mean*.nc
    $sesam -mode oper -incfg list.cfg -outvar ${smpensdir}std#.nc -typeoper std
    $sesam -mode oper -incfg list.cfg -outvar ${smpensdir}mean#.nc -typeoper mean
    rm -f list.cfg
    cd $sdir
done
date
