% -------------------------------------------------------------------------
% FUNCTION  get_data_list   Get a list of all data files in a given directory
% INPUTS    dpath           Data directory
% OUTPUTS   listbin         List of all binary files in the directory
%           listcsv         List of all csv files in the directory
% -------------------------------------------------------------------------
function [listbin, listcsv] = get_data_list(dpath)

listbin=dir(fullfile(dpath,'*.bin'));
if isempty(listbin)
    warning("Folder does not contain .bin files.\n");
end

listcsv=dir(fullfile(dpath,'*.csv'));
if isempty(listcsv)
    warning("Folder does not contain .csv files.\n");
end

end