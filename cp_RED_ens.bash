#!/bin/bash


#!/bin/bash


for i in $(seq -w 1 30); do    
    xt=$(printf "%02d" $((10#$i)))
    echo "${xt}"
    # pseudoobstp="/lustre/fsstor/projects/rech/egi/utw56cf/SNOOPI/ExpEns/${xt}/ENS0029.cpak.bas"
    pseudoobstp="/lustre/fsstor/projects/rech/egi/utw56cf/SNOOPI/ExpEns/${xt}"
    pseudoobstp2="/lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/ExpEns/${xt}"
    echo "${pseudoobstp2}"
    echo "${pseudoobstp}"
    cp "${pseudoobstp}"/*std*_.nc "${pseudoobstp2}"/.
done 
