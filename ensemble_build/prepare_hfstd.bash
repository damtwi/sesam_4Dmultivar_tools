#!/bin/bash
# -----------------------------------------------------------------------------
# Prepare the high-frequency ensemble and compute its sample standard deviation.
# Create symbolic links to the filtered member fields, convert them to SESAM
# ensemble format, and compute the standard deviation across all members.
# -----------------------------------------------------------------------------

. ./param.bash

cd $wdir

# Copy the SESAM configuration file
cp -p ${sdir}/sesamlist .
rm -rf tmpmask.nc

# Define the source ensemble and working directories
tag_enssize=$(printf "%04d" $((10#$mem1)))
ensname="ENS${etag_enssize}"
ens_dir="ENS0030.nc.bas"
mkdir $ens_dir

# Create symbolic links to the high-frequency fields for each member and variable
rm -rf "${ens_dir}/"*
for i in $(seq -w 1 30); do
    for var in ${varlist} ; do
        membertagi=$(printf "%04d" $((10#$i)))
        src="${source_prior}vct_${var}_${membertagi}_sphf.nc"
        dst="${ens_dir}/vct_${var}_${membertagi}.nc"
        # Create a symbolic link to the source field
        ln -s "$src" "$dst"
    done
done

# Convert the input fields to SESAM ensemble format
mkdir ${ensname}.cpak.bas
rm ${ensname}.cpak.bas/*
$sesam -mode intf -inxbas ${ens_dir} -outxbas ${ensname}.cpak.bas

# Build a configuration file listing all ensemble members
echo $ens_size > list.cfg
let member=1
while [ $member -le ${ens_size} ] ; do
    membertag4=`echo $member | awk '{printf("%04d", $1)}'`
    ifile="${ensname}.cpak.bas/vct${membertag4}.cpak"
    echo $ifile >> list.cfg
    let member=$member+1
done

# Compute the sample standard deviation across the high-frequency ensemble
$sesam -mode oper -incfg list.cfg -outvar ${ensname}std#hf.nc -typeoper std

# Remove temporary ensemble directories
rm ${ensname}.cpak.bas ${ensname}.nc.bas
