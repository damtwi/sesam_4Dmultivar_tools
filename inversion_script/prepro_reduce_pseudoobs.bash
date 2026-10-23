#!/bin/bash
#SBATCH --time=00:05:00
#SBATCH -A egi@cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

PARAM_FILE=${1:-param.bash}
. ./$PARAM_FILE

cd $wdir


# ------------------------------------------------------------------
# Define directories
# ------------------------------------------------------------------
rm -rf tmp_red
mkdir tmp_red

for obsi in "${obs_list[@]}"; do
    rm -f redobs_*.cobs
    obsname="PseudoObs_${obsi}_z${zmin}-${zmax}/obs"
    pseudoobstp="PseudoObs_${obsi}_z${zmin}-${zmax}"
    echo "${pseudoobstp}"
    if compgen -G "${pseudoobstp}/redobs*.cobs" > /dev/null; then
	echo "Reduced observations already exist. Reusing them."
	cp ${pseudoobstp}/redobs*.cobs tmp_red/.
    else
	#Center-reduce observation
	rm -f tmpred*.cobs
	echo "${pseudoobstp},$use_zero_mean,${obsname},${ensdir}mean,${wdir}"
	$sesam -mode oper -inobs ${obsname}#.cobs -configobs ${obsname}#.cobs -inobsref ${ensdir}mean#.nc -outobs tmpred#.cobs -typeoper -
	
	$sesam -mode oper -inobs tmpred#.cobs -configobs ${obsname}#.cobs -inobsref ${ensdir}std#.nc -outobs redobs#.cobs -typeoper /
	rm -f tmpred*.cobs
	# Reduce observation error
	
	$sesam -mode oper -inobs ${obsname}_oestd#.cobs -configobs ${obsname}#.cobs -inobsref ${ensdir}std#.nc -outobs redobs_oestd#.cobs -typeoper /
	
	cp redobs*.cobs ${pseudoobstp}/.
	cp redobs*.cobs tmp_red/.
    fi
done
cp tmp_red/* .
rm -rf tmp_red
