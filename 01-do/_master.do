/*==============================================================================
  Project:    Group Therapy RCT in Ghana
  Author:     Anubhava Singla
  Created:    January 2026
  Purpose:    Master do-file. Sets globals, installs packages, and runs all
              analysis scripts in sequence.
  
  INSTRUCTIONS
  ────────────
  1.  Set the macro `root' below to the top-level project folder on your machine.
  2.  Run this file. It will execute every subsequent do-file in order.
  
  FOLDER STRUCTURE
  ────────────────
  root/
  ├── 01-do/            ← do-files (this folder)
  ├── 02-rawdata/       ← .dta files as received (never modified)
  ├── 03-tempdata/      ← intermediate datasets
  ├── 04-output/        ← tables, figures, logs
  └── 05-writeup/       ← supplementary document
==============================================================================*/

* ── Housekeeping ──────────────────────────────────────────────────────────────
clear all
set more off
cap log close
version 17                   // pin Stata version for reproducibility

* ── Root path (EDIT THIS) ─────────────────────────────────────────────────────
* Detect user and set path automatically; add your own block.
if (lower("`c(username)'") == "yourname") {
    global root "/Users/yourname/Projects/JPAL_GPRL/"
}
else {
    * Fallback — edit before running
    global root "SET_YOUR_PATH_HERE/"
}

* ── Derived globals (do not edit) ─────────────────────────────────────────────
global dofiles  "${root}01-do/"
global rawdata  "${root}02-rawdata/"
global tempdata "${root}03-tempdata/"
global output   "${root}04-output/"

* Create output directories if they don't exist
cap mkdir "${tempdata}"
cap mkdir "${output}"

* ── Install user-written packages (first run only) ────────────────────────────
foreach pkg in estout reghdfe ftools {
    cap which `pkg'
    if _rc  ssc install `pkg', replace
}

* ── Open log ──────────────────────────────────────────────────────────────────
log using "${output}master_log.smcl", replace name(master)

* ── Run analysis pipeline ─────────────────────────────────────────────────────
do "${dofiles}01_data_preparation.do"
do "${dofiles}02_kessler_construction.do"
do "${dofiles}03_merge_analysis_dataset.do"
do "${dofiles}04_exploratory_analysis.do"
do "${dofiles}05_rct_evaluation.do"

log close master
