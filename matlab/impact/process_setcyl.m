% Function for processing outputs of setdrum.cpp
clc
clear
close all

% Additional matlab paths
addpath(fullfile('..','shared'));

% Input parameters
dpath ='/home/deos/c.sunday/Bureau/data/runimpact/261113_235741';

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
% Cylinder: diameter = clength_x = clength_y, height = clength_z, axis
% along z, floor at z = 0
container = struct('shape','cylinder','diameter',500,'height',200, ...
    'orientation','z','center',[0 0 100]);
view_static(dat,container,rpath);
view_dynamic(dat,container,rpath,'vel_m',[1 10]);

% View the evolution of kinetic energy in the system
view_kinetic_energy(dpath,rpath);

% View the partitioning of computation time
view_timers(dpath,rpath);
