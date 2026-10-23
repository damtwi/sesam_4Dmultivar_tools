#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:15:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
##SBATCH --partition=prepost
#SBATCH --qos=qos_cpu-dev

# =============================================================================
# Generate noisy pseudo-observations and estimate observation-error standard
# deviations for each observation system using SESAM.
#
# The script performs two main steps:
#   1. Pseudo-observation generation:
#      - interpolate pseudo-observations from the specified observation
#        configurations and the model field.
#      - Generates basin-scale high-frequency noise and adds it to the
#        pseudo-observations.
#      - Adds observation-system-specific measurement noise.
#   2. Observation-error estimation:
#      - Interpolates the ensemble high-frequency standard deviation onto
#        the observation locations.
#      - If needed, applies a multiplicative scaling factor.
#      - Incorporates the measurement-error contribution to obtain the
#        final observation-error standard deviations.
#
# Configuration:
#   - Loads the parameter file provided as the first argument, or param.bash
#     by default.
#   - Uses parameters defined in the configuration file, including wdir,
#     scenario, zmin, zmax, obs_list, SESAM executable and measurement errors.
#
# Input requirements:
#   - Observation configurations and ensemble high-frequency standard-deviation
#     fields.
#   - The noise-generation script noise.py.
#
# Output:
#   - Noisy pseudo-observations under PseudoObs_<type>_z<zmin>-<zmax>/.
#   - Observation-error standard-deviation fields (oestd) for each observation
#     system.
#
# =============================================================================

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
pseudoobsxtname="PseudoObsxt_${scenario}/obs"
tag_enssize=$(printf "%04d" $((10#$mem1)))

for obsi in "${obs_list[@]}"; do
    #files definitions
    pseudoobs_file="PseudoObs_${obsi}_z${zmin}-${zmax}/"
    pseudoobstp="PseudoObs_${obsi}_z${zmin}-${zmax}/obs"
    rm -rf ${pseudoobstp}*
    
    #real observation definition & hf observational error importation
    src_obs="$wdir/Obs_${obsi}_z${zmin}-${zmax}"
    obsname="Obs_${obsi}_z${zmin}-${zmax}/obs"
    ln -sf "${source_obs}/Obs_${obsi}_z${zmin}-${zmax}" "${src_obs}"
    ln -sf ../"${ensdir}${tag_enssize}std_*_hf.nc" .
    
    #sat obs do not depend on depth
    if [ "${obsi}" = "sat" ]; then
	obsname="Obs_${obsi}/obs"
    fi

    #created the pseudoobs file
    if [ ! -d PseudoObs_${obsi}_z${zmin}-${zmax} ] ; then
	mkdir PseudoObs_${obsi}_z${zmin}-${zmax}
    fi
    rm -rf "$pseudoobstp"*
    
    echo $pseudoobsname $obsname

    # Definition of the measurment error
    case "$obsi" in
        "${scenario}")
            oe_obs="$oectd"
            oe_sobs="$oesctd"
            ;;
        "sat")
            oe_obs="$oesat"
            ;;
        "gli")
            oe_obs="$oegli"
            oe_sobs="$oesgli"
            ;;
        "argo")
            oe_obs="$oeargo"
            oe_sobs="$oesargo"
            ;;
        *)
            echo "Unknown observation type: $obsi"
            oe_obs="$oectd"
	    
            ;;
    esac   
    
    #--------------------------------------------
    # STEP 1 : ADD NOISE TO PSEUDO-OBS
    #--------------------------------------------
    # Generation of the noise from basin HF-std
    rm -rf noise_basin3d_*nc
    cp $sdir/noise.py .
    python3 noise.py

    # Initiate the pseudo-obs without noise
    rm -rf "$pseudoobsxtname"*
    $sesam  -mode intf -inobs xt#.nc -outobs ${pseudoobsxtname}#.cobs \
		    -configobs ${obsname}#.cobs
    
    # extract the gaussian noise field in obs format
    rm -rf tmpnoise*.cobs
    $sesam  -mode intf -inobs noise_basin3d#hf.nc -outobs tmpnoise0#.cobs \
	    -configobs ${pseudoobsxtname}#.cobs
    
    cp -r tmpnoise0*.cobs ${pseudoobs_file}/.
    #Add HF-noise to perfect pseudo observation
    $sesam -mode oper -inobs tmpnoise0#.cobs -configobs ${pseudoobsxtname}#.cobs -typeoper + \
	                      -inobsref ${pseudoobsxtname}#.cobs \
	                      -outobs ${pseudoobstp}#_tmp.cobs


    if [ "${obsi}" = "sat" ]; then
	rm -f tmpgnoise*.cobs
	$sesam -mode oper -inobs ${pseudoobsxtname}#.cobs -configobs ${pseudoobsxtname}#.cobs \
	       -outobs tmpgnoise#.cobs -typeoper gnoise_$oesat

    	#Add noise to perfect pseudo observation
	$sesam -mode oper -inobs tmpgnoise#.cobs -configobs ${pseudoobsxtname}#.cobs -typeoper + \
	                      -inobsref ${pseudoobsxtname}#.cobs \
	                      -outobs ${pseudoobstp}#.cobs
    else
	#split temperature and salinity into temp_me
	if [ ! -d temp_me ] ; then
	    mkdir temp_me
	fi

	if [ ! -d temp_out ] ; then
	    mkdir temp_out
	fi
	rm -f temp_out/*
	rm -f tmptgnoise*.cobs
	rm -f tmpsgnoise*.cobs
	rm -f temp_me/*

	# generation of salinity noise
	cp ${pseudoobstp}_s*_tmp.cobs temp_me/.
	$sesam -mode oper -inobs temp_me/obs#_tmp.cobs -configobs temp_me/obs#_tmp.cobs \
	       -outobs tmpsgnoise#.cobs -typeoper gnoise_$oe_sobs
	
	cp tmpsgnoise*.cobs ${pseudoobs_file}/.
	#Add measurment noise to salinity pseudo observation
	$sesam -mode oper -inobs tmpsgnoise#.cobs -configobs tmpsgnoise#.cobs -typeoper + \
                  -inobsref  temp_me/obs#_tmp.cobs \
                  -outobs temp_out/obs#.cobs
	
	#Save the salinity pseudoobse
	cp temp_out/*cobs ${pseudoobs_file}/.

	rm -f temp_out/*
	rm -f tmptgnoise*.cobs
	rm -f temp_me/*
	
	# selection of temperature files
	cp ${pseudoobstp}*_tmp.cobs temp_me/.
	rm -f temp_me/obs_s*
	
	# generation of temperature noise
	$sesam -mode oper -inobs temp_me/obs#_tmp.cobs -configobs temp_me/obs#_tmp.cobs \
	       -outobs tmptgnoise#.cobs -typeoper gnoise_$oe_obs
	cp tmptgnoise*.cobs ${pseudoobs_file}/.

	#Add measurment noise to pseudo observation
	rm -f temp_out/*
	$sesam -mode oper -inobs tmptgnoise#.cobs -configobs tmptgnoise#.cobs -typeoper + \
                  -inobsref  temp_me/obs#_tmp.cobs \
                  -outobs temp_out/obs#.cobs
	#and save it
	cp temp_out/*cobs ${pseudoobs_file}/.
	
    fi

    #--------------------------------------------------------------
    # STEP 2 : OBS-error CALCULATION (with measurement error)
    #--------------------------------------------------------------    
    # std calculation step 1 : filtered HF 
    rm -rf ${pseudoobstp}_oestd*.cobs
    rm -rf ${pseudoobstp}_oetp2*.cobs
    rm -rf ${pseudoobstp}_oetp*.cobs
    $sesam  -mode intf -inobs ENS0030std#hf.nc -outobs ${pseudoobstp}_oetp#.cobs -configobs ${obsname}#.cobs

    # multiplicator just in case if the error d'obs is to low
    alpha_obs="1"
    $sesam -mode oper -inobs ${pseudoobstp}_oetp#.cobs -outobs ${pseudoobstp}_oetp1#.cobs \
	   -configobs ${pseudoobstp}#.cobs -typeoper cst_$alpha_obs
    $sesam  -mode oper -inobs ${pseudoobstp}_oetp1#.cobs -inobsref ${pseudoobstp}_oetp#.cobs -outobs ${pseudoobstp}_oetp3#.cobs \
	    -configobs ${pseudoobstp}#.cobs -typeoper x
    
    # std calculation step 2 : measurement error
    echo $oe_obs
    # add the measurement to the obs error std     
    rm -rf ${pseudoobstp}_oetp2#.cobs
    $sesam -mode oper -inobs ${pseudoobstp}_oetp3#.cobs -outobs ${pseudoobstp}_oetp2#.cobs -configobs ${pseudoobstp}_oetp3#.cobs -typeoper cst_$oe_obs
    $sesam -mode oper -inobs ${pseudoobstp}_oetp2#.cobs -configobs ${pseudoobstp}_oetp#.cobs -typeoper + -inobsref ${pseudoobstp}_oetp2#.cobs -outobs ${pseudoobstp}_oestd#.cobs
    
done 
