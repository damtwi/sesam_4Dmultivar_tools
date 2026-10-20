#!/bin/bash

# Chemins de base
PARAM_TEMPLATE="param.bash"
PREPARE_SCRIPT="prepare_config_ens.bash"

# Boucle sur les membres de l'ensemble
for i in $(seq -w 1 30); do
    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"

    # Copier param.bash en param{xt}.bash
    PARAM_FILE="param${xt}.bash"
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"

    # Modifier memxt et wdir à l'intérieur du param{xt}.bash
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"

    # wdir="$SCRATCH/SNOOPI/ExpEns" -> ajouter le sous-dossier xt
    # On suppose que le dossier parent $SCRATCH/SNOOPI/ExpEns existe
    WDIR_SUB="$SCRATCH/SNOOPI/ExpEns/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"

    # Créer le dossier wdir/xt si nécessaire
    mkdir -p "$WDIR_SUB"

    # Exécuter prepare_config.bash avec le paramètre modifié
    bash "$PREPARE_SCRIPT" "$PARAM_FILE"

    echo "### Member $xt ready ###"
done
