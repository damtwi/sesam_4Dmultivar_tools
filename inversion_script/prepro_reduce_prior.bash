#!/bin/bash
#SBATCH --time=02:30:00
#SBATCH -A egi@cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread

PARAM_FILE=${1:-param.bash}
. ./$PARAM_FILE

cd $wdir
membertag4=`echo $ens_size | awk '{printf("%04d", $1)}'`

# # Convert input ensemble to cpak
rm -fr ${ensdir}.cpak.bas ; mkdir ${ensdir}.cpak.bas
$sesam -mode intf -inxbas ${ensdir}.nc.bas -outxbas ${ensdir}.cpak.bas

# Compute ensemble mean and standard deviation
rm -f list.cfg
echo $ens_size > list.cfg
let member=1
while [ $member -le ${ens_size} ] ; do
  membertag4=`echo $member | awk '{printf("%04d", $1)}'`
  ifile="${ensdir}.cpak.bas/vct${membertag4}.cpak"
  echo $ifile >> list.cfg
  let member=$member+1
done

rm -f ${ensdir}std*.nc ${ensdir}mean*.nc
rm -f ${ensdir}std.cpak ${ensdir}mean.cpak
$sesam -mode oper -incfg list.cfg -outvar ${ensdir}std#.nc -typeoper std
$sesam -mode intf -invar ${ensdir}std#.nc -outvar ${ensdir}std.cpak
$sesam -mode oper -incfg list.cfg -outvar ${ensdir}mean#.nc -typeoper mean
$sesam -mode intf -invar ${ensdir}mean#.nc -outvar ${ensdir}mean.cpak
rm -f list.cfg

# Center-reduce input ensemble
rm -fr RED_1_${ensdir}.cpak.bas ; mkdir RED_1_${ensdir}.cpak.bas

let member=1
while [ $member -le ${ens_size} ] ; do
  membertag4=`echo $member | awk '{printf("%04d", $1)}'`
  ifile="${ensdir}.cpak.bas/vct${membertag4}.cpak"
  ofile="RED_1_${ensdir}.cpak.bas/vct${membertag4}.cpak"

  rm -f tmpred.cpak
  $sesam -mode oper -invar $ifile -invarref ${ensdir}mean#.nc -outvar tmpred.cpak -typeoper -
  $sesam -mode oper -invar tmpred.cpak -invarref ${ensdir}std#.nc -outvar $ofile -typeoper /
  rm -f tmpred.cpak

  let member=$member+1
done
