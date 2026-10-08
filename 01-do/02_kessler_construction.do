/*==============================================================================
  File:       02_kessler_construction.do
  Purpose:    Part 1, sections 6–7: Construct K10 score and categories; tabulate
              distribution by wave.
  Inputs:     ${rawdata}depression.dta
  Outputs:    ${tempdata}depression_clean.dta
  
  NOTES ON MISSING-VALUE HANDLING
  ───────────────────────────────
  The K10 is the simple sum of 10 items, each scored 1–5, yielding a range
  of 10–50. Two decisions arise when items are missing:
  
  (a) Fully missing respondents (all 10 items missing): these individuals
      did not complete the module. They are dropped. 
  
  (b) Partially missing respondents (1–9 items answered): the exam 
      instructions note that "sometimes variables in the Kessler section
      are missing, which can complicate construction of a score."
      
      I treat the K10 as missing if ANY of the 10 items is missing. This
      conservative approach avoids understating distress due to item
      non-response. An alternative would be pro-rating (scaling the sum
      of answered items), but this introduces measurement noise and could
      bias results if missingness is non-random. Given that <2% of 
      respondents have partial missingness, the cost of dropping them is
      small relative to the risk of measurement error.
==============================================================================*/

use "${rawdata}depression.dta", clear

format hhid %12.0f

* Inspect the 10 K10 items 
local k10_items tired nervous sonervous hopeless restless sorestless ///
               depressed everythingeffort nothingcheerup worthless

foreach var of local k10_items {
    tab `var', mi
}

* Count non-missing items per respondent 
egen k10_nonmiss = rownonmiss(`k10_items')
tab k10_nonmiss, mi

* Drop fully missing respondents (no information) 
drop if k10_nonmiss == 0

* [Construct K10 score] 
*    Sum all 10 items. If any item is missing, the sum is missing (Stata
*    default for gen/egen with missing values uses rowtotal with the
*    missing option turned off). We use an explicit check.

egen k10_raw = rowtotal(`k10_items'), missing
/*  rowtotal(..., missing) returns missing if ALL items are missing.
    But we want missing if ANY item is missing. So: */

gen kessler_score = k10_raw if k10_nonmiss == 10
label var kessler_score "Kessler-10 score (sum of 10 items, 10–50)"

* Report how many observations have partial missingness
count if k10_nonmiss > 0 & k10_nonmiss < 10
/* These observations are retained in the dataset but will have
   kessler_score == . and will be excluded from K10-based analyses. */

drop k10_raw k10_nonmiss


* Construct Kessler categories 
*    Standard thresholds from the K10 manual:
*      10–19: No significant depression
*      20–24: Mild depression
*      25–29: Moderate depression
*      30–50: Severe depression

gen kessler_cat = .
replace kessler_cat = 1 if inrange(kessler_score, 10, 19)
replace kessler_cat = 2 if inrange(kessler_score, 20, 24)
replace kessler_cat = 3 if inrange(kessler_score, 25, 29)
replace kessler_cat = 4 if inrange(kessler_score, 30, 50)

label define kcat_lbl ///
    1 "No significant depression (10–19)" ///
    2 "Mild depression (20–24)" ///
    3 "Moderate depression (25–29)" ///
    4 "Severe depression (30–50)"

label values kessler_cat kcat_lbl
label var kessler_cat "Kessler depression category"



/*──────────────────────────────────────────────────────────────────────────────
  7. DISTRIBUTION ACROSS KESSLER CATEGORIES BY WAVE
──────────────────────────────────────────────────────────────────────────────*/

* Tabulate (row percentages within each wave)
tab wave kessler_cat if !mi(kessler_cat), row nofreq

* Exporting a clean version for the write-up
estpost tab wave kessler_cat if !mi(kessler_cat)
esttab using "${output}table_kessler_by_wave.csv", ///
    cell(colpct(fmt(1))) unstack noobs replace


save "${tempdata}depression_clean.dta", replace
