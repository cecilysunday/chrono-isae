% ------------------------------------------------------------------------
% Function to import simulation energy file as a matlab table
%
% Input:   dpath    Path to the data folder containing the parameter file
% Output:  energy   Table containing the simulation kinetic energy data    
% ------------------------------------------------------------------------

function [energy] = import_energy(dpath)

% Set the name of the parameter file in the given data directory
filename = strcat(dpath,'\system_energy.txt');
if ~isfile(filename) 
    fprintf(2,'\nWARNING: system_energy.txt does not exist in the specified directory!!\n\n');
end

% Import the energy file as a table
opts = detectImportOptions(filename);
energy = readtable(filename,opts);

end