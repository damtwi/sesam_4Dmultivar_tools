#!/bin/bash
#SBATCH --job-name=checkscore
#SBATCH -e checkscore.e%j
#SBATCH -o checkscore.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=04:45:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
##SBATCH --qos=qos_cpu-dev
#SBATCH --qos=qos_cpu-t3

. ./param01.bash

cd $wdir

diagimin=0
diagimax=1000
diagjmin=0
diagjmax=1000
for idepth in $(seq 0 65); do
idepth_old=$((idepth-1))

# File to generate the diagnostic partition
cat > mkpart.cfg <<EOF
SSH   'mkpartSSH.cnt' 11
TEM   'mkpartTEM.cnt' 11
SAL   'mkpartSAL.cnt' 11
EOF

let ipart=1
for var in SSH TEM SAL ; do

# File defining the diagnostic partition
cat > mkpart$var.cnt <<EOF
1 5 1
# Inside
5
$diagimin $diagjmin
$diagimax $diagjmin
$diagimax $diagjmax
$diagimin $diagjmax
$diagimin $diagjmin
1
$ipart $(printf "%.1f" "$(echo "$idepth_old + 0.5" | bc)") $(printf "%.1f" "$(echo "$idepth + 0.5" | bc)")
EOF

  let ipart=$ipart+1
done

cat > algodiff.cfg <<EOF
# Configuration file for the computation of RMS differences
1 1
RMS_domain
1
1
EOF

# Generate partition for the computation of RMS differences

rm -f rmspart${ftype}.nc
$sesam -mode zone -incfg mkpart.cfg -outpartvar rmspart$idepth#.nc
$sesam -mode intf -invar rmspart${idepth}#.nc -outvar rmspart${idepth}.cpak

done
