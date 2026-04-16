%% High-Lift System Sizing - Fowler Flaps + Leading Edge Slats
%  Roskam Part VI, Chapter 8 methodology
%  3D baseline from OpenVSP (VSPAERO) clean-wing aerodynamic data
%
%  Usage: Run this main script. Envokes flaplift script function to run
%         the rest of the analysis.
%         All configuration is in AircraftConfig.m.
%         Empirical data is in LoadRoskamData.m.
%
%  Plot Certain Conditions:
%    After running, inspect any (df, ds) config from the command window:
%    example: >> PlotConfig(tradeResults, VSP, ac, clean, 10, 25)

clc; clear; close all

[tradeResults, VSP, ac, clean] = flaplift();