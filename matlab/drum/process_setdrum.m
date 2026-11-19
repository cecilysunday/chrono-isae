% Function for processing outputs of setdrum.cpp
clc
clear
close all

% Additional matlab paths
addpath(fullfile('..','shared'));

% Input parameters
dpath = 'C:\Users\c.sunday\Desktop\simulation_data\setdrum\261109_095348';

% Create a directory for the results
rpath = fullfile(dpath,'results');
if exist(rpath,'dir')
    rmdir(rpath,'s');
end
mkdir(rpath);

% Get the list of data files in the test folder
[listbin,listcsv] = get_data_list(dpath);
if isempty(listbin)
    return;
end

% Import the last file in the data set
lastfile = fullfile(listbin(end).folder,listbin(end).name);
[dat,count] = import_state_bin(lastfile);

% View the system layout and particle size distribution
view_positions(dat,rpath);

% View the evolution of kinetic energy in the system
view_kinetic_energy(dpath,rpath);

% View the partitioning of computation time
view_timers(dpath,rpath);
