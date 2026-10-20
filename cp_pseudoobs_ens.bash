#!/bin/bash

PARAM_FILE=${1:-param.bash}
. ./$PARAM_FILE

cd $wdir

if [ ! -d PseudoObs_${scenario} ] ; then
  mkdir PseudoObs_${scenario}
fi
if [ ! -d PseudoObsxt_${scenario} ] ; then
  mkdir PseudoObsxt_${scenario}
fi

cp sesamlist sesamlist_obs
pseudoobsname="PseudoObs_${scenario}"
pseudoobsxtname="PseudoObsxt_${scenario}/obs"

rm -rf "$pseudoobsname"/*
for obsi in "${obs_list[@]}"; do
    pseudoobstp="PseudoObs_${obsi}"
    pseudoobstp2="PseudoObs_${obsi}_z${zmin}-${zmax}"

    # obsname="Obs_${obsi}_z${zmin}-${zmax}/obs"
    # src_obs="/lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/Exp3D/Obs_${obsi}_z${zmin}-${zmax}"
    # if [ "${obsi}" = "sat" ]; then
    # 	obsname="Obs_${obsi}/obs"
    # 	src_obs="/lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/Exp3D/Obs_${obsi}"
    # fi
    # if [[ "$obsi" != "sat" || "$zmin" == "0" ]]; then
    cp -r ${pseudoobstp} ${pseudoobstp2}
    # fi
done 
