#!/bin/bash
#SBATCH --job-name=spacefilter
#SBATCH -e spacefilter.e%j
#SBATCH -o spacefilter.o%j
#SBATCH --ntasks=10
#SBATCH --time=02:45:00
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev
##SBATCH --partition=prepost

# =============================================================================
# Apply the Gaussian spatial filter to the temporally filtered LF fields,
# then recombine the resulting time blocks into full NetCDF files.
#
# For each ensemble member and variable, this script:
#   1. Selects the recombined LF file produced by comb_ts.bash / extract_lf_recomb.py.
#   2. Applies extract_spacefiltering.py under MPI (nblocks ranks splitting the
#      time axis), writing one block per rank.
#   3. Concatenates the time blocks with extract_space_recomb.py into a
#      full-domain, full-length filtered field.

# Requirements:
#   - A param.bash configuration file in the parent directory.
#   - Recombined LF file from Stage 2 for every member in [mem0, mem1] and
#     every variable in varlist (see input convention below).
#   - grid_file: regional grid matching the filtered domain
#   - extract_spacefiltering.py and extract_space_recomb.py with
#     python/3.10.4 (netCDF4, numpy, scipy) and intel-mpi.
#   - Number of tasks equal to nblocks (time blocks are distributed over ranks).
#
# Output naming convention (rank suffix removed, same directory):
#   ${source_prior}/vct_<variable>_<member4>_splf.nc
#
# Note: Existing intermediate blocks are not automatically removed.
# Clean up stale blocks before rerunning to avoid mixing old and new outputs.
# After this script you can clean the ${source_prior}/block file
#============================================================================
module load intel-mpi
module unload python
module load python/3.10.4
shopt -s nullglob

. ./param.bash

# Process ensemble members
first_member=$mem0
last_member=$mem1

for ((imember=first_member; imember<=last_member; imember++)); do
    tag=$(printf "%03d" "$imember")
    tag4=$(printf "%04d" "$imember")
    echo "Processing member ${tag}"

    for var in $varlist; do
        if [[ "$var" == "sossheig" ]]; then
            vardim=2
            window_size=$ssh_window
        else
            vardim=3
            window_size=$lanczos_window
        fi

        # Identify temporally filtered input files
        input_files=( "${source_prior}/block/${tag}{expt}_${var}lanczos_${window_size}lf.nc" )
        # Step 1: Apply spatial filtering using MPI
        block_prefix="${source_prior}/${tag}${expt}_${var}_sp"
        echo "Spatial filtering: ${tag} ${var}"

        srun python extract_spacefiltering.py \
            --variable_name "$var" \
            --variable_dim "$vardim" \
            --window_size "$sigma" \
            --total_timesteps "$total_timestep" \
            --use_mpi \
            --num_blocks "$nblocks" \
            --output_file "$block_prefix" \
            "${input_files[@]}"


        # Step 2: Recombine the spatial blocks
        block_files=( "${block_prefix}"*"_${sigma}splf.nc" )
        output_file="${source_prior}/vct_${var}_${tag4}_splf.nc"
        echo "Recombining blocks into ${output_file}"

        python extract_space_recomb.py \
            --variable_name "$var" \
            --variable_dim "$vardim" \
            --grid_file "$grid_file" \
            --output_file "$output_file" \
            "${block_files[@]}"

    done
done

date
