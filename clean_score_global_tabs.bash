#!/bin/bash

# Chemins de base
# PARAM_TEMPLATE="param.bash"
PARAM_TEMPLATE="param0-300.bash"

# Boucle sur les membres de l'ensemble
# for i in 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30; do
for i in 24 26 28; do
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
    
    cp convert_tabs_crps.py $wdir

    cd $wdir    

    expt_ref="PRIOR"
    echo $expt_ref
    
    python3 convert_tabs_crps.py --expmcmc ${expt} --repertory $wdir
    # python3 convert_tabs_crps.py --expmcmc ${expt_ref} --repertory $wdir
    
    cd $sdir

done
