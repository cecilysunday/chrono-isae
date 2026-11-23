% -------------------------------------------------------------------------
% FUNCTION  view_static         Plot the grain positions and size
%                               distribution in a 2 x 2 layout:
%                               top left: size distribution
%                               top right: top view   (along z)
%                               bottom left: side view  (along x)
%                               bottom right: front view (along y)
%                               Grains are drawn in a single color
% INPUTS    dat                 Data structure from import_state_bin
%           container           Struct describing the container (mm), see
%                               get_container_geometry
%           rpath (optional)    Filepath to results folder. If given, the
%                               figure is saved there as positions.png
% OPTS      'Slice'             [x y z] point to slice the views through.
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
% EXAMPLES  view_static(dat,container,rpath);
%           view_static(dat,container,rpath,'Slice',[0 0 0]);
%           view_static(dat,container,rpath,'Slice',[0 0 0],'SliceViews',"front");
%
% NOTES     - Only bodies with body_id >= 0 (grains) are plotted
%           - See draw_triple_view for how the views are drawn and sliced. A
%             sliced view gives the slice plane in its title
%           - The size distribution always uses all grains
%           - Assumes the mm-g-s unit system
% -------------------------------------------------------------------------
function [F] = view_static(dat,container,rpath,opts)

arguments
    dat
    container (1,1) struct
    rpath = ''
    opts.Slice double = []
    opts.SliceViews string = ["top","side","front"]
    opts.SliceThickness (1,1) double = NaN
end

% Filter data by grains only
g = dat.body_id >= 0;
if ~any(g)
    error('view_static:noGrains', ...
        'No grains (body_id >= 0) in the data. Check the input file.');
end
P = [dat.pos_x(g), dat.pos_y(g), dat.pos_z(g)];
r = dat.radius(g);

geo = get_container_geometry(container, P, r);

% Size distribution and single-color grains
[C, ~] = plot_colors(1);
light = [0.86 0.92 0.98];
gcol  = light + 0.5*(C(1,:) - light);
F = figure('Name','positions','Units','centimeters','Position',[2 2 17 17]);
T = tiledlayout(F, 2, 2, 'TileSpacing','compact', 'Padding','compact');
plot_size_hist(nexttile(T, 1), 2*r, C(1,:));
draw_triple_view(T, P, r, geo, gcol, 'Slice', opts.Slice, ...
    'SliceViews', opts.SliceViews, 'SliceThickness', opts.SliceThickness);
plot_format(F, 'PanelLabelLocation', 'outside');

% Save plot
if ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F, fullfile(rpath,'positions.png'), 'Resolution', 300, 'Padding', 'figure');
end

end

% -------------------------------------------------------------------------
% Grain size histogram (50 equal-width bins spanning the smallest to the
% largest grain) with a fitted normal distribution. If all grains are the
% same size (to round-off), one bar and no fit.
% -------------------------------------------------------------------------
function plot_size_hist(ax, d, col)

hold(ax, 'on');
mu   = mean(d);
mono = max(d) - min(d) <= 1e-9 * mu;
if mono
    d   = mu * ones(size(d));             % remove round-off spread
    sig = 0;
    w   = 0.05 * mu;                      % one bar, 5% of the size wide
    histogram(ax, d, 'BinEdges', mu + [-w w]/2, 'Normalization','percentage', ...
        'FaceColor', col, 'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.25);
    xlim(ax, mu * [0.5 1.5]);
else
    sig = std(d);
    H = histogram(ax, d, 'NumBins', 50, 'Normalization','percentage', ...
        'FaceColor', col, 'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.25);
end

% Fitted normal distribution, scaled to match the percentage histogram
if ~mono
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
