#!/bin/bash

# Required modules
module load intel-mpi
module unload python
module load python/3.10.4

expt="ENS04"

. param.bash

# varlist="vosaline"
date
ref_files="/linkhome/rech/genige01/utw56cf/SNOOPI/Run_Exp3D/Sesam_dh/ENS0029_prior.nc.bas/vct_votemper_0030.nc"
imember="030"
figdir="/gpfsscratch/rech/egi/utw56cf/Nemo-med_fig/Data"
indir0="/lustre/fsn1/projects/rech/egi/utw56cf/temp_DATA/DATA2"
indir="/lustre/fsn1/projects/rech/egi/utw56cf/temp_DATA/ENS04_lf/"
let lon_size=$imax-$imin
for imember in $(seq -w 1 30); do
    tag=$(printf "%03d" $((10#$imember)))
    tag4=$(printf "%04d" $((10#$imember)))
    echo $tag
    for var in $varlist ; do

	if [[ $var == "sossheig" ]] ; then
	    vardim="2"
	    ntim="30"
	else
	    vardim="3"
	    ntim="6"
	fi

	list_files=""
	for ifile in ${indir}${tag}ENS04_${var}_sp*_${sigma}splf.nc ; do
	    echo $ifile                                                                    
            list_files="$list_files $ifile"
	done
	ofile="${wdir}/${ensdir}_prior.nc.bas/vct_${var}_${tag4}_splf.nc"
	# ofile="$indir/${tag}ENS04_${var}_${sigma}splf.nc"
	python extract_space_recomb.py --variable_name $var --variable_dim $vardim --ref_files $ref_files --output_file $ofile $list_files
	# cp $ofile "/lustre/fsstor/projects/rech/egi/utw56cf/ENS04_lf/${tag}${expt}_${var}_lf.nc"
	
	# for ifile in $figdir/${tag}${expt}_${var}_lf.nc00* ; do
	# 	rm $ifile
	# done
     
    done
done
# for s_file in $list_files ; do
#     rm -f $s_file       
# done

# date
# for m in $(seq -f "%04g" 1 30); do
#     infile="vct_sossheig_${m}_splf.nc"
#     tmpfile="vct_sossheig_${m}_splf_trimmed.nc"

#     echo "Processing $infile"

#     # extraire du pas 1 au pas -2
#     ncks -O -d time_counter,1,-2 "$infile" "$tmpfile"

#     # remplacer le fichier original
#     mv "$tmpfile" "$infile"
# done
