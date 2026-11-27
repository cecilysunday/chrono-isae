% Function for processing outputs of setdrum.cpp
clc
clear
close all

% Additional matlab paths
addpath(fullfile('..','shared'));

% Input parameters
dpath = 'C:\Users\c.sunday\Desktop\simulation_data\rundrum\261121_012032';

% State files to process for the animations and the angle of repose over
% time: 1 = every file, 2 = every other file, ...
frame_step = 2;

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

% Import the first file in the data set
firstfile = fullfile(listbin(1).folder,listbin(1).name);
[dati,counti] = import_state_bin_fast(firstfile);

% View the system layout and particle size distribution
view_static(dati,container,rpath);

% Import the last file in the data set
lastfile = fullfile(listbin(end).folder,listbin(end).name);
[datf,countf] = import_state_bin_fast(lastfile);

% View the system layout with the grains colored by a third variable. The
% color scale of this (final) data set is kept for the animation below.
field = 'vel_m';
dyn_opts = {'Colormap','rainbow','Slice',[0 0 0],'SliceViews',"front"};
[~,cs] = view_dynamic(datf,container,rpath,field,dyn_opts{:});

% Find the angle of repose from the free surface of the bed
[theta,theta_err] = find_angle_of_repose(datf,container,rpath);

% Loop over the state files (every frame_step-th one) to extract frames for
% the animations and the angle of repose over time. Skips state_final.bin
files = listbin(~strcmp({listbin.name}, 'state_final.bin'));
files = files(1:frame_step:end);
nf    = numel(files);
fdyn  = fullfile(rpath,'frames_dynamic');
faor  = fullfile(rpath,'frames_aor');

mkdir(fdyn);
mkdir(faor);

tt = nan(nf,1);  
th = nan(nf,1);  
te = nan(nf,1);
pdyn = strings(nf,1);  
paor = strings(nf,1);

vis = get(0,'DefaultFigureVisible');
set(0,'DefaultFigureVisible','off');
for k = 1:nf
    fprintf('File %d of %d: %s\n', k, nf, files(k).name);
    d = import_state_bin_fast(fullfile(files(k).folder,files(k).name));
    tt(k) = d.time(1);

    % 2) angle of repose front view
    [th(k),te(k),S] = find_angle_of_repose(d,container,'','Labels',false,'DepthPlot',false);
    add_time_label(S.F(1), tt(k));
    paor(k) = fullfile(faor, sprintf('frame_%03d.png', k));
    exportgraphics(S.F(1), paor(k), 'Resolution', 300, 'Padding', 'figure');
    close(S.F(1));

    % 1) view_dynamic on the color scale of the final data set
    F = view_dynamic(d,container,'',field,cs.range,'Scale',cs.scale,dyn_opts{:}, ...
        'HistEdges',cs.hist_edges,'HistYMax',cs.hist_ymax);
    add_time_label(F, tt(k));
    pdyn(k) = fullfile(fdyn, sprintf('frame_%03d.png', k));
    exportgraphics(F, pdyn(k), 'Resolution', 300, 'Padding', 'figure');
    close(F);
end
set(0,'DefaultFigureVisible',vis);

% Animations, in time order
[tt, order] = sort(tt);
make_gif(pdyn(order), fullfile(rpath, ['dynamic_' field '.gif']));
make_gif(paor(order), fullfile(rpath, 'angle_of_repose.gif'));

% 3) Mean angle of repose over time
plot_aor_v_time(tt, th(order), te(order), rpath);

% -------------------------------------------------------------------------
% Time stamp in the top left corner of a figure
% -------------------------------------------------------------------------
function add_time_label(F, t)
annotation(F, 'textbox', [0.01 0.95 0.3 0.05], 'String', sprintf('t = %.2f s', t), ...
    'EdgeColor', 'none', 'FontName', 'Times New Roman', 'FontSize', 12, ...
    'VerticalAlignment', 'top');
end