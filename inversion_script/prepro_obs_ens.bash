#!/bin/bash
#SBATCH --time=00:30:00
#SBATCH -A egi@cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev


# =============================================================================
# Project the reduced ensemble fields onto observation space.
# =============================================================================

# Load the main configuration and link the localized ensembleinto each NR files
. ./param.bash
idir1="RED_1_ENS${ens_size}.cpak.bas"
idir2="RED_2_ENS${ens_size}-${loc_dir_tag}.cpak.bas"
ln -sf ${wdir}/${idir2} .

# Load the parameter file
PARAM_FILE=${1:-param.bash}
. ./$PARAM_FILE

cd $wdir
ensdir="ENS${ens_size}"

obsname="PseudoObs_${scenario}/obs"
obsname="redobs"
# Compute the observation-space equivalent of the multiscale input ensemble

idir1obs="RED_1_ENS${ens_size}.cobs.bas"
odir1obstag="RED_1_ENS${ens_size}-${loc_dir_tag}prior.obs.bas"

idir2obs="RED_2_ENS${ens_size}.cobs.bas"
odir2obstag="RED_2_ENS${ens_size}-${loc_dir_tag}.obs.bas"

echo "$ensdir,${obsname},${ensdir}mean,${wdir}"

# Project the first reduced ensemble onto observation space
rm -fr $idir1obs
mkdir $idir1obs
$sesam -mode intf -inobas $idir1 -outobas $idir1obs -configobs ${obsname}#.cobs

# Project the second reduced ensemble onto observation space
rm -fr $idir2obs
mkdir $idir2obs
$sesam -mode intf -inobas $idir2 -outobas $idir2obs -configobs ${obsname}#.cobs

# Generate observation-space data for the first reduced ensemble
$sesam -mode obsv -inobs $idir1obs/vct#0001.cobs -configobs $idir1obs/vct#0001.cobs -outdta $idir1obs/vtc0001.cdta

# Copy the parameter file into the generated observation directories
cp $sdir/${PARAM_FILE} $wdir/RED_2_ENS${ens_size}.cobs.bas/.
cp $sdir/${PARAM_FILE} $wdir/RED_1_ENS${ens_size}.cobs.bas/.

# Rename the observation directories with the localization tag
# and preserve the original directory names through symbolic links
rm -fr ${odir2obstag}
mv ${idir2obs} ${odir2obstag}
ln -sf ${odir2obstag} ${idir2obs}

rm -fr ${odir1obstag}
mv ${idir1obs} ${odir1obstag}
ln -sf ${odir1obstag} ${idir1obs}
