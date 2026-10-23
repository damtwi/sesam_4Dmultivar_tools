#!/bin/bash
#SBATCH --job-name=extractlf
#SBATCH -e extractlf.e%j
#SBATCH -o extractlf.o%j
#SBATCH --ntasks=10
#SBATCH --time=01:45:00
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev
##SBATCH --partition=prepost

# =============================================================================
# Apply temporal HF/LF filtering to ensemble members.
#
# =============================================================================
# Apply temporal HF/LF filtering to an ensemble of NetCDF fields.
#
# For each selected ensemble member and variable, this script:
#   1. Identifies the corresponding input NetCDF files.
#   2. Splits the longitude domain across MPI ranks.
#   3. Applies temporal Lanczos filtering independently to each spatial block.
#   4. Writes one HF and one LF NetCDF file per MPI rank.
#
# Requirements:
#   - A param.bash configuration file in the script directory.
#   - Input ensemble files matching the naming convention described below.
#   - extract_hf.py and its Python dependencies.
#
# Configuration:
#   - mem0, mem1: first and last ensemble member indices to process.
#   - varlist: variables to process.
#   - lanczos_window: filter window for 3D variables.
#   - nblocks: number of spatial blocks used by the MPI processing.
#   - filter: filtering method passed to extract_hf_dh4.py.
#   - indir, outdir: input and output directories, defined below.
#
# Input naming convention:
#   vct_<variable>_<member_tag>.nc
#   where member_tag is formatted using three digits.
#   Example pattern for member 30: vct_votemper_0030.nc
#
# Output naming convention:
#   <output_prefix><rank><filter>_<window_size>hf.nc
#   <output_prefix><rank><filter>_<window_size>lf.nc
#   The MPI rank suffix is omitted when MPI is disabled.
#

# -----------------------------------------------------------------------------
# Load software dependencies.
# Adapt module commands to the target computing environment.
# -----------------------------------------------------------------------------
module load intel-mpi
module unload python
module load python/3.10.4

# -----------------------------------------------------------------------------
# Load configuration.
# -----------------------------------------------------------------------------
. ./param.bash

# -----------------------------------------------------------------------------
# Script-specific configuration.
# -----------------------------------------------------------------------------

first_member=$((10#${mem0}))
last_member=$((10#${mem1}))



echo "Input directory: ${source_ensemble}"
echo "Output directory: ${source_prior}"
echo "Ensemble member range: ${first_member}-${last_member}+1"
echo "Variables: ${varlist}"
date

# -----------------------------------------------------------------------------
# Process each ensemble member.
# -----------------------------------------------------------------------------
for ((i=first_member; i<=last_member; i++)); do
    member_tag=$(printf "%03d" "$i")
    echo "#### Processing ensemble member ${member_tag} ####"
    for var in $varlist; do
        echo "Variable: ${var}"
        files=( "${source_ensemble}"/vct_"${var}"*0"${member_tag}".nc )
        # SSH is a 2D variable and uses a longer temporal filter window.
        if [[ "$var" == "sossheig" ]]; then
            vardim=2
            ntim=$ssh_timesteps
            window_size=$ssh_window
        else
            vardim=3
            ntim=$default_timesteps
            window_size=$lanczos_window
        fi
	mkdir "${source_prior}/block"
        output_file="${source_prior}/block/${member_tag}${expt}_${var}"
        echo "Input files: ${#files[@]}"
        echo "Output file: ${output_file}"
        srun python extract_hf.py \
            --variable_name "$var" \
            --variable_dim "$vardim" \
            --lat_index_start "$jmin" \
            --lat_index_end "$jmax" \
            --lon_index_start "$imin" \
            --lon_index_end "$imax" \
            --window_size "$window_size" \
            --num_timesteps "$ntim" \
            --use_mpi \
            --num_blocks "$nblocks" \
            --output_file "$output_file" \
            "${files[@]}" \
            --filters "$filter"

    done
done

date
