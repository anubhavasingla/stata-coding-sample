/*==============================================================================
  File:       01_data_preparation.do
  Purpose:    Part 1, Sections 1–5: Identify units of observation, construct
              household size, impute missing asset values and compute asset 
			  aggregates.
  Inputs:     ${rawdata}demographics.dta, ${rawdata}assets.dta
  Outputs:    ${tempdata}demographics_clean.dta
              ${tempdata}assets_hh_wave.dta
==============================================================================*/


/*──────────────────────────────────────────────────────────────────────────────
  1. UNIT OF OBSERVATION AND UNIQUE IDENTIFIERS
──────────────────────────────────────────────────────────────────────────────*/

* [Demographics] 
* Unit: individual household member × wave.
* Unique ID: (hhid, hhmid, wave).

use "${rawdata}demographics.dta", clear

isid hhid hhmid wave
//Confirmed if each row is one household member observed in one wave. 

* [Assets] 
* Unit: individual asset record within a household × wave.
* The dataset contains three asset categories (Asset_Type = 1 animals, 
* 2 tools, 3 durable goods). Within each category an InstanceNumber
* indexes separate items.
* Unique ID: (hhid, wave, Asset_Type, InstanceNumber).

use "${rawdata}assets.dta", clear

* NOTE: hhid is stored as string in assets.dta (with leading zeros) but as
* numeric in demographics.dta and depression.dta. Destring here so that
* merges work correctly downstream.
destring hhid, replace force
format hhid %12.0f

isid hhid wave Asset_Type InstanceNumber
// Confirmef if each row is one asset instance within a household-wave.

* [Depression] 
* Unit: individual (head or spouse) × wave.
* Unique ID: (hhid, hhmid, wave).

use "${rawdata}depression.dta", clear

isid hhid hhmid wave
// Confirmed if each row is one individual observed in one wave. 


/*──────────────────────────────────────────────────────────────────────────────
  2. CONSTRUCTING HOUSEHOLD SIZE (DEMOGRAPHICS)
──────────────────────────────────────────────────────────────────────────────
  
  What did I do - counted the number of members rostered in Wave 1 for 
  each household. Per instructions, I hold this value fixed for Wave 2 so that 
  household size is a pre-treatment baseline characteristic and is not itself 
  affected by the intervention.
──────────────────────────────────────────────────────────────────────────────*/

use "${rawdata}demographics.dta", clear

* Counting members per household in Wave 1 only
bysort hhid: egen hh_size = total(wave == 1)
label var hh_size "Household size (count of Wave 1 roster members)"

save "${tempdata}demographics_clean.dta", replace


/*──────────────────────────────────────────────────────────────────────────────
  3. IMPUTING MISSING CURRENT VALUES (ASSETS)
──────────────────────────────────────────────────────────────────────────────
  
  currentvalue reports the value of a single unit of each asset. It is
  reported to be missing. 
  
  What did I do - I will impute using the median of currentvalue for each asset 
  *iwtem* — i.e., "chickens", "cutlass", etc.

  Asset items are identified by the combination of Asset_Type and the
  relevant code variable within that type:
      Asset_Type 1 (Animals):       animaltype
      Asset_Type 2 (Tools):         toolcode
      Asset_Type 3 (Durable Goods): durablegood_code

  I construct a single consolidated item code (`item_code`) so that the
  median imputation is done at the correct item level across all three
  asset categories.
──────────────────────────────────────────────────────────────────────────────*/

use "${rawdata}assets.dta", clear

destring hhid, replace force
format hhid %12.0f

* Dropped observations with missing asset type
count if mi(Asset_Type)
drop if mi(Asset_Type)

* [Creating consolidated item code]
* Each Asset_Type has its own code variable. We create a unified item
* identifier by combining Asset_Type and the item-specific code.
* This ensures, e.g., code "1" in animals ≠ code "1" in tools.

gen item_code = .
replace item_code = animaltype     if Asset_Type == 1
replace item_code = toolcode       if Asset_Type == 2
replace item_code = durablegood_code if Asset_Type == 3

label var item_code "Consolidated asset item code (within Asset_Type)"

* Imputing missing currentvalue using item-level median
* Step 1: Compute median by specific item
bysort Asset_Type item_code: egen med_value = median(currentvalue)
replace currentvalue = med_value if mi(currentvalue)

* Step 2: If still missing (item has no observed prices), fall back to
*         median by Asset_Type overall
bysort Asset_Type: egen med_value_type = median(currentvalue)
replace currentvalue = med_value_type if mi(currentvalue)

* Report remaining missingness
count if mi(currentvalue)
/* Any remaining missing values are items with zero observed prices
   across the entire asset category (very rare). */

drop med_value med_value_type


/*──────────────────────────────────────────────────────────────────────────────
  4. COMPUTED OBSERVATION-LEVEL TOTAL ASSET VALUE
──────────────────────────────────────────────────────────────────────────────*/

gen asset_value = quantity * currentvalue
label var asset_value "Total value of this asset observation (qty × unit value)"

* Flagging observations where value could not be computed
count if mi(asset_value) & !mi(quantity)


/*──────────────────────────────────────────────────────────────────────────────
  5. AGGREGATE TO HOUSEHOLD-WAVE LEVEL
──────────────────────────────────────────────────────────────────────────────
  
  Produce a dataset with one row per household × wave, containing:
    - total_val_animals
    - total_val_tools
    - total_val_durables
    - total_asset_value  (sum of the three)
──────────────────────────────────────────────────────────────────────────────*/

* Collapsing by household-wave-asset type
collapse (sum) asset_value, by(hhid wave Asset_Type)

* Reshaping so each asset type becomes its own column
reshape wide asset_value, i(hhid wave) j(Asset_Type)

rename asset_value1 total_val_animals
rename asset_value2 total_val_tools
rename asset_value3 total_val_durables

label var total_val_animals  "Total value of animals"
label var total_val_tools    "Total value of tools"
label var total_val_durables "Total value of durable goods"

* Replaced missing with 0 (household owns none of that category)
foreach v of varlist total_val_animals total_val_tools total_val_durables {
    replace `v' = 0 if mi(`v')
}

* Total across all categories
gen total_asset_value = total_val_animals + total_val_tools + total_val_durables
label var total_asset_value "Total household asset value (all categories)"


save "${tempdata}assets_hh_wave.dta", replace
