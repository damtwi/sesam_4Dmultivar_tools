Script to perform ensemble observational update
===============================================

1. Preparation of the PRIOR Ensemble (facultative)
--------------------------------------------------

Use the README.md from the ensemble_build field.


2. Perform the OSSE over multiple Nature-run
--------------------------------------------------

       a. Prepare SESAM configuration
	______________________________
prepare_config_ens.bash

for the each nature run, defined a param{xt}.bash file which: 
Define sesamlist and mask file	     
Define truth to be used in twin experiments
Prepare zero file
Extract region and time window from NEMO ensemble
-> 29 members for us (2D or 3D vectors)
-> one membre as xt 


	b. Prepare observation 
	_______________________
prepare_obs_ens.bash

for each nature run:
->extract obs from each member
->estimated the noise from observation error
->estimated the std from obs & measurement error

	b*. Prepare covariance localization for MCMC sampler
	___________________________________________________
draw_loc_sample.bash


	c. Prepare reduce problem
	________________________________
prepare_reduce_ens.bash
-> reduce the prior ensemble & reduce shurz matrix
-> reduce the pseudo-obs (from the nature run)
-> extract the obs from reduce ensemble



	d. Execut the mcmc algorithm
	____________________________
update_mcmc_gpu_ens.bash (or update_mcmc.bash)



4. Evaluate posterior ensemble solution
---------------------------------------

postpro_reduce.bash  (uncenter-unreduce ensemble + compute mean and std)

a. Compute probabilistic scores (rank histogram, RCRV, CRPS)

prepare_partition_diag.bash
check_score_global_loop.bash

b. Diagnose ensemble correlation with respect to a reference location

diag_correlation.bash


