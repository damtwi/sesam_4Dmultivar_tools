# Ensemble Observational Update

This workflow performs ensemble observational updates using an MCMC sampler in an OSSE (Observing System Simulation Experiment) framework. It iterates over multiple Nature Runs to generate and evaluate posterior ensemble estimates.

## 1. Perform the OSSE over Multiple Nature Runs

### A. Prepare the SESAM Configuration

**Script:** `prepare_config_ens.bash`

For each Nature Run, this script generates a `param{xt}.bash` configuration file to:

- Define the SESAM configuration (`sesamlist`) and mask file.
- Define the reference truth used in the twin experiments.
- Prepare the zero file.
- Extract the relevant spatial region and time window from the NEMO ensemble.
- Configure the ensemble with 29 members for the prior and one additional member (`xt`) as the Nature Run.

The ensemble can contain either 2D or 3D vectors.

### B. Prepare Pseudo-Observations

**Script:** `prepare_pseudoobs.bash`

For recursive execution over multiple Nature Runs, use `submit_pseudoobs_ens.bash`.

For each Nature Run, the workflow:

- Extracts observations from each ensemble member.
- Estimates the noise associated with observational errors.
- Estimates the observation standard deviation by accounting for both ensemble variability and measurement errors.

### B.1. Prepare Covariance Localization for the MCMC Sampler

**Script:** `draw_loc_sample.bash`

Computes the localized ensemble based on the covariance structure of the prior ensemble.

### C. Prepare the Reduced Problem

**Script:** `submit_reduce_ens.bash`

Submits the following three scripts in sequence to reduce the prior ensemble and pseudo-observations, and prepare the observation-space representation for each Nature Run.

- **`prepro_reduce_prior.bash`**: centers and reduces the prior ensemble.
- **`prepro_reduce_pseudoobs.bash`**: centers and reduces the pseudo-observations.
- **`prepro_obs_ens.bash`**: interpolates the localized ensemble into observation space and prepares the observation-space representation of the centered and reduced prior ensemble.

### D. Execute the MCMC Algorithm

**Script:** `mcmc_update_ens.bash`

Applies the MCMC sampler to each Nature Run to sample the posterior probability distribution conditioned on the observations.

## 2. Evaluate the Posterior Ensemble

**Script:** `postpro_reduce.bash`

Reconstructs the updated ensemble by reversing the centering and reduction steps, then computes the posterior ensemble mean and standard deviation.

### A. Compute Probabilistic Scores

The following scripts evaluate the posterior ensemble using probabilistic diagnostics, including rank histograms, reduced centered random variable (RCRV) statistics, and the continuous ranked probability score (CRPS).

- **`prepare_partition_diag.bash`**: prepares the data partitions required for diagnostics.
- **`check_score_global_loop.bash`**: computes probabilistic scores across the evaluation domain and iterates over the relevant configurations.

### B. Diagnose Ensemble Correlations

**Script:** `diag_correlation.bash`

Analyzes ensemble correlations relative to a reference location.