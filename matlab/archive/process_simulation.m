clc
clear all
close all

% Path to utility functions for importing and plotting simulation data
addpath(fullfile('.','_util'));

% Specify the data directory containing the simulation files to process
dpath = 'C:\Users\c.sunday\Desktop\simulation_data\setdrum\261109_095348';

% Import standard simulation files into matlab as data tables
energy = import_energy(dpath);
params = import_params(dpath);
packing = import_packing(dpath);
stats = import_stats(dpath);

% Import the final state data for all of the particles in the system
fstate = import_state_bin(strcat(dpath,'\state_final.bin'));

% Generate system plots
plot_energy(energy);
plot_stats(stats);
plot_grain_distribution(fstate);