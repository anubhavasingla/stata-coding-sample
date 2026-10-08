/*==============================================================================
  File:       03_merge_analysis_dataset.do
  Purpose:    Part 1, Section 8: Merge demographics, assets, and depression                   
              into a single individual-wave analysis dataset.
  Inputs:     ${tempdata}demographics_clean.dta
              ${tempdata}assets_hh_wave.dta
              ${tempdata}depression_clean.dta
  Outputs:    ${tempdata}analysis.dta
  
  MERGE STRATEGY
  ──────────────
  The analysis sample is defined by the depression dataset, since the K10
  was administered only to household heads and spouses — the population
  for whom the treatment (Group Therapy) was offered. We merge demographics
  and assets onto this spine.
  
      Depression  ← 1:1 →  Demographics   on (hhid, hhmid, wave)
      Depression  ← m:1 →  Assets         on (hhid, wave)
  
  Observations that exist only in demographics (other household members
  who were not heads/spouses) are not included.
==============================================================================*/

* Loading depression data
use "${tempdata}depression_clean.dta", clear

* Merging demographics 
merge 1:1 hhid hhmid wave using "${tempdata}demographics_clean.dta"

* Merge outcomes
tab _merge


keep if _merge == 3 
drop _merge

* Merging household-wave asset aggregates 
merge m:1 hhid wave using "${tempdata}assets_hh_wave.dta"

tab _merge

keep if _merge == 3
drop _merge

* Final verification
isid hhid hhmid wave
// Confirmed that unit of observation is individual × wave. 

* Check that each person has at most 2 observations (one per wave)
bysort hhid hhmid: gen n_waves = _N
assert n_waves <= 2
drop n_waves

* Checking treatment balance
tab treat_hh wave

* [Creating useful derived variables for analysis]

* Binary: woman indicator
gen woman = (gender == 5) if !mi(gender)
label var woman "Female (=1)"
label define woman_lbl 0 "Male" 1 "Female"
label values woman woman_lbl

* Log of total asset value (for regressions)
gen ln_assets = ln(total_asset_value + 1)
label var ln_assets "Log(1 + total asset value)"

* Baseline K10 score (for ANCOVA specifications)
* Carry Wave 1 kessler_score forward to Wave 2 observations
bysort hhid hhmid (wave): gen kessler_baseline = kessler_score[1]
label var kessler_baseline "Baseline Kessler score (Wave 1)"

* Confirm baseline is from Wave 1
assert kessler_baseline == kessler_score if wave == 1 & !mi(kessler_score)

* Saving analysis dataset 
compress
save "${tempdata}analysis.dta", replace

di as text "Analysis dataset saved: " as result "`c(N)'" as text " observations"
