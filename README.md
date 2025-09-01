# GTES6000GZh Simulation Scripts

This repository contains MATLAB scripts that programmatically build and
simulate a Simulink model of the **GTES-6000-ГЖ** 6 MW gas turbine generator.
The model uses Simscape Electrical Specialized Power Systems.

## Files
- `build_GT6000.m` – creates `GTES6000GZh.slx` with gas turbine, governor,
  synchronous generator, excitation system, transformer and grid interface.
- `ggov1_sfunc.m` – simplified IEEE GGOV1 governor-turbine S-function.
- `run_year_GT6000.m` – runs a 1‑year phasor simulation with minute
  resolution and exports `minute_results.csv` and `KPIs.txt`.
- `run_emt_test.m` – 120‑s electromagnetic transient test including a 100 ms
  three‑phase fault.

## Usage
In MATLAB/Simulink with Simscape Electrical Specialized Power Systems:

```matlab
>> build_GT6000        % create GTES6000GZh.slx
>> run_emt_test        % quick dynamic verification
>> run_year_GT6000     % full year simulation, exports CSV and KPIs
```

Default parameters follow manufacturer data when available; other values are
marked as *assumed* in the code and may be edited in the builder script.
