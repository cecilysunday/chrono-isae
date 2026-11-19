% -------------------------------------------------------------------------
% FUNCTION  view_positions      Plot the grain positions in two figures,
%                               each in a 2 x 2 layout:
%                               top left      distribution (see below)
%                               top right     top view   (along z)
%                               bottom left   side view  (along x)
%                               bottom right  front view (along y)
%                               Figure 1 'positions': size distribution,
%                               grains in a single color
%                               Figure 2 'velocities': velocity
%                               distribution, grains colored by velocity
%                               magnitude
% INPUTS    dat                 Data structure from import_state_bin
%           rpath (optional)    Filepath to results folder. If given, the
%                               figures are saved there as positions.png
%                               and velocities.png
% OPTS      'VelocityRange'     [min max] of the velocity color scale in
%                               mm/s. Default: [1 10]. For a bed close to
%                               rest, try e.g. [0.001 0.1]
%           'Highlight'         Velocity in mm/s above which grains are
%                               drawn in red. Default: the top of
%                               VelocityRange. Use inf to turn it off
% OUTPUTS   F                   Figure handles [positions, velocities]
%
% NOTES     - Only bodies with body_id >= 0 (grains) are plotted
%           - Grains are drawn as circles at their true radius, so they
%             have the correct size relative to the container. Each view
%             shows only the grains visible from that side: nearer grains
%             hide the ones behind them (this includes red grains)
%           - Viewers sit at +z (top), +x (side) and -y (front), so each
%             view is right-handed and not mirrored
%           - All three views use the same axis range (and so the same
%             scale), sized to fit the largest container dimension
%           - The container is inferred from the grain positions: if all
%             grains fit inside a circle about one of the axes it is drawn
%             as a cylinder (e.g. a drum), otherwise as a box
%           - The velocity color scale is logarithmic over VelocityRange.
%             Grains outside that range get the end colors, except those
%             above Highlight, which are red (also in the histogram)
%           - The velocity histogram lists how many grains move faster
%             than Highlight
%           - Assumes the mm-g-s unit system
% -------------------------------------------------------------------------
function [F] = view_positions(dat,rpath,opts)

arguments
    dat
    rpath = ''
    opts.VelocityRange (1,2) double {mustBePositive} = [1 10]
    opts.Highlight (1,1) double = NaN
end

% Velocity color range and highlight threshold (mm/s)
VLIM = opts.VelocityRange;
if VLIM(2) <= VLIM(1)
    error('view_positions:badRange', 'VelocityRange must be [min max] with min < max.');
end
VHL = opts.Highlight;
if isnan(VHL)
    VHL = VLIM(2);
elseif VHL <= 0
    error('view_positions:badHighlight', 'Highlight must be positive (or inf to turn it off).');
end

% Filter data by grains only
g = dat.body_id >= 0;
if ~any(g)
    error('view_positions:noGrains', ...
        'No grains (body_id >= 0) in the data. Check the input file.');
end
P = [dat.pos_x(g), dat.pos_y(g), dat.pos_z(g)];
r = dat.radius(g);
v = dat.vel_m(g);

geo = container_geometry(P, r);

% Figure 1: size distribution, single-color grains
[C, ~] = plot_colors(1);
F(1) = figure('Name','positions','Units','centimeters','Position',[2 2 17 17]);
T = tiledlayout(F(1), 2, 2, 'TileSpacing','compact', 'Padding','compact');
plot_size_hist(nexttile(T, 1), 2*r, C(1,:));
draw_views(T, P, r, geo, C(1,:));
plot_format(F(1), 'PanelLabelLocation', 'outside');

% Figure 2: velocity distribution, grains colored by velocity, fast
% grains (above the highlight threshold) in red
cmap = velocity_colormap(256);
Call = plot_colors();
red  = Call(8,:);
F(2) = figure('Name','velocities','Units','centimeters','Position',[2 2 19 17]);
T = tiledlayout(F(2), 2, 2, 'TileSpacing','compact', 'Padding','compact');
plot_velocity_hist(nexttile(T, 1), v, VLIM, VHL, C(1,:), red);
% Per-grain RGB from the log color scale, red above the threshold. The
% axes colormap and limits below only drive the colorbar.
t   = (log10(min(max(v, VLIM(1)), VLIM(2))) - log10(VLIM(1))) / diff(log10(VLIM));
rgb = cmap(round(t*(size(cmap,1) - 1)) + 1, :);
rgb(v > VHL, :) = repmat(red, nnz(v > VHL), 1);
AX = draw_views(T, P, r, geo, rgb);
for ax = AX
    colormap(ax, cmap);
    ax.ColorScale = 'log';
    clim(ax, VLIM);
end
cb = colorbar(AX(end));
cb.Layout.Tile = 'east';
cb.Ticks = log_ticks(VLIM);
cb.TickLabels = compose('%g', cb.Ticks);
cb.TickLabels{1}   = ['\leq' cb.TickLabels{1}];
if VHL ~= VLIM(2)                         % above the top is red otherwise
    cb.TickLabels{end} = ['\geq' cb.TickLabels{end}];
end
cb.Label.String = 'Velocity magnitude (mm/s)';
plot_format(F(2), 'PanelLabelLocation', 'outside');

% Save plots
if ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F(1), fullfile(rpath,'positions.png'),  'Resolution', 300, 'Padding', 'figure');
    exportgraphics(F(2), fullfile(rpath,'velocities.png'), 'Resolution', 300, 'Padding', 'figure');
end

end

% -------------------------------------------------------------------------
% Container geometry and the common axis range for all views
% -------------------------------------------------------------------------
function geo = container_geometry(P, r)

% Bounding box, then try a cylinder about each axis
lo  = min(P - r, [], 1);
hi  = max(P + r, [], 1);
cyl = find_cylinder(P, r, lo, hi);

% Cylinder sets the full extent in the two cross-section directions
if ~isempty(cyl)
    ax2 = setdiff(1:3, cyl.axis);
    lo(ax2) = cyl.center - cyl.R;
    hi(ax2) = cyl.center + cyl.R;
end

% Same axis range in every view
pad = 0.03 * max(hi - lo);
geo = struct('lo', lo, 'hi', hi, 'cyl', cyl, ...
    'hw', max(hi - lo)/2 + pad, 'ctr', (lo + hi)/2);

end

% -------------------------------------------------------------------------
% Grain size histogram with a fitted normal distribution
% -------------------------------------------------------------------------
function plot_size_hist(ax, d, col)

hold(ax, 'on');
H = histogram(ax, d, 'Normalization','percentage', 'FaceColor', col, ...
    'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);

% Fitted normal distribution, scaled to match the percentage histogram
mu  = mean(d);
sig = std(d);
if sig > 0
    xf = linspace(min(mu - 4*sig, min(d)), max(mu + 4*sig, max(d)), 300);
    yf = 100 * H.BinWidth * exp(-0.5*((xf - mu)/sig).^2) / (sig*sqrt(2*pi));
    plot(ax, xf, yf, 'k-', 'LineWidth', 1);
end

xlabel(ax, 'Grain diameter (mm)');
ylabel(ax, 'Grains (%)');
title(ax, 'Size distribution');
ylim(ax, [0, 1.6*max(ylim(ax))]);
pbaspect(ax, [1 1 1]);
text(ax, 0.04, 0.96, sprintf('N = %s grains', format_count(numel(d))), ...
    'Units','normalized', 'VerticalAlignment','top');
text(ax, 0.96, 0.96, { ...
    sprintf('\\mu = %.3g mm', mu), ...
    sprintf('\\sigma = %.3g mm', sig), ...
    sprintf('min = %.3g mm', min(d)), ...
    sprintf('max = %.3g mm', max(d))}, ...
    'Units','normalized', 'VerticalAlignment','top', 'HorizontalAlignment','right');

end

% -------------------------------------------------------------------------
% Velocity magnitude histogram on log-spaced bins. The x range runs in
% whole decades from the 1st percentile to the maximum; slower grains are
% counted in the first bin. The color-scale range is shaded in gray and
% grains above the highlight threshold are stacked in red.
% -------------------------------------------------------------------------
function plot_velocity_hist(ax, v, vlim, vhl, col, red)

[~, Pn] = plot_colors();
hold(ax, 'on');

vs = sort(v(v > 0));
if isempty(vs)
    vs = vlim(1);                         % everything at rest
end
v01 = vs(max(1, ceil(0.01*numel(vs))));
e   = floor(log10(v01)) : ceil(log10(vs(end)));
if isscalar(e), e = [e e+1]; end
edges = logspace(e(1), e(end), 10*(e(end) - e(1)) + 1);

vc     = min(max(v, edges(1)), edges(end));
counts = 100 * histcounts(vc, edges) / numel(v);
cslow  = 100 * histcounts(vc(v <= vhl), edges) / numel(v);

% Shaded color-scale range, behind the bars
ytop = 2.3 * max(counts);
patch(ax, vlim([1 2 2 1]), [0 0 ytop ytop], Pn.gray, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');

% Stacked: full height in red, then the slow part over it in blue
if any(v > vhl)
    histogram(ax, 'BinEdges', edges, 'BinCounts', counts, 'FaceColor', red, ...
        'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);
end
histogram(ax, 'BinEdges', edges, 'BinCounts', cslow, 'FaceColor', col, ...
    'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);

ax.XScale = 'log';
xlim(ax, edges([1 end]));
ylim(ax, [0 ytop]);
xticks(ax, 10.^e);
xlabel(ax, 'Velocity magnitude (mm/s)');
ylabel(ax, 'Grains (%)');
title(ax, 'Velocity distribution');
pbaspect(ax, [1 1 1]);
% Stats, with the number of grains above the highlight threshold
lines = { ...
    sprintf('N = %s grains', format_count(numel(v))), ...
    sprintf('median = %.3g mm/s', median(v)), ...
    sprintf('max = %.3g mm/s', max(v))};
if isfinite(vhl)
    lines{end+1} = sprintf('> %g mm/s (red): %s', vhl, count_str(nnz(v > vhl), numel(v)));
end
text(ax, 0.96, 0.96, lines, ...
    'Units','normalized', 'VerticalAlignment','top', 'HorizontalAlignment','right');

end

% -------------------------------------------------------------------------
% Top, side and front views in tiles 2-4. 'col' is either one RGB color
% for all grains or an N x 3 RGB color per grain. Returns the three axes.
% -------------------------------------------------------------------------
function AX = draw_views(T, P, r, geo, col)

names = 'xyz';
cyl   = geo.cyl;

% {tile, title, viewing axis, horizontal axis, vertical axis, side}
% 'side' is where the viewer sits along the viewing axis (+1 or -1),
% chosen so (horizontal, vertical, toward viewer) is right-handed
views = {2, 'Top view',   3, 1, 2,  1;      % from +z: x right, y up
         3, 'Side view',  1, 2, 3,  1;      % from +x: y right, z up
         4, 'Front view', 2, 1, 3, -1};     % from -y: x right, z up

AX = gobjects(1, size(views,1));
for k = 1:size(views,1)
    [tile, name, a, h, v, s] = views{k,:};
    ax = nexttile(T, tile);
    AX(k) = ax;
    hold(ax, 'on');

    % Grains as true-size circles. Depth = distance toward the viewer, so
    % the depth buffer shows only the grains visible from that side.
    depth = s * P(:,a);
    draw_circles(ax, P(:,h), P(:,v), depth, r, col);

    % Container outline (above all grains)
    ztop = max(depth) + 1;
    if ~isempty(cyl) && cyl.axis == a
        ax2 = setdiff(1:3, a);
        t  = linspace(0, 2*pi, 361);
        ih = find(ax2 == h);
        iv = find(ax2 == v);
        plot3(ax, cyl.center(ih) + cyl.R*cos(t), cyl.center(iv) + cyl.R*sin(t), ...
            ztop*ones(size(t)), 'k-', 'LineWidth', 1);
    else
        lo = geo.lo;  hi = geo.hi;
        plot3(ax, [lo(h) hi(h) hi(h) lo(h) lo(h)], [lo(v) lo(v) hi(v) hi(v) lo(v)], ...
            ztop*ones(1,5), 'k-', 'LineWidth', 1.);
    end

    view(ax, 2);
    axis(ax, 'equal');
    xlim(ax, geo.ctr(h) + [-geo.hw geo.hw]);
    ylim(ax, geo.ctr(v) + [-geo.hw geo.hw]);
    xlabel(ax, sprintf('%s (mm)', names(h)));
    ylabel(ax, sprintf('%s (mm)', names(v)));
    title(ax, name);
end

end

% -------------------------------------------------------------------------
% Draw N circles (centers u,v, radii r) as one patch. The depth d is used
% as the z coordinate so the depth buffer puts nearer grains on top.
% 'col' is one RGB color for all grains, or an N x 3 RGB color per grain.
% -------------------------------------------------------------------------
function draw_circles(ax, u, v, d, r, col)

n  = 16;                                  % vertices per circle
t  = (0:n-1) * 2*pi/n;
N  = numel(u);
X  = u + r .* cos(t);                     % N x n
Y  = v + r .* sin(t);
Z  = repmat(d, 1, n);
V  = [X(:), Y(:), Z(:)];
Fc = (1:N)' + (0:n-1) * N;                % face i uses rows i, i+N, ...

if isequal(size(col), [1 3])
    patch(ax, 'Faces', Fc, 'Vertices', V, 'FaceColor', col, ...
        'EdgeColor', 0.6*col, 'LineWidth', 0.1);
else
    patch(ax, 'Faces', Fc, 'Vertices', V, 'FaceVertexCData', col, ...
        'FaceColor', 'flat', 'EdgeColor', [0 0 0], 'EdgeAlpha', 0.3, ...
        'LineWidth', 0.1);
end

end

% -------------------------------------------------------------------------
% Single-hue sequential colormap: light blue (slow) to dark blue (fast)
% -------------------------------------------------------------------------
function cmap = velocity_colormap(n)

[C, ~] = plot_colors(1);
stops = [0.86 0.92 0.98;                  % light
         C(1,:);                          % palette blue
         0.05 0.15 0.38];                 % dark navy
cmap = interp1([0 0.5 1], stops, linspace(0, 1, n));

end

% -------------------------------------------------------------------------
% Test each axis as a possible cylinder axis. A cylinder is accepted when
% every grain fits inside a circle whose diameter is the larger of the two
% cross-section spans. Returns [] if no axis works (container is a box).
% -------------------------------------------------------------------------
function cyl = find_cylinder(P, r, lo, hi)

cyl  = [];
best = inf;
tol  = 0.01;                              % 1% of the radius

for a = 1:3
    ax2  = setdiff(1:3, a);
    span = hi(ax2) - lo(ax2);
    [D, ifull] = max(span);
    R = D / 2;

    % Center: midpoint along the fully spanned direction. Along the other,
    % the grains may only partly fill the circle (e.g. a settled bed), so
    % try the circle against either side and keep the better fit
    c0 = (lo(ax2) + hi(ax2)) / 2;
    io = 3 - ifull;
    cands = c0;
    if span(io) < (1 - tol) * D
        cands = [c0; c0];
        cands(1,io) = lo(ax2(io)) + R;
        cands(2,io) = hi(ax2(io)) - R;
    end

    for j = 1:size(cands,1)
        c = cands(j,:);
        % Fraction of grains poking outside the circle
        rho = hypot(P(:,ax2(1)) - c(1), P(:,ax2(2)) - c(2)) + r;
        bad = mean(rho > (1 + tol) * R);
        if bad < 1e-3 && bad < best
            best = bad;
            cyl  = struct('axis', a, 'center', c, 'R', R);
        end
    end
end

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
% Grain count with its share of the total, e.g. '3 (0.0061%)'. The count
% is always exact, so a few grains never round away to 0%.
% -------------------------------------------------------------------------
function s = count_str(k, n)
s = sprintf('%s (%.2g%%)', format_count(k), 100*k/n);
end

% -------------------------------------------------------------------------
% Integer with thousands separators, e.g. 60898 -> '60,898'
% -------------------------------------------------------------------------
function s = format_count(n)
s = fliplr(regexprep(fliplr(sprintf('%d', n)), '(\d{3})(?=\d)', '$1,'));
end
