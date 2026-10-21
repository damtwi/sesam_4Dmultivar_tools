#!/bin/bash
#SBATCH --job-name=combhf
#SBATCH -e combhf.e%j
#SBATCH -o combhf.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=01:25:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

# Required modules
module load intel-mpi
module unload python
module load python/3.10.4

. ../param.bash

date
let lon_size=$imax-$imin
echo $lon_size

for freq in "lf" "hf"; do
    echo $freq
    for ((imember=$mem0; imember<=$mem1+1; imember++)); do
	tag=$(printf "%03d" $((10#$imember)))
	echo $tag
	for var in $varlist ; do
            if [[ "$var" == "sossheig" ]]; then
		vardim=2
		window_size=$ssh_window
            else
		vardim=3
		window_size=$lanczos_window
            fi
	    ofile="${source_prior}/block/${tag}${expt}_${var}"
	    python extract_lf_recomb.py --variable_name $var --variable_dim $vardim --lon_index_start 0 --lon_index_end $lon_size --num_blocks $nblocks --grid_file $grid_file --inout_path $ofile --window $window_size --freq $freq
	done
    done
done
date
