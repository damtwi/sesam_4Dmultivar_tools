#!/bin/bash
#SBATCH --job-name=prepro
#SBATCH -e reduce.e%j
#SBATCH -o reduce.o%j
#SBATCH --time=00:30:00
#SBATCH -A egi@cpu
##SBATCH --partition=prepost
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev



# Boucle sur les membres de l'ensemble
for i in $(seq -w 8 9); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"

    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    . ./${PARAM_FILE}
    cd $wdir

    ensdir="ENS${ens_size}"

    obsname="PseudoObs_${scenario}/obs"
    obsname="redobs"
    # Compute observation equivalent of multiscale input ensemble

    idir1="RED_1_ENS${ens_size}.cpak.bas"
    idir2="RED_2_ENS${ens_size}.cpak.bas"
    idir1obs="RED_1_ENS${ens_size}.cobs.bas"
    odir1obstag="RED_1_ENS${ens_size}-${loc_dir_tag}prior.obs.bas"

    idir2obs="RED_2_ENS${ens_size}.cobs.bas"
    odir2obstag="RED_2_ENS${ens_size}-${loc_dir_tag}.obs.bas"

    echo "$ensdir,${obsname},${ensdir}mean,${wdir}"
    echo "${idir1obs},${idir1},${idir1obs}"
    echo "${idir2obs},${idir2},${idir2obs}"
    rm -fr $idir1obs ; mkdir $idir1obs
    $sesam -mode intf -inobas $idir1 -outobas $idir1obs -configobs ${obsname}#.cobs
    rm -fr $idir2obs ; mkdir $idir2obs
    $sesam -mode intf -inobas $idir2 -outobas $idir2obs -configobs ${obsname}#.cobs
    
    $sesam  -mode obsv -inobs $idir1obs/vct#0001.cobs -configobs $idir1obs/vct#0001.cobs -outdta $idir1obs/vtc0001.cdta
    
    cp $sdir/${PARAM_FILE} $wdir/RED_2_ENS${ens_size}.cobs.bas/.
    cp $sdir/${PARAM_FILE} $wdir/RED_1_ENS${ens_size}.cobs.bas/.
    
    rm -fr ${odir2obstag}
    mv ${idir2obs} ${odir2obstag}
    rm -fr ${odir1obstag}
    mv ${idir1obs} ${odir1obstag}
    ln -sf ${odir2obstag} ${idir2obs}
    ln -sf ${odir1obstag} ${idir1obs}
