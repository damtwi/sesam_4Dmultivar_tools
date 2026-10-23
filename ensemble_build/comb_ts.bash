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

# =============================================================================
# Recombine temporally filtered longitude blocks into full-domain LF/HF files.
#
# For each ensemble member, variable and frequency (lf then hf), this script:
#   1. Locates the per-rank temporally filtered files produced by
#      extract_ts_prior_time.bash / extract_hf.py in ${source_prior}/block/.
#   2. Concatenates their longitude blocks back into the full regional domain
#      via extract_lf_recomb.py, taking the horizontal coordinates from
#      grid_file and the time axis from the rank-0000 file.
#   3. Writes one full-domain LF and one full-domain HF NetCDF file
#      per member and variable.
#
# Requirements:
#   - A param.bash configuration file in the parent directory.
#   - Must be run from this script's directory (../param.bash and
#     extract_lf_recomb.py are resolved relatively).
#   - Per-rank files from Stage 1 for every member in [mem0, mem1] and every
#     variable in varlist (see input convention below).
#   - grid_file: regional grid matching the filtered domain
#   - extract_lf_recomb.py with python/3.10.4 (netCDF4).
#
# Input naming convention (one file per Stage-1 MPI rank):
#   <prefix><rank><filter>_<window><freq>.nc
#   where <prefix> = ${source_prior}/block/<member_tag><expt>_<variable>

# Output naming convention (rank suffix removed, same directory):
#   <prefix><filter>_<window><freq>.nc
# =============================================================================


# Required modules
module load intel-mpi
module unload python
module load python/3.10.4

. ./param.bash

date
let lon_size=$imax-$imin
echo $lon_size

for freq in "lf" "hf"; do
    echo $freq
    for ((imember=$mem0; imember<=$mem1; imember++)); do
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
