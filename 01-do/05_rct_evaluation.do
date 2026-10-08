/*==============================================================================
  File:       05_rct_evaluation.do
  Purpose:    Part 2, Section 2 and 3: Estimate treatment effects of Group 
              Therapy on depression; examine gender heterogeneity.
  Inputs:     ${tempdata}analysis.dta
  Outputs:    ${output}table_treatment_effects.tex
              ${output}table_gender_heterogeneity.tex
  
  ECONOMETRIC FRAMEWORK
  ─────────────────────
  Treatment was randomly assigned at the household level after Wave 1.
  Heads and spouses in treated households were invited to Group Therapy.
  We assume perfect compliance (as instructed).
  
  Under random assignment:
  - Simple difference-in-means (DIM) gives an unbiased ATE.
  - ANCOVA (controlling for baseline K10) improves precision by absorbing
    persistent individual variation in depression (McKenzie 2012).
  - Standard errors are clustered at the household level (the unit of 
    treatment assignment).
==============================================================================*/

use "${tempdata}analysis.dta", clear


/*──────────────────────────────────────────────────────────────────────────────
  2. WERE THE GT SESSIONS EFFECTIVE AT REDUCING DEPRESSION?
──────────────────────────────────────────────────────────────────────────────*/

* Verifing randomization through balance check on baseline characteristics 

preserve
keep if wave == 1

foreach var in kessler_score age woman hh_size total_asset_value {
    di as text _n "Balance check: `var'"
    reg `var' treat_hh, vce(cluster hhid)
}
restore

* Treatment effect estimation (Wave 2 outcomes)
preserve
keep if wave == 2 & !mi(kessler_score)

eststo clear

* Model 1: Simple difference-in-means
*   Kessler_i2 = α + β·Treat_h + ε_ih
reg kessler_score treat_hh, vce(cluster hhid)
eststo m_dim
estadd scalar control_mean = _b[_cons]

* Model 2: ANCOVA — control for baseline K10
*   Kessler_i2 = α + β·Treat_h + γ·Kessler_i1 + ε_ih
*
*   Preferred specification. Under random assignment, both models are
*   unbiased for the ATE. ANCOVA reduces residual variance by exploiting
*   the strong serial correlation in K10 scores, yielding more precise
*   estimates (Bruhn & McKenzie 2009).
reg kessler_score treat_hh kessler_baseline, vce(cluster hhid)
eststo m_ancova
estadd scalar control_mean = _b[_cons] + _b[kessler_baseline] * 20.3
    // approximate: control mean of baseline K10 ≈ 20.3

* Model 3: ANCOVA with demographic controls
*   Adding controls that are pre-determined (age, gender, hh size) should
*   not change the point estimate under valid randomization, but can
*   further improve precision.
reg kessler_score treat_hh kessler_baseline age woman hh_size, vce(cluster hhid)
eststo m_full

* Exporting table 
esttab m_dim m_ancova m_full using "${output}table_treatment_effects.tex", ///
    replace booktabs ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(3) se(3) ///
    keep(treat_hh kessler_baseline age woman hh_size) ///
    label ///
    mtitles("Diff-in-means" "ANCOVA" "ANCOVA + controls") ///
    stats(N r2 control_mean, ///
          labels("Observations" "R-squared" "Control group mean") ///
          fmt(0 3 2)) ///
    title("Treatment Effects on Depression (Wave 2 Outcomes)") ///
    addnotes("Standard errors clustered at household level." ///
             "Dependent variable: Kessler-10 score (10–50)." ///
             "ANCOVA controls for individual baseline (Wave 1) Kessler score.")

restore


/*──────────────────────────────────────────────────────────────────────────────
  3. DID THE EFFECT DIFFER BY GENDER?
──────────────────────────────────────────────────────────────────────────────
  
  Specification (as prescribed in the instructions):
  
      Kessler_i2 = α + β₁·Woman_i + β₂·Treat_h + β₃·(Woman_i × Treat_h) + ε_ih
  
  Interpretation of coefficients:
  
      α   = Mean K10 for men in control households (reference group)
      β₁  = Gender gap: difference in K10 for women vs. men, within
             control households
      β₂  = Treatment effect for men
      β₃  = Differential treatment effect for women relative to men.
             The total treatment effect for women is β₂ + β₃.
  
  We use Wave 2 data only, with SEs clustered at the household level.
──────────────────────────────────────────────────────────────────────────────*/

preserve
keep if wave == 2 & !mi(kessler_score)

eststo clear

* No additional controls
reg kessler_score woman treat_hh c.treat_hh#c.woman, vce(cluster hhid)
eststo m_het

* Computing and testing the total treatment effect for women
lincom treat_hh + c.treat_hh#c.woman
/* This gives us the point estimate and CI for the female-specific
   treatment effect (β₂ + β₃). */

* Extended specification with baseline control 
reg kessler_score woman treat_hh c.treat_hh#c.woman kessler_baseline, ///
    vce(cluster hhid)
eststo m_het_ancova

lincom treat_hh + c.treat_hh#c.woman

* Exporting table 
esttab m_het m_het_ancova using "${output}table_gender_heterogeneity.tex", ///
    replace booktabs ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(3) se(3) ///
    order(woman treat_hh c.treat_hh#c.woman kessler_baseline) ///
    label ///
    mtitles("Prescribed spec." "With baseline control") ///
    stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
    title("Gender Heterogeneity in Treatment Effects (Wave 2)") ///
    addnotes("Standard errors clustered at household level." ///
             "Dependent variable: Kessler-10 score (10–50)." ///
             "Reference group: men in control households." ///
             "Total treatment effect for women = Treat + Treat×Woman.")

restore
