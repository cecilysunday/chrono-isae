% -------------------------------------------------------------------------
% FUNCTION  view_timers             Import the system_stats file and display
%                                   the partitioning of computation time
% INPUTS    dpath                   Data file path (contains system_stats.txt)
%           rpath (optional)        Filepath to results folder. If given, the
%                                   figure is saved there as a PNG
% OUTPUTS   F                       Figure handle
%
% NOTES     - Each timer keeps the same color in every figure, whatever its
%             rank or whether other timers are zero
%           - Slices are sorted largest first, starting at 12 o'clock
%           - Slices below 3% are not labelled on the pie; their share is
%             still listed in the legend
% -------------------------------------------------------------------------
function [F] = view_timers(dpath,rpath)

% Load the system stats file
fname = fullfile(dpath,'system_stats.txt');
if ~isfile(fname)
    warning('Unable to plot simulation timers. The system_stats.txt file does not exist in the specified directory. \n');
    F = [];
    return;
end

% Import the stats file as a table of doubles
opts = detectImportOptions(fname, 'Delimiter', ' ', 'CommentStyle', '#', 'ReadRowNames', true, 'ReadVariableNames', false);
opts = setvaropts(opts, 'Var2', 'Type', 'double');
opts.DataLines = [2 Inf];

S = readtable(fname, opts);
S = rows2vars(S);
S = S(:,2:end);

% Timers and labels (fixed order = fixed color for each timer)
timers = [S.timer_broad_collision, S.timer_narrow_collision, S.timer_custom_collision, ...
          S.timer_other_collision, S.timer_total_update, S.timer_total_advance, S.timer_total_other];
labels = {'Collision: broad', 'Collision: narrow', 'Collision: custom', ...
          'Collision: other', 'Update', 'Advance', 'Other'};
C = plot_colors(numel(timers));
[~, P] = plot_colors();

if sum(timers) <= 0
    warning('Unable to plot simulation timers. All timers are zero. \n');
    F = [];
    return;
end

% Drop empty timers, then sort largest first
keep = timers > 0;
pct  = 100 * timers(keep) / sum(timers);
labels = labels(keep);
C      = C(keep,:);
[pct, k] = sort(pct, 'descend');
labels = labels(k);
C      = C(k,:);

% Create figure
F  = figure('Name','system_stats','Units','centimeters','Position',[2 2 17 10]);
ax = axes(F);

% Pie (percentages sum to 100, so pie always draws a full circle)
h = pie(ax, pct);
slices = h(1:2:end);
ptext  = h(2:2:end);
for i = 1:numel(slices)
    set(slices(i), 'FaceColor', C(i,:), 'EdgeColor', 'w', 'LineWidth', 1.5);
    if pct(i) >= 3
        set(ptext(i), 'String', sprintf('%.1f%%', pct(i)), 'Color', P.ink);
    else
        set(ptext(i), 'String', '');
    end
end
axis(ax, 'equal', 'off');

% Legend lists every timer with its share
entries = cellfun(@(s, p) sprintf('%s (%.1f%%)', s, p), labels, num2cell(pct), ...
    'UniformOutput', false);
legend(ax, slices, entries, 'Location', 'eastoutside', 'Box', 'off');

title(ax, 'Computation time by function');
text(ax, 0.5, -0.06, { ...
    sprintf('Particles: %s   |   Shapes: %s', ...
        format_count(S.num_particles), format_count(S.num_shapes)), ...
    sprintf('CPU time: %.3g s per time step per shape', S.sim_cpu)}, ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'Color', P.ink2);

% Formatting
plot_format(F, 'PanelLabels', false);
set(ax.Legend, 'Box', 'off');

% Save plot
if nargin > 1 && ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F, fullfile(rpath,'timers.png'), 'Resolution', 300, 'Padding', 'figure');
end

end