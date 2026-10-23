# Preparation of the Prior Ensemble

This workflow prepares the prior ensemble through temporal and spatial filtering.

## 1. Temporal Filtering (Lanczos HF/LF)

### `extract_ts_prior_time.bash`

Applies Lanczos temporal filtering in parallel over longitude blocks using MPI. Each MPI rank processes one longitude block and produces one high-frequency (HF) file and one low-frequency (LF) file.

### `comb_ts.bash`

Recombines the chunked temporal-filtering outputs into full-domain LF and HF files.

## 2. Spatial Filtering (Gaussian)

### `extract_ts_prior_space.bash`

Applies Gaussian spatial filtering to the low-frequency (LF) fields in two steps:

1. **Spatial filtering:** `extract_spacefiltering.py` applies the Gaussian filter independently to each time step, with MPI parallelization over the time dimension.
2. **Recombination:** `extract_space_recomb.py` recombines the spatially filtered chunks into full-domain files.

**Output naming convention:**

```text
${source_prior}/vct_<var>_<NNNN>_splf.nc

## 3. High-frequency std
### `prepare_hfstd.bash`

Computes the sample standard deviation of the high-frequency (HF) ensemble across all members. This estimate is used to calculate the observation-error standard deviation associated with the pseudo-observation vector.