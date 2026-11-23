% -------------------------------------------------------------------------
% FUNCTION  get_data_list   Get a list of all data files in a given directory
% INPUTS    dpath           Data directory
% OUTPUTS   listbin         List of all binary files in the directory
%           listcsv         List of all csv files in the directory
%
% NOTES     - Exclude intruder files. Only consider grain state files.
% -------------------------------------------------------------------------
function [listbin, listcsv] = get_data_list(dpath)

exclude = {'state_single_body'};

listbin=dir(fullfile(dpath,'*.bin'));
[~,names] = cellfun(@fileparts, {listbin.name}, 'UniformOutput', false);
listbin(ismember(names, exclude)) = [];
if isempty(listbin)
    warning("Folder does not contain .bin files.\n");
end

listcsv=dir(fullfile(dpath,'*.csv'));
[~,names] = cellfun(@fileparts, {listcsv.name}, 'UniformOutput', false);
listcsv(ismember(names, exclude)) = [];
if isempty(listcsv)
    warning("Folder does not contain .csv files.\n");
end

end