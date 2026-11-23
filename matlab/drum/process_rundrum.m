% Function for processing outputs of setdrum.cpp
clc
clear
close all

% Additional matlab paths
addpath(fullfile('..','shared'));

% Input parameters
dpath = 'C:\Users\c.sunday\Desktop\simulation_data\rundrum\261114_130705';

% Container dimensions
container = struct('shape','cylinder','diameter',80,'height',20,'orientation','y');

% Create a directory for the results
rpath = fullfile(dpath,'results');
if exist(rpath,'dir')
    rmdir(rpath,'s');
end
mkdir(rpath);

% View the partitioning of computation time
view_timers(dpath,rpath);

% View the evolution of kinetic energy in the system
view_kinetic_energy(dpath,rpath);

% Get the list of data files in the test folder
[listbin,listcsv] = get_data_list(dpath);
if isempty(listbin)
    return;
end

% Import the last file in the data set
lastfile = fullfile(listbin(end).folder,listbin(end).name);
[dat,count] = import_state_bin(lastfile);

% View the system layout with the grains colored by a third variable
view_dynamic(dat,container,rpath,'vel_m','Colormap','rainbow', ...
    'Slice',[0 0 0],'SliceViews',"front");

% Find the angle of repose from the free surface of the bed
[theta,theta_err] = find_angle_of_repose(dat,container,rpath);
