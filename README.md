# Real‑Time GSR Stress Monitor

MATLAB script to collect and analyze GSR data in real-time.
* **gsr_live_acquire/** – real‑time DAQ, signal processing, and peak detection  

## Quick start
1. Open **gsr_live_acquire.m** and run.
2. After recording ends, open the generated `*_GSR.mat` for further analysis in MATLAB or open `_GSR.csv` and `_peaks.csv` for analysis in Excel, Sheets, etc.
3. Commit figures & `summary_metrics.csv` for your report.

## Required Materials
1. Software: MATLAB R2022+ with **Data Acquisition Toolbox**  
2. Hardware: NI USB‑6009 + GSR circuit (see report for details on circuit construction).
