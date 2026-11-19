% ------------------------------------------------------------------------
% Function to import the general simulation stats as a matlab table
%
% Input:   dpath   Path to the data folder containing the parameter file
% Output:  stats   Table containing the general simulation statistics    
% ------------------------------------------------------------------------

function [stats] = import_stats(dpath)

% Set the name of the simulation stats file in the given data directory
filename = strcat(dpath,'\system_stats.txt');
if ~isfile(filename) 
    fprintf(2,'\nWARNING: system_stats.txt does not exist in the specified directory!!\n\n');
end

% Import the stats file as a table of doubles
opts = detectImportOptions(filename, 'Delimiter', ' ', 'CommentStyle', '#', 'ReadRowNames', true, 'ReadVariableNames', false);
opts = setvaropts(opts, 'Var2', 'Type', 'double');
opts.DataLines = [2 Inf];

stats = readtable(filename, opts);
stats = rows2vars(stats);
stats = stats(:,2:end);

end