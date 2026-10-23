# Ensemble estimation of the low-frequency component of ocean dynamic height from satellite altimetry

This repository contains a collection of Bash and Python tools to produce an
ensemble estimate (3D + time) of the low-frequency component of ocean dynamic
height by combining an ensemble model simulation with observations.

The reference application is the Mediterranean Sea at a 1/12° resolution,
using an ensemble simulation produced by Héron et al. (2026) and observations
from satellite altimetry, Argo floats, CTD casts and gliders. The workflow is
built around the [SESAM](https://github.com/brankart/sesam) toolbox.

The repository covers the complete chain:

1. `ensemble_build`: construction of a low-frequency prior ensemble from the model simulation;
2. `prepare_obs`: preparation of the observational datasets in SESAM format;
3. `inversion_script`: ensemble observational update with an MCMC sampler in an OSSE
   (Observing System Simulation Experiment) framework;
4. post-processing and probabilistic diagnostics of the posterior ensemble.

## Observation Data Sources

 - **Source Glider:** [SEANOE dataset 00409/52027](https://www.seanoe.org/data/00409/52027/)
 - **Source CTD:** [Ifremer oceanographic cruise series 235](https://campagnes.flotteoceanographique.fr/series/235/)
 - **Source Argo:** Data retrieved using the Python [argopy](https://argopy.readthedocs.io/) library.
 - **Source Satellite altimetry:** CMEMS along-track L3 product, product ID `SEALEVEL_GLO_PHY_L3_MY_008_062` ([Copernicus Marine Service](https://marine.copernicus.eu/)).

The original observational datasets are not distributed with this repository. Users must download the data from the sources listed above and adapt the paths and filenames in the observation-preparation scripts as needed.


### Output data

The output is an ensemble of possible solutions (in 3D+time) for the low-frequency dynamic of the North-East Mediterranean Sea.