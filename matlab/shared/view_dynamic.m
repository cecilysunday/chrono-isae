% -------------------------------------------------------------------------
% FUNCTION  view_dynamic        Plot the grains colored by any per-grain
%                               quantity in a 2 x 2 layout:
%                               top left: distribution of the quantity
%                               top right: top view   (along z)
%                               bottom left: side view  (along x)
%                               bottom right: front view (along y)
% INPUTS    dat                 Data structure from import_state_bin
%           container           Struct describing the container (mm), see
%                               get_container_geometry
%           rpath               Filepath to results folder. If not empty,
%                               the figure is saved there as
%                               dynamic_<field>.png
%           field               Name of the dat field to color by, e.g.
%                               'vel_m', 'force_m', 'pos_z', 'wvel_y'
%           range (optional)    [min max] of the color scale. Default:
%                               mean +/- 2 sigma of the data, clipped to
%                               the data range (in log10 space when the
%                               scale is log)
% OPTS      'Colormap'          'blue' (default): single-hue blue scale
%                               with red grains above 'Highlight'.
%                               'rainbow' (= turbo) or any other MATLAB
%                               colormap name ('parula', 'jet', 'hot',
%                               ...): that scale, with no threshold
%           'Highlight'         Value above which grains are drawn in red
%                               ('blue' colormap only). Default: the top of
%                               the color range. Use inf to turn it off
%           'Scale'             'auto' (default), 'log' or 'linear'
%           'Label'             Axis label for the quantity, including the
%                               unit. Default: from the field name, e.g.
%                               'Velocity magnitude (mm/s)'
%           'Slice'             [x y z] point to slice the views through.
%                               Each sliced view shows only the grains in
%                               a slab normal to its viewing direction
%                               (top: z, side: x, front: y). Default: []
%                               (no slicing)
%           'SliceViews'        Views to slice, any of "top", "side",
%                               "front". Default: all three
%           'SliceThickness'    Slab thickness (mm). Default: 2 mean grain
%                               diameters
% OUTPUTS   F                   Figure handle
%
% EXAMPLES  view_dynamic(dat,container,rpath,'vel_m',[0.001 1.0]);
%           view_dynamic(dat,container,rpath,'force_m');
%           view_dynamic(dat,container,'','vel_z','Highlight',inf);
%           view_dynamic(dat,container,rpath,'force_m','Colormap','rainbow');
%           view_dynamic(dat,container,rpath,'vel_m','Slice',[0 0 0], ...
%               'SliceViews',"front");
%
% NOTES     - Only bodies with body_id >= 0 (grains) are plotted
%           - See draw_triple_view for how the views are drawn and sliced. A
%             sliced view gives the slice plane in its title. In an
%             unsliced view, red grains can be hidden behind nearer grains
%           - The histogram and the auto color range always use all
%             grains, so colors mean the same in sliced and unsliced views
%           - Grains outside the color range get the end colors, except
%             those above Highlight, which are red (also in the histogram;
%             'blue' colormap only)
%           - With a log scale, values <= 0 get the bottom color
%           - Assumes the mm-g-s unit system
% -------------------------------------------------------------------------
function [F] = view_dynamic(dat,container,rpath,field,range,opts)

arguments
    dat
    container (1,1) struct
    rpath {mustBeTextScalar}
    field {mustBeTextScalar}
    range double = []
    opts.Colormap {mustBeTextScalar} = 'blue'
    opts.Highlight (1,1) double = NaN
    opts.Scale {mustBeMember(opts.Scale, {'auto','log','linear'})} = 'auto'
    opts.Label {mustBeTextScalar} = ''
    opts.Slice double = []
    opts.SliceViews string = ["top","side","front"]
    opts.SliceThickness (1,1) double = NaN
end
field = char(field);

% Filter data by grains only
if ~isfield(dat, field)
    error('view_dynamic:badField', 'dat has no field ''%s''.', field);
end
g = dat.body_id >= 0;
if ~any(g)
    error('view_dynamic:noGrains', ...
        'No grains (body_id >= 0) in the data. Check the input file.');
end
P = [dat.pos_x(g), dat.pos_y(g), dat.pos_z(g)];
r = dat.radius(g);
v = dat.(field)(g);
v = double(v(:));
if ~all(isfinite(v))
    error('view_dynamic:badValues', 'dat.%s has non-finite values.', field);
end

% Color scale and range
if ~isempty(range) && (numel(range) ~= 2 || range(2) <= range(1))
    error('view_dynamic:badRange', 'range must be [min max] with min < max.');
end
islog = pick_scale(opts.Scale, v, range);
if isempty(range)
    range = auto_range(v, islog);
elseif islog && range(1) <= 0
    error('view_dynamic:badRange', 'A log scale needs range(1) > 0.');
end
LIM = range(:)';

% Colormap and highlight threshold (red grains only with the blue scale)
cmap = pick_colormap(opts.Colormap, 256);
isblue = strcmpi(opts.Colormap, 'blue');
VHL = opts.Highlight;
if ~isblue
    if isfinite(VHL)
        error('view_dynamic:badHighlight', ...
            'Highlight only works with the ''blue'' colormap.');
    end
    VHL = inf;
elseif isnan(VHL)
    VHL = LIM(2);
end

% Label and unit
[name, unit, short] = field_label(field);
lbl = char(opts.Label);
if isempty(lbl)
    lbl = name;
    if ~isempty(unit), lbl = sprintf('%s (%s)', name, unit); end
end

% Per-grain RGB from the color scale, red above the threshold. The axes
% colormap and limits below only drive the colorbar.
[C, ~] = plot_colors(1);
Call = plot_colors();
red  = Call(8,:);
t   = scale_frac(v, LIM, islog);
rgb = cmap(round(t*(size(cmap,1) - 1)) + 1, :);
rgb(v > VHL, :) = repmat(red, nnz(v > VHL), 1);

F = figure('Name',field,'Units','centimeters','Position',[2 2 19 17]);
T = tiledlayout(F, 2, 2, 'TileSpacing','compact', 'Padding','compact');
plot_value_hist(nexttile(T, 1), v, LIM, VHL, islog, short, unit, lbl, C(1,:), red);
AX = draw_triple_view(T, P, r, get_container_geometry(container, P, r), rgb, ...
    'Slice', opts.Slice, 'SliceViews', opts.SliceViews, ...
    'SliceThickness', opts.SliceThickness);
for ax = AX
    colormap(ax, cmap);
    if islog, ax.ColorScale = 'log'; end
    clim(ax, LIM);
end
cb = colorbar(AX(end));
cb.Layout.Tile = 'east';
if islog
    cb.Ticks = log_ticks(LIM);
else
    % Automatic ticks plus both ends, dropping any too close to the ends
    tk = cb.Ticks;
    tk = tk(tk > LIM(1) + 0.08*diff(LIM) & tk < LIM(2) - 0.08*diff(LIM));
    cb.Ticks = [LIM(1), tk, LIM(2)];
end
cb.TickLabels = arrayfun(@num_str, cb.Ticks, 'UniformOutput', false);
cb.TickLabels{1} = ['\leq' cb.TickLabels{1}];
if VHL ~= LIM(2)                          % above the top is red otherwise
    cb.TickLabels{end} = ['\geq' cb.TickLabels{end}];
end
cb.Label.String = lbl;
plot_format(F, 'PanelLabelLocation', 'outside');

% Save plot
if ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F, fullfile(rpath, ['dynamic_' field '.png']), ...
        'Resolution', 300, 'Padding', 'figure');
end

end

% -------------------------------------------------------------------------
% Log or linear color scale. Auto: log when all values are >= 0 and the
% positive values (or the given range) span more than two decades.
% -------------------------------------------------------------------------
function islog = pick_scale(scale, v, range)

switch scale
    case 'log'
        islog = true;
        if ~any(v > 0)
            error('view_dynamic:badScale', 'A log scale needs some positive values.');
        end
    case 'linear'
        islog = false;
    otherwise
        if ~isempty(range)
            islog = range(1) > 0 && range(2)/range(1) > 100;
        else
            vp = v(v > 0);
            islog = all(v >= 0) && ~isempty(vp) && ...
                prctile(vp, 99) / prctile(vp, 1) > 100;
        end
end

end

% -------------------------------------------------------------------------
% Default color range: mean +/- 2 sigma (of log10 of the positive values
% for a log scale), clipped to the data range
% -------------------------------------------------------------------------
function lim = auto_range(v, islog)

if islog
    vp  = v(v > 0);
    lv  = log10(vp);
    lim = 10.^(mean(lv) + [-2 2]*std(lv));
    lim = [max(lim(1), min(vp)), min(lim(2), max(vp))];
else
    lim = mean(v) + [-2 2]*std(v);
    lim = [max(lim(1), min(v)), min(lim(2), max(v))];
end

% All grains (nearly) equal: open up a small range around the value
if ~(lim(2) > lim(1))
    c = lim(1);
    if islog
        lim = c * [0.5 2];
    elseif c == 0
        lim = [-1 1];
    else
        lim = c + [-0.1 0.1]*abs(c);
    end
end

end

% -------------------------------------------------------------------------
% Position of each value on the color scale, from 0 (bottom) to 1 (top)
% -------------------------------------------------------------------------
function t = scale_frac(v, lim, islog)
if islog
    t = (log10(min(max(v, lim(1)), lim(2))) - log10(lim(1))) / diff(log10(lim));
else
    t = (min(max(v, lim(1)), lim(2)) - lim(1)) / diff(lim);
end
end

% -------------------------------------------------------------------------
% Histogram of the values. Log scale: log-spaced bins in whole decades
% from the 1st percentile to the maximum. Linear: 40 bins from the 0.5th
% to the 99.5th percentile, widened to cover the color range. Values
% outside the bins are counted in the end bins. The color range is shaded
% in gray and values above the highlight threshold are stacked in red.
% -------------------------------------------------------------------------
function plot_value_hist(ax, v, lim, vhl, islog, name, unit, lbl, col, red)

[~, Pn] = plot_colors();
hold(ax, 'on');

if islog
    vs = sort(v(v > 0));
    v01 = vs(max(1, ceil(0.01*numel(vs))));
    e   = floor(log10(min(v01, lim(1)))) : ceil(log10(max(vs(end), lim(2))));
    if isscalar(e), e = [e e+1]; end
    edges = logspace(e(1), e(end), 10*(e(end) - e(1)) + 1);
else
    lo = min(prctile(v, 0.5), lim(1));
    hi = max(prctile(v, 99.5), lim(2));
    edges = linspace(lo, hi, 41);
end

vc     = min(max(v, edges(1)), edges(end));
counts = 100 * histcounts(vc, edges) / numel(v);
cslow  = 100 * histcounts(vc(v <= vhl), edges) / numel(v);

% Shaded color-scale range, behind the bars
ytop = 2.3 * max(counts);
patch(ax, lim([1 2 2 1]), [0 0 ytop ytop], Pn.gray, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');

% Stacked: full height in red, then the rest over it in blue
if any(v > vhl)
    histogram(ax, 'BinEdges', edges, 'BinCounts', counts, 'FaceColor', red, ...
        'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);
end
histogram(ax, 'BinEdges', edges, 'BinCounts', cslow, 'FaceColor', col, ...
    'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);

if islog
    ax.XScale = 'log';
    xticks(ax, 10.^e);
end
xlim(ax, edges([1 end]));
ylim(ax, [0 ytop]);
xlabel(ax, lbl);
ylabel(ax, 'Grains (%)');
title(ax, sprintf('%s distribution', name));
pbaspect(ax, [1 1 1]);

% Stats, with the number of grains above the highlight threshold
u = '';
if ~isempty(unit), u = [' ' unit]; end
lines = { ...
    sprintf('N = %s grains', format_count(numel(v))), ...
    sprintf('median = %s%s', num_str(median(v)), u), ...
    sprintf('min = %s%s', num_str(min(v)), u), ...
    sprintf('max = %s%s', num_str(max(v)), u)};
if isfinite(vhl)
    lines{end+1} = sprintf('> %s%s (red): %s', num_str(vhl), u, count_str(nnz(v > vhl), numel(v)));
end
text(ax, 0.96, 0.96, lines, ...
    'Units','normalized', 'VerticalAlignment','top', 'HorizontalAlignment','right');

end

% -------------------------------------------------------------------------
% Name and unit (mm-g-s) from an import_state_bin field name, e.g.
% 'vel_m' -> 'Velocity magnitude', 'mm/s', and the short name without
% the component, 'Velocity' (for the histogram title). Unknown fields use
% the field name and no unit.
% -------------------------------------------------------------------------
function [name, unit, short] = field_label(field)

base = {'pos',    'Position',             'mm';
        'vel',    'Velocity',             'mm/s';
        'wvel',   'Angular velocity',     'rad/s';
        'acc',    'Acceleration',         'mm/s^2';
        'wacc',   'Angular acceleration', 'rad/s^2';
        'force',  'Force',                '\muN';
        'torque', 'Torque',               'nN m';
        'radius', 'Radius',               'mm'};
comp = {'m', 'magnitude'; 'x', 'x'; 'y', 'y'; 'z', 'z'};

name  = strrep(field, '_', '\_');
short = name;
unit  = '';
tok   = strsplit(field, '_');               % e.g. {'vel','m'}
ib   = find(strcmp(base(:,1), tok{1}));
if isempty(ib) || numel(tok) > 2, return; end
ic = [];
if numel(tok) == 2
    ic = find(strcmp(comp(:,1), tok{2}));
    if isempty(ic), return; end
end
name  = base{ib,2};
short = name;
unit  = base{ib,3};
if ~isempty(ic)
    name = sprintf('%s %s', name, comp{ic,2});
end

end

% -------------------------------------------------------------------------
% n x 3 colormap from its name: 'blue' (see below), 'rainbow' (= turbo)
% or a MATLAB colormap function name
% -------------------------------------------------------------------------
function cmap = pick_colormap(name, n)

name = lower(char(name));
known = {'turbo','parula','jet','hsv','hot','cool','spring','summer', ...
         'autumn','winter','gray','bone','copper','pink'};
switch name
    case 'blue'
        cmap = sequential_colormap(n);
    case 'rainbow'
        cmap = turbo(n);
    otherwise
        if ~any(strcmp(name, known))
            error('view_dynamic:badColormap', ...
                'Colormap must be ''blue'', ''rainbow'' or one of: %s.', ...
                strjoin(known, ', '));
        end
        cmap = feval(name, n);
end

end

% -------------------------------------------------------------------------
% Single-hue sequential colormap: light blue (low) to dark blue (high)
% -------------------------------------------------------------------------
function cmap = sequential_colormap(n)

[C, ~] = plot_colors(1);
stops = [0.86 0.92 0.98;                  % light
         C(1,:);                          % palette blue
         0.05 0.15 0.38];                 % dark navy
cmap = interp1([0 0.5 1], stops, linspace(0, 1, n));

end

% -------------------------------------------------------------------------
% Colorbar ticks for a log range: 1-2-5 steps inside it, plus both ends
% -------------------------------------------------------------------------
function t = log_ticks(lim)
dec = floor(log10(lim(1))) : ceil(log10(lim(2)));
t = [1; 2; 5] * 10.^dec;
t = t(t > lim(1)*(1+1e-9) & t < lim(2)*(1-1e-9));
t = [lim(1); t(:); lim(2)]';
end

% -------------------------------------------------------------------------
% Number to 3 significant digits for TeX labels: plain for 0.001 <= |x|
% < 1000, otherwise as a power of ten, e.g. 1.24\times10^{5}
% -------------------------------------------------------------------------
function s = num_str(x)
if x == 0 || (abs(x) >= 1e-3 && abs(x) < 1e3)
    s = sprintf('%.3g', x);
    return;
end
e = floor(log10(abs(x)));
m = round(x / 10^e, 2);
if abs(m) >= 10, m = m/10; e = e + 1; end
if m == 1
    s = sprintf('10^{%d}', e);
elseif m == -1
    s = sprintf('-10^{%d}', e);
else
    s = sprintf('%.3g\\times10^{%d}', m, e);
end
end

% -------------------------------------------------------------------------
% Grain count with its share of the total, e.g. '3 (0.0061%)'. The count
% is always exact, so a few grains never round away to 0%.
% -------------------------------------------------------------------------
function s = count_str(k, n)
s = sprintf('%s (%.2g%%)', format_count(k), 100*k/n);
end
