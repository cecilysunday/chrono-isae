% -------------------------------------------------------------------------
% FUNCTION  view_positions      Plot the grain size distribution and the
%                               grain positions in a 2 x 2 layout:
%                               top left      size distribution
%                               top right     top view   (along z)
%                               bottom left   side view  (along x)
%                               bottom right  front view (along y)
% INPUTS    dat                 Data structure from import_state_bin
%           rpath (optional)    Filepath to results folder. If given, the
%                               figure is saved there as a PNG
% OUTPUTS   F                   Figure handle
%
% NOTES     - Only bodies with body_id >= 0 (grains) are plotted
%           - Grains are drawn as circles at their true radius, so they
%             have the correct size relative to the container. Nearer
%             grains are drawn on top of farther ones.
%           - All three views use the same axis range (and so the same
%             scale), sized to fit the largest container dimension
%           - The container is inferred from the grain positions: if all
%             grains fit inside a circle about one of the axes it is drawn
%             as a cylinder (e.g. a drum), otherwise as a box
%           - Assumes the mm-g-s unit system
% -------------------------------------------------------------------------
function [F] = view_positions(dat,rpath)

% Grains only
g = dat.body_id >= 0;
P = [dat.pos_x(g), dat.pos_y(g), dat.pos_z(g)];
r = dat.radius(g);

[C, ~] = plot_colors(1);
names = 'xyz';

% Container geometry: bounding box, then try a cylinder about each axis
lo = min(P - r, [], 1);
hi = max(P + r, [], 1);
cyl = find_cylinder(P, r, lo, hi);
d  = 2*r;

% Cylinder sets the full extent in the two cross-section directions
if ~isempty(cyl)
    ax2 = setdiff(1:3, cyl.axis);
    lo(ax2) = cyl.center - cyl.R;
    hi(ax2) = cyl.center + cyl.R;
end

% Figure formatting - set same axis range in every view
pad = 0.03 * max(hi - lo);
hw  = max(hi - lo)/2 + pad;
ctr = (lo + hi)/2;

% Create figure
F = figure('Name','positions','Units','centimeters','Position',[2 2 17 17]);
T = tiledlayout(F, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% Panel 1 Top left: grain size distribution
ax = nexttile(T, 1);
histogram(ax, d, 'Normalization','percentage', 'FaceColor', C(1,:), ...
    'FaceAlpha', 1, 'EdgeColor', 'w', 'LineWidth', 0.5);
xlabel(ax, 'Grain diameter (mm)');
ylabel(ax, 'Grains (%)');
title(ax, 'Size distribution');
ylim(ax, [0, 1.25*max(ylim(ax))]);
pbaspect(ax, [1 1 1]);
text(ax, 0.04, 0.96, sprintf('N = %s grains', format_count(numel(r))), ...
    'Units','normalized', 'VerticalAlignment','top');

% Other views {tile, title, viewing axis, horizontal axis, vertical axis}
views = {2, 'Top view',   3, 1, 2;      % along z: x right, y up
         3, 'Side view',  1, 2, 3;      % along x: y right, z up
         4, 'Front view', 2, 1, 3};     % along y: x right, z up

for k = 1:size(views,1)
    [tile, name, a, h, v] = views{k,:};
    ax = nexttile(T, tile);
    hold(ax, 'on');

    % Grains as true-size circles; depth on z so nearer grains cover farther
    draw_circles(ax, P(:,h), P(:,v), P(:,a), r, C(1,:));

    % Container outline (above all grains)
    ztop = max(P(:,a)) + 1;
    if ~isempty(cyl) && cyl.axis == a
        t  = linspace(0, 2*pi, 361);
        ih = find(ax2 == h);
        iv = find(ax2 == v);
        plot3(ax, cyl.center(ih) + cyl.R*cos(t), cyl.center(iv) + cyl.R*sin(t), ...
            ztop*ones(size(t)), 'k-', 'LineWidth', 1);
    else
        plot3(ax, [lo(h) hi(h) hi(h) lo(h) lo(h)], [lo(v) lo(v) hi(v) hi(v) lo(v)], ...
            ztop*ones(1,5), 'k-', 'LineWidth', 1.);
    end

    view(ax, 2);
    axis(ax, 'equal');
    xlim(ax, ctr(h) + [-hw hw]);
    ylim(ax, ctr(v) + [-hw hw]);
    xlabel(ax, sprintf('%s (mm)', names(h)));
    ylabel(ax, sprintf('%s (mm)', names(v)));
    title(ax, name);
end

% Formatting
plot_format(F, 'PanelLabelLocation', 'outside');

% Save plot
if nargin > 1 && ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F, fullfile(rpath,'positions.png'), 'Resolution', 300, 'Padding', 'figure');
end

end

% -------------------------------------------------------------------------
% Draw N circles (centers u,v, radii r) as one patch. The depth d is used
% as the z coordinate so the depth buffer puts nearer grains on top.
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

patch(ax, 'Faces', Fc, 'Vertices', V, 'FaceColor', col, ...
    'EdgeColor', 0.6*col, 'LineWidth', 0.1);

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
% Integer with thousands separators, e.g. 60898 -> '60,898'
% -------------------------------------------------------------------------
function s = format_count(n)
s = fliplr(regexprep(fliplr(sprintf('%d', n)), '(\d{3})(?=\d)', '$1,'));
end
