% -------------------------------------------------------------------------
% FUNCTION  view_kinetic_energy     Import the system energy file and display
%                                   the evolution of the energy in the system
% INPUTS    dpath                   Data file path (contains system_energy.txt)
%           rpath (optional)        Filepath to results folder. If given, the
%                                   figure is saved there as a PNG and FIG
% OUTPUTS   F                       Figure handle
%
% NOTES     - Assumes the mm-g-s unit system
%           - Energy is in g*mm^2/s^2 = nJ and velocity is in mm/s
% -------------------------------------------------------------------------
function [F] = view_kinetic_energy(dpath,rpath)

fname = fullfile(dpath,'system_energy.txt');
if ~isfile(fname)
    warning('Unable to plot energy trends. The system_energy.txt file does not exist in the specified directory. \n');
    F = [];
    return;
end

opts = detectImportOptions(fname);
ke = readtable(fname,opts);

% Figure formatting
lw = 1.25; % line width
pos = @(y) y .* (y > 0) ./ (y > 0); % zero/negative -> NaN, since Log axes can't show zeros 

% Create figure
F = figure('Name','kinetic_energy','Units','centimeters','Position',[2 2 18 16]);
T = tiledlayout(F,2,1,'TileSpacing','compact','Padding','compact');

% Panel 1: mean kinetic energy per particle
ax1 = nexttile(T);
hold(ax1,'on');
plot(ax1, ke.time, pos(ke.mean_KE), 'LineWidth', lw);
plot(ax1, ke.time, pos(ke.mean_KE_trn), 'LineWidth', lw);
plot(ax1, ke.time, pos(ke.mean_KE_rot), 'LineWidth', lw);
set(ax1, 'YScale', 'log');
ylabel(ax1, 'Mean kinetic energy (nJ)');
title(ax1, 'Kinetic energy');
legend(ax1, {'Total','Translational','Rotational'},'Location','north','Orientation','horizontal');

% Panel 2: particle velocity
ax2 = nexttile(T);
hold(ax2,'on');
plot(ax2, ke.time, pos(ke.max_vel), 'LineWidth', lw);
plot(ax2, ke.time, pos(ke.rms_vel), 'LineWidth', lw);
set(ax2, 'YScale', 'log');
ylabel(ax2, 'Velocity (mm/s)');
xlabel(ax2, 'Time (s)');
title(ax2, 'Particle velocity');
legend(ax2, {'Maximum','RMS'}, 'Location','north','Orientation','horizontal');

% Formatting
linkaxes([ax1 ax2],'x');

xlim(ax1,[0 ke.time(end)]);
ax1.XTickLabel = {};

plot_format(F, 'DecadeTicks', true, 'DecadeHeadroom', 0);

% Save plot
if nargin > 1 && ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath); 
    end
    exportgraphics(F, fullfile(rpath,'kinetic_energy.png'), 'Resolution', 300, 'Padding', 'figure');
end

end

