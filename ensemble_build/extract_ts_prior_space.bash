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

#===========================================================================
# Apply spatial filtering to temporally filtered fields, then recombine
# the resulting longitude blocks into complete NetCDF files.
# Filtering uses MPI; recombination starts after filtering has completed.
# Apply spatial filtering to temporally filtered fields, then recombine
# the resulting blocks into complete NetCDF files.
# Filtering uses MPI; recombination starts after filtering has completed.
#
# Note: Existing intermediate blocks are not automatically removed.
# Clean up stale blocks before rerunning to avoid mixing old and new outputs.
#============================================================================
module load intel-mpi
module unload python
module load python/3.10.4

. ../param.bash

expt="ENS04"
total_timestep=123
freq="lf"

# Directories and reference grid
ref_files="/linkhome/rech/genige01/utw56cf/SNOOPI/Run_Exp3D/Sesam_dh/ENS0029_prior.nc.bas/vct_votemper_0030.nc"
grid_file=
date
shopt -s nullglob

# Process ensemble members
first_member=$mem0
last_member=$mem1

for ((imember=first_member; imember<=last_member+1; imember++)); do
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
        input_files=( "${source_prior}/block/${tag}filter_${var}${filter}"*"${window_size}lf.nc" )

        # Step 1: Apply spatial filtering using MPI
        block_prefix="${indir}/${tag}${expt}_${var}_sp"
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
        output_file="${wdir}/${ensdir}_prior.nc.bas/vct_${var}_${tag4}_splf.nc"
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
