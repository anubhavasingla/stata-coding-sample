/*==============================================================================
  File:       04_exploratory_analysis.do
  Purpose:    Part 2: Explore the relationship between depression and
              (a) household wealth, (b) gender, (c) household size —
              using Wave 1 (pre-intervention) data.
  Inputs:     ${tempdata}analysis.dta
  Outputs:    Figures:
                ${output}fig_wealth_depression.png
                ${output}fig_gender_density.png
                ${output}fig_hhsize_depression.png
              Tables (LaTeX):
                ${output}tab_wealth_quartiles.tex
                ${output}tab_wealth_reg.tex
                ${output}tab_gender_summary.tex
                ${output}tab_hhsize_reg.tex
  
  All analyses use Wave 1 data collected prior to treatment assignment.
  Relationships are descriptive correlations, not causal effects.
==============================================================================*/

use "${tempdata}analysis.dta", clear
keep if wave == 1


/*──────────────────────────────────────────────────────────────────────────────
  DEPRESSION AND HOUSEHOLD WEALTH
──────────────────────────────────────────────────────────────────────────────*/

* Wealth quartiles
xtile wealth_q = total_asset_value, nq(4)
label define wq_lbl 1 "Q1 (Poorest)" 2 "Q2" 3 "Q3" 4 "Q4 (Richest)"
label values wealth_q wq_lbl

gen severe = (kessler_cat == 4) if !mi(kessler_cat)

* Summary by quartile (Also eventually exporting to LaTeX)
estpost tabstat kessler_score severe if !mi(kessler_score), ///
    by(wealth_q) stat(count mean sd) columns(stat) nototal
esttab using "${output}tab_wealth_quartiles.tex", ///
    cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2))") ///
    noobs replace booktabs ///
    title("Baseline Depression by Household Wealth Quartile")

* Figure 1: Binned scatter — K10 on log(assets)
preserve
    xtile asset_bin = ln_assets, nq(20)
    collapse (mean) kessler_score ln_assets, by(asset_bin)
    
    twoway (scatter kessler_score ln_assets, ///
                msymbol(circle) msize(medium) mcolor(navy%80)) ///
           (lfit kessler_score ln_assets, ///
                lcolor(cranberry) lwidth(medthick)), ///
        xtitle("Log(1 + total asset value) (Wave 1, bin mean)") ///
        ytitle("Mean Kessler score (Wave 1)") ///
        title("Wave 1: Depression and Household Wealth (log scale, binned means)") ///
        legend(off) ///
        note("Each point represents the mean Kessler score within a 5-percentile" ///
             "bin of log household asset values. Line shows OLS fit.") ///
        scheme(s2color)

    graph export "${output}fig_wealth_depression.png", width(1800) replace
restore

drop severe

* Regression: K10 on log(assets) 
eststo clear

reg kessler_score ln_assets, vce(cluster hhid)
eststo m1

reg kessler_score ln_assets age woman hh_size, vce(cluster hhid)
eststo m2

esttab m1 m2 using "${output}tab_wealth_reg.tex", ///
    replace booktabs ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(3) se(3) ///
    label ///
    mtitles("Bivariate" "With controls") ///
    stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
    title("Descriptive Regression: Depression on Household Wealth (Wave 1)") ///
    addnotes("Standard errors clustered at household level." ///
             "Dependent variable: Kessler-10 score (10--50).")


/*──────────────────────────────────────────────────────────────────────────────
  DEPRESSION AND GENDER
──────────────────────────────────────────────────────────────────────────────*/

* Summary table 
gen mod_severe = (kessler_cat >= 3) if !mi(kessler_cat)

estpost tabstat kessler_score mod_severe if !mi(kessler_score), ///
    by(woman) stat(count mean sd) columns(stat) nototal
esttab using "${output}tab_gender_summary.tex", ///
    cells("count(fmt(0)) mean(fmt(2)) sd(fmt(2))") ///
    noobs replace booktabs ///
    title("Baseline Depression by Gender")

* Figure 2: Overlapping kernel densities by gender
twoway (kdensity kessler_score if woman == 0, ///
            lcolor(navy) lwidth(medthick) lpattern(solid)) ///
       (kdensity kessler_score if woman == 1, ///
            lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
    xtitle("Kessler score (Wave 1)") ///
    ytitle("Density") ///
    title("Wave 1: Distribution of Kessler Scores by Gender") ///
    legend(order(1 "Male" 2 "Female") ring(0) pos(2)) ///
    scheme(s2color)

graph export "${output}fig_gender_density.png", width(1800) replace

drop mod_severe


/*──────────────────────────────────────────────────────────────────────────────
  DEPRESSION AND HOUSEHOLD SIZE
──────────────────────────────────────────────────────────────────────────────*/

* Figure 3: Mean K10 by household size (with observation-weighted markers)
preserve
    collapse (mean) kessler_score (count) n = kessler_score, by(hh_size)
    
    twoway (scatter kessler_score hh_size [aw = n], ///
                msymbol(circle) mcolor(navy%60)) ///
           (lfit kessler_score hh_size [aw = n], ///
                lcolor(cranberry) lwidth(medthick)), ///
        xtitle("Household size") ///
        ytitle("Mean Kessler score (Wave 1)") ///
        title("Wave 1: Mean Depression by Household Size (weighted trend)") ///
        legend(label(1 "Mean (marker size = observations)") ///
               label(2 "Weighted linear fit") ring(0) pos(5)) ///
        scheme(s2color)

    graph export "${output}fig_hhsize_depression.png", width(1800) replace
restore

* Regression: K10 on household size 
eststo clear

reg kessler_score hh_size, vce(cluster hhid)
eststo m_hhsize

esttab m_hhsize using "${output}tab_hhsize_reg.tex", ///
    replace booktabs ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(3) se(3) ///
    label ///
    stats(N r2, labels("Observations" "R-squared") fmt(0 3)) ///
    title("Descriptive Regression: Depression on Household Size (Wave 1)") ///
    addnotes("Standard errors clustered at household level." ///
             "Dependent variable: Kessler-10 score (10--50).")
