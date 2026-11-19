% ------------------------------------------------------------------------
% Function to import simulation packing stats as a matlab table
%
% Input:   dpath    Path to the data folder containing the parameter file
% Output:  packing  Table containing the simulation packing stats   
% ------------------------------------------------------------------------

function [packing] = import_packing(dpath)

% Set the name of the packing stats file in the given data directory
filename = strcat(dpath, '\system_packing.txt');
if ~isfile(filename)
    fprintf(2,'\nWARNING: system_packing.txt does not exist in the specified directory!!\n\n');
end

% Convert the configuration file into a matlab structure
opts = detectImportOptions(filename, 'Delimiter', ' ', 'CommentStyle', '#', 'ReadRowNames', true, 'ReadVariableNames', false);
opts = setvaropts(opts, 'Var2', 'Type', 'char');
opts.DataLines = [2 Inf];

packing = readtable(filename, opts);
packing = rows2vars(packing);
packing = packing(:,2:end);

% Convert certain table entries to type 'double'
packing.container_volume = str2double(packing.container_volume);
packing.xlim_min = str2double(packing.xlim_min);
packing.xlim_max = str2double(packing.xlim_max);
packing.ylim_min = str2double(packing.ylim_min);
packing.ylim_max = str2double(packing.ylim_max);
packing.zlim_min = str2double(packing.zlim_min);
packing.zlim_max = str2double(packing.zlim_max);
packing.num_grains = str2double(packing.num_grains);
packing.grain_mass = str2double(packing.grain_mass);
packing.grain_volume = str2double(packing.grain_volume);
packing.packing_fraction = str2double(packing.packing_fraction);
packing.bulk_density = str2double(packing.bulk_density);

end