#!/bin/bash

# range of ensemble members
datadir="$SCRATCH/temp_DATA/DATA2"
ens_size="0029"
ensdir="ENS${ens_size}"
mem0="1"
mem1="29"
memxt=""
sdir="/linkhome/rech/genige01/utw56cf/SNOOPI/Run_ExpEns"
wdir="/lustre/fsn1/projects/rech/egi/utw56cf/SNOOPI/ExpEns/"
zmin="1000"
zmax="3000"
# define list of variables
varlist="votemper sossheig vosaline"
sigma="4"
vardim="3"

# Temporal filtering
filter="lanczos"
lanczos_window="7"
default_timesteps="6"
nblocks="10"      # Number of longitude blocks used during filtering
total_timestep=123

# SSH-specific filtering
ssh_window="31"
ssh_timesteps="1"

# Parallel processing
nblocks="10"
use_mpi="true"




# Define the source and output ensemble directories.
source_ensemble="NEMOMED12_${ensdir}"
source_prior="${wdir}/${ensdir}_prior.nc.bas"
prior_dir="${wdir}/{ensdir}.nc.bas"
mask_input="${source_prior}/vct_${var}_${replacement_tag}.nc"
grid_input="${source_prior}/vct_${var}_${replacement_tag}.nc"

# define region and time span
grid_file="/path/to/your/mesh_mask.nc"
imin="148"
imax="252"
jmin="144"
jmax="231"

# tmin="14068"
# tmax="14098"
size_yr="10" # number of year in one member
tmin="0"
tmax="73"
# tmax="14797"

# # standard SESAM executable
sesam="sesam_mpi"
# GPU SESAM executable
sesam_gpu="sesam_gpu"

model_expt="ENS04"
obsdir="/lustre/fsn1/projects/rech/egi/utw56cf/temp_DATA/DATA/Obs_dbs"
model_grid="/lustre/fswork/projects/rech/egi/utw56cf/mesh_mask_MED12_v75.nc"

# Define observation database
satlist="tp j1 j2 j3"   # List of satellite missions to extract (! h2a is for h2ag !)
dbslonmin="2.5"
dbslonmax="9"
dbslatmin="40"
dbslatmax="44"

# Define observation scenario
obs_satlist="tp j1 j2 j3 tpn e1 e1g e2 g2 j1n j1g en enn j2n j2g c2 al alg h2a h2ag s3a"
# scenario="ctd24j"
scenario="FullObs_z${zmin}-${zmax}"
obs_list=(
    "ctd24j"
    "argo"
    "sat"
    "gli"
)

# scenario="glider"
oesat="0.03"   # observation error standard deviation

oectd="0.001"   # observation error standard deviation
oegli="0.002"   # observation error standard deviation
oeargo="0.002"   # observation error standard deviation

oesctd="0.003"   # observation error standard deviation
oesgli="0.002"   # observation error standard deviation
oesargo="0.01"   # observation error standard deviation
# scenario="red"
# oestd="0.1"   # observation error standard deviation

# # Covariance localization parameters
loc_lmax="100"              # Maximum degree of spherical harmonics in localizing ensemble
loc_radius="7.3"            # Localization radius (in degree)   ! multiplied by sqrt(mult=6)
loc_time_scale="8760"      # Localization time scale (in days) ! multiplied by sqrt(mult=6)
loc_dir_tag="100-8760-7300"  # Tag in directory name

# Use zero background mean rather than ensemble mean
# Use constant background error variance rather than ensemble variance
use_zero_mean="False"
use_cst_bestd="False"
# bestd="0.03"  # background error standard deviation

# MCMC sampler parameters
expt=$loc_dir_tag${scenario}         # Name of the experiment
scal_mult_1="1"           # Multiplicity of 1st scale
scal_mult_2="6"           # Multiplicity of 2nd scale
upd_size="0029"           # Updated ensemble size
niter="2000"             # Number of iterations
