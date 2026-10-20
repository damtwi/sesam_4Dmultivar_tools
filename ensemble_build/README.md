Script to perform ensemble observational update
===============================================

1. Preparation of the PRIOR Ensemble (facultative)
--------------------------------------------------

	a. Preparation of the prior ensemble
	____________________________________

extract_ts_prior_time.bash
->time-along filtering

comb_ts.bash
-> rebuild the chunked time-filtering data
-> split first time step of the chunk file in extract_block & open_netcdf

extract_ts_prior_space.bash
-> space filtering
-> rebuild the chunked space-filtering data
