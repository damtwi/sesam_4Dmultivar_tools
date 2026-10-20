#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"
PREPARE_SCRIPT="prepro_reduce_obs.bash"
sdir="/linkhome/rech/genige01/utw56cf/SNOOPI/Run_ExpEns"

# Boucle sur les membres de l'ensemble
for i in $(seq -w 5 5); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    . ./${PARAM_FILE}
    cd $wdir
    # rm *tmpnoise*
    # rm *tmpred*
    echo "PWD2: $(pwd)"                                                                                 
    for obsi in "${obs_list[@]}"; do
	pseudoobstp="PseudoObs_${obsi}/obs"
	echo $pseudoobstp
	rm ${pseudoobstp}_oetp*.cobs
    done
    pseudoobstp="PseudoObs_${scenario}/obs"
    rm -rf ${pseudoobstp}_oetp*.cobs
    cd ${sdir}    
    echo "### Member $xt ready ###"
done
