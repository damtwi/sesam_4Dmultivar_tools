#!/bin/bash
# =============================================================================
# Prepare ensemble configurations and leave-one-out prior ensembles.
#
# For each Nature Run (NR), this script:
#   1. Creates a member-specific parameter file from param.bash.
#   2. Prepares regional grid and mask files for the configured variables.
#   3. Extracts the selected NR fields.
#   4. Builds a prior ensemble of ens_size members, excluding the selected NR
#      and replacing it with the first member outside the prior.
#
# Assumptions:
#   - Ensemble members are numbered consecutively from 1.
#   - The source ensemble contains members 1 to ens_size + 1.
#   - The member ens_size + 1 is used to replace the selected NR.
#   - Prior ensemble files follow the naming convention:
#       src=${ensdir}.nc.bas/vct_<variable>_<member>.nc
#       Example: ENS0029.nc.bas/vct_votemper_0001.nc
#
# Outputs:
#   - Member-specific parameter files (paramXX.bash).
#   - Regional grid and mask files.
#   - Extracted NR fields (xt_<var>_.nc).
#   - Prior ensemble files represented by symbolic links.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Load software dependencies.
# -----------------------------------------------------------------------------
module purge
module load gcc
module load nco

# -----------------------------------------------------------------------------
# Check the configuration template and required tools.
# -----------------------------------------------------------------------------
param_template="param.bash"
./${param_template}
# Convert configuration values to integers.
prior_size=$((10#${ens_size}))
first_nr=$((10#${mem0}))
last_nr=$((10#${mem1}))
replacement_member=$((prior_size + 1))
replacement_tag=$(printf "%04d" "$replacement_member")


echo "Prior ensemble size: ${prior_size}"
echo "Nature Run range: ${first_nr}-${last_nr}"
echo "Replacement member: ${replacement_tag}"
echo "Source ensemble: ${source_prior}"

# -----------------------------------------------------------------------------
# Process each selected Nature Run.
# -----------------------------------------------------------------------------
for nr_index in $(seq "$first_nr" "$last_nr"); do
    member=$(printf "%02d" "$nr_index")
    member_tag=$(printf "%04d" "$nr_index")
    param_file="${sdir}/param${member}.bash"

    echo "#### Preparing Nature Run ${member} ####"

    # Create a member-specific parameter file.
    cp "$param_template" "$param_file"
    sed -i "s/^memxt=.*/memxt=\"${member}\"/" "$param_file"

    # Load the member configuration.
    source "$param_file"

    # Set the working directory for this Nature Run.
    mkdir -p "$wdir"
    cd "$wdir"

    # Copy the SESAM configuration.
    cp -p "${sdir}/sesamlist" .

    # Prepare mask and regional grid files for each model variable.
    for var in $varlist; do
	grid_output="grid_${var}.nc"
	mask_output="mask_${var}.nc"

	# Extract the regional domain and required coordinates.
	ncks -O \
             -d x,"$imin","$imax" \
             -d y,"$jmin","$jmax" \
             -v time_counter,nav_lon,nav_lat,"${var}" \
             "$grid_input" "$grid_output"

    	# Extract the regional domain and required coordinates.
	ncks -O \
             -d x,"$imin","$imax" \
             -d y,"$jmin","$jmax" \
             -v time_counter,nav_lon,nav_lat,"${var}" \
             "$mask_input" "$mask_output"
    done

	
    # -------------------------------------------------------------------------
    # Extract the selected Nature Run fields.
    # -------------------------------------------------------------------------
    for var in $varlist; do
        src="${source_prior}/vct_${var}_${member_tag}_splf.nc"
        nr_output="xt_${var}_.nc"
        cp "$src" "$nr_output"
    done

    # -------------------------------------------------------------------------
    # Construct the leave-one-out prior ensemble.
    # The output directory contains ens_size members.
    # -------------------------------------------------------------------------
    mkdir -p "$prior_dir"

    # Remove previous field links/files managed by this script.
    rm -f "${prior_dir}"/vct_*.nc

    # Link the first ens_size members to the prior directory.
    for prior_index in $(seq 1 "$prior_size"); do
        prior_tag=$(printf "%04d" "$prior_index")
        for var in $varlist; do
            src="${source_prior}/vct_${var}_${prior_tag}_splf.nc"
            dst="${prior_dir}/vct_${var}_${prior_tag}.nc"
            ln -s "$src" "$dst"
        done
    done

    # Replace the selected Nature Run with the first member outside the prior.
    # If the selected NR is already that member, no replacement is necessary.
    if [[ "$member_tag" != "$replacement_tag" ]]; then
        for var in $varlist; do
            src="${source_prior}/vct_${var}_${replacement_tag}_splf.nc"
            dst="${prior_dir}/vct_${var}_${member_tag}.nc"
            rm -f "$dst"
            ln -s "$src" "$dst"
        done
    fi

    echo "### Nature Run ${member} ready ###"
    cd "$sdir"
done

echo "All requested Nature Run configurations have been prepared."
