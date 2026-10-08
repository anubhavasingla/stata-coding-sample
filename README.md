# Evaluating Group Therapy for Depression: RCT in Ghana

## Project Structure

```
├── 01-do/
│   ├── _master.do                  ← Run this file (set root path first)
│   ├── 01_data_preparation.do      ← IDs, household size, asset imputation & aggregation
│   ├── 02_kessler_construction.do  ← K10 score construction, categories, wave distribution
│   ├── 03_merge_analysis_dataset.do← Merge into individual-wave analysis dataset
│   ├── 04_exploratory_analysis.do  ← Wealth, gender, household size & depression (Wave 1)
│   └── 05_rct_evaluation.do        ← Treatment effects, gender heterogeneity (Wave 2)
├── 02-rawdata/                     ← Original .dta files (never modified)
│   ├── demographics.dta
│   ├── assets.dta
│   └── depression.dta
├── 03-tempdata/                    ← Intermediate datasets (created by code)
├── 04-output/                      ← Tables (.tex), figures (.png), log files
└── 05-writeup/
    ├── report.tex                  ← Full write-up (LaTeX source)
    └── report.pdf                  ← Compiled PDF
```

## How to Run

1. Open `01-do/_master.do` and set the `root` global to your project folder path.
2. Run `_master.do` in Stata. It will install required packages and execute all do-files in sequence.
3. Figures and tables are exported to `04-output/` and referenced in the LaTeX write-up.
4. To recompile the write-up, copy the figures from `04-output/` into `05-writeup/` and run `pdflatex report.tex` twice.

## Requirements

- Stata 17+
- User-written packages: `estout`, `reghdfe`, `ftools` (auto-installed on first run)
- LaTeX distribution (for recompiling the write-up)
