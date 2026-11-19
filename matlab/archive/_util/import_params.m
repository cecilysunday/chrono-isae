% ------------------------------------------------------------------------
% Function to import simulation parameter file as a matlab table
%
% Input:   dpath   path to the data folder containing the parameter file
% Output:  params  table containing the simulation parameters    
% ------------------------------------------------------------------------

function [params] = import_params(dpath)

% Set the name of the parameter file in the given data directory
filename = strcat(dpath,'\system_params.txt');
if ~isfile(filename) 
    fprintf(2,'\nWARNING: system_params.txt does not exist in the specified directory!!\n\n');
end

% Import the parameter file as a table of strings
opts = detectImportOptions(filename, 'Delimiter', ' ', 'CommentStyle', '#', 'ReadRowNames', true, 'ReadVariableNames', false);
opts = setvaropts(opts, 'Var2', 'Type', 'char');
opts.DataLines = [2 Inf];

params = readtable(filename, opts);
params = rows2vars(params);
params = params(:,2:end);
   
% Convert certain table entries to type 'double'
params.youngs = str2double(params.youngs);
params.poisson = str2double(params.poisson);
params.mu_pp = str2double(params.mu_pp);
params.mu_pw = str2double(params.mu_pw);
params.mu_roll = str2double(params.mu_roll);
params.mu_spin = str2double(params.mu_spin);
params.cor_pp = str2double(params.cor_pp);
params.cor_pw = str2double(params.cor_pw);
params.ad = str2double(params.ad);

params.clength_x = str2double(params.clength_x);
params.clength_y = str2double(params.clength_y);
params.clength_z = str2double(params.clength_z);
params.cthickness = str2double(params.cthickness);
params.cmass = str2double(params.cmass);

params.gdia = str2double(params.gdia);
params.gmarg = str2double(params.gmarg);
params.grho = str2double(params.grho);
params.gvel = str2double(params.gvel);
params.gmass = str2double(params.gmass);

params.grav_x = str2double(params.grav_x);
params.grav_y = str2double(params.grav_y);
params.grav_z = str2double(params.grav_z);
params.time_step = str2double(params.time_step);
params.time_loop = str2double(params.time_loop);
params.time_save = str2double(params.time_save);
params.sim_duration = str2double(params.sim_duration);

params.tolerance = str2double(params.tolerance);
params.min_roll_vel = str2double(params.min_roll_vel);
params.min_spin_vel = str2double(params.min_spin_vel);
params.max_itbilateral = str2double(params.max_itbilateral);
params.bpa_x = str2double(params.bpa_x);
params.bpa_y = str2double(params.bpa_y);
params.bpa_z = str2double(params.bpa_z);

end