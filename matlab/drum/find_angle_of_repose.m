% -------------------------------------------------------------------------
% FUNCTION  find_angle_of_repose  Find the angle of repose in every slice
%                               across the depth (y) of the container, and
%                               their mean. In each slice, the top layer of
%                               grains is found and a line is fitted
%                               through it.
% INPUTS    dat                 Data structure from import_state_bin
%           container           Struct describing the container (mm), see
%                               get_container_geometry
%           rpath (optional)    Filepath to results folder. If given, the
%                               figures are saved there as
%                               angle_of_repose.png and
%                               angle_of_repose_depth.png
% OPTS      'SliceThickness'    Thickness (mm) of each slice. Default: 2
%                               mean grain diameters
%           'Resolution'        Spacing (mm) of the x-y sample points used
%                               to find the surface grains (see NOTES).
%                               Default: 0.75*1 mean grain diameter
%           'Trim'              Fraction of the surface's x extent dropped
%                               at each end before fitting, to leave out
%                               the curved surface near the drum wall.
%                               Default: 0.15
% OUTPUTS   theta               Mean angle of repose over all slices (deg)
%           err                 Standard error of that mean (deg):
%                               std(slice angles) / sqrt(number of slices)
%           S                   Struct with the details:
%                                 .y          slice centers (mm)
%                                 .theta      angle in each slice (deg)
%                                 .err        standard error of each
%                                             slice's angle (deg)
%                                 .n          surface grains in each slice
%                                 .std        std of the slice angles (deg)
%                                 .thickness  slice thickness (mm)
%                                 .mid        fit in the plotted (middle)
%                                             slice: .y, .slope,
%                                             .intercept, .surface
%                                             (indices into dat)
%                                 .F          figure handles [view, depth]
%
% NOTES     - Gravity is along -z and the surface is fitted in the x-z
%             plane (the front view)
%           - Only bodies with body_id >= 0 (grains) are used
%           - Slices are created side by side (no overlap) and centered in
%             the container's y range.
%           - The surface contains grains that are visible from above.
%           - A line fit is created through each slice. Then grains more 
%             than 3 standard deviations from the line (e.g. loose grains on top) 
%             are removed and the line is fitted again. A slice's error is 
%             calculated from the standard error of the slope
%             se(slope) / (1 + slope^2), in degrees
%           - Slices with fewer than 3 surface grains are left out of the mean
% -------------------------------------------------------------------------
function [theta, err, S] = find_angle_of_repose(dat,container,rpath,opts)

arguments
    dat
    container (1,1) struct
    rpath = ''
    opts.SliceThickness (1,1) double = NaN
    opts.Resolution (1,1) double = NaN
    opts.Trim (1,1) double {mustBeInRange(opts.Trim, 0, 0.49)} = 0.15
end

% Grains only
g = find(dat.body_id >= 0);
if isempty(g)
    error('find_angle_of_repose:noGrains', ...
        'No grains (body_id >= 0) in the data. Check the input file.');
end
P = [dat.pos_x(g), dat.pos_y(g), dat.pos_z(g)];
r = dat.radius(g);
geo = get_container_geometry(container, P, r);

dmean = mean(2*r);
t = opts.SliceThickness;
if isnan(t), t = 2*dmean; end
ds = opts.Resolution;
if isnan(ds), ds = 0.75*dmean; end
if t <= 0 || ds <= 0
    error('find_angle_of_repose:badSize', 'SliceThickness and Resolution must be positive.');
end

% Slices across the container depth, side by side and centered
ylo = geo.lo(2);
yhi = geo.hi(2);
ns  = floor((yhi - ylo) / t);
if ns < 1
    error('find_angle_of_repose:thickSlice', ...
        'SliceThickness (%.3g mm) is larger than the container depth (%.3g mm).', t, yhi - ylo);
end
yc = (ylo + yhi)/2 + ((1:ns) - (ns + 1)/2) * t;

% Fit every slice. The rule for membership matches slice_grains.
th = nan(1, ns);  se = nan(1, ns);  ng = zeros(1, ns);
fits = cell(1, ns);
for k = 1:ns
    fits{k} = fit_surface(P, r, yc(k) + [-1 1]*t/2, ds, opts.Trim);
    if ~isempty(fits{k})
        th(k) = fits{k}.theta;
        se(k) = fits{k}.err;
        ng(k) = fits{k}.n;
    end
end
ok = ~isnan(th);
if ~any(ok)
    error('find_angle_of_repose:noFit', ...
        'No slice has enough surface grains to fit. Try a larger SliceThickness.');
end
theta = mean(th(ok));
sd    = std(th(ok));
err   = sd / sqrt(nnz(ok));

% Slice to plot: the one nearest the middle that has a fit
[~, kmid] = min(abs(yc - (ylo + yhi)/2) + 1e9*~ok);
fm = fits{kmid};

% Colors
[C, Pn] = plot_colors();
light = [0.86 0.92 0.98];
blue  = light + 0.5*(C(1,:) - light);     % same grain color as view_static
red   = C(8,:);                           % same red as view_dynamic

% Figure 1: front view of the middle slice
F(1) = figure('Name','angle_of_repose','Units','centimeters','Position',[2 2 12 12]);
ax = axes(F(1));
in = abs(P(:,2) - yc(kmid)) <= t/2;
ztop = draw_single_view(ax, P(in,:), r(in), geo, blue, 2, 1, 3, -1);
xs = P(fm.idx,1);
draw_circles(ax, xs, P(fm.idx,3), ztop, r(fm.idx), red);
xl = [min(xs), max(xs)] + [-1 1]*0.1*(max(xs) - min(xs));
plot3(ax, xl, fm.m*xl + fm.b, (ztop + 1)*[1 1], 'k-', 'LineWidth', 1.5);
title(ax, 'Angle of repose');
subtitle(ax, sprintf('Slice y = %.3g \\pm %.2g mm', yc(kmid), t/2));
text(ax, 0.03, 0.97, { ...
    sprintf('\\theta = %.1f\\circ \\pm %.1f\\circ with %s surface grains', fm.theta, fm.err,format_count(fm.n)), ...
    sprintf('\\theta_{%d} = %.1f\\circ \\pm %.1f\\circ', nnz(ok), theta, err)}, ...
    'Units','normalized', 'VerticalAlignment','top', ...
    'BackgroundColor','w', 'Margin', 2);
plot_format(F(1));

% Figure 2: angle versus depth
F(2) = figure('Name','angle_of_repose_depth','Units','centimeters','Position',[2 2 14 9]);
ax = axes(F(2));
hold(ax, 'on');
xr = [ylo yhi] + [-1 1]*0.05*(yhi - ylo);
patch(ax, xr([1 2 2 1]), theta + err*[-1 -1 1 1], Pn.gray, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(ax, xr, theta*[1 1], '-', 'Color', Pn.ink2, 'LineWidth', 1);
errorbar(ax, yc(ok), th(ok), se(ok), 'o', 'Color', C(1,:), ...
    'MarkerFaceColor', C(1,:), 'MarkerSize', 5, 'LineWidth', 1, 'CapSize', 4);
yl = ylim(ax);
yl = yl + [-1 1]*0.15*diff(yl);
plot(ax, ylo*[1 1], yl, 'k-', 'LineWidth', 1.5);     % end walls
plot(ax, yhi*[1 1], yl, 'k-', 'LineWidth', 1.5);
xlim(ax, xr);
ylim(ax, yl);
xlabel(ax, 'y (mm)');
ylabel(ax, 'Angle of repose (\circ)');
title(ax, 'Angle of repose across the depth');
text(ax, 0.5, 0.96, sprintf('Mean = %.1f\\circ \\pm %.1f\\circ (%d slices, %.2g mm thick)', ...
    theta, err, nnz(ok), t), 'Units','normalized', ...
    'HorizontalAlignment','center', 'VerticalAlignment','top');
plot_format(F(2));

% Save plots
if ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F(1), fullfile(rpath,'angle_of_repose.png'), 'Resolution', 300, 'Padding', 'figure');
    exportgraphics(F(2), fullfile(rpath,'angle_of_repose_depth.png'), 'Resolution', 300, 'Padding', 'figure');
end

mid = struct('y', yc(kmid), 'slope', fm.m, 'intercept', fm.b, 'surface', g(fm.idx));
S = struct('y', yc, 'theta', th, 'err', se, 'n', ng, 'std', sd, ...
    'thickness', t, 'mid', mid, 'F', F);

% Print results
fprintf('Angle of repose: %.1f +/- %.1f deg\n', theta, err);

end

% -------------------------------------------------------------------------
% Surface fit for the slice ylim = [ymin ymax]. Returns [] if fewer than
% 3 surface grains are left. Otherwise a struct with the angle .theta and
% its standard error .err (deg), the line .m, .b, the surface grains used
% .idx (into P) and their number .n
% -------------------------------------------------------------------------
function f = fit_surface(P, r, ylim, ds, trim)

f = [];

% Grains that can cover a point in the slice: in it or overlapping it.
% The neighbors outside the slice block the view down its faces.
idx = find(P(:,2) + r >= ylim(1) & P(:,2) - r <= ylim(2));
if numel(idx) < 3, return; end
Q = P(idx,:);

% Visible grains whose centers lie in the slice
isurf = surface_grains(Q, r(idx), ds, ylim);
isurf = isurf(Q(isurf,2) >= ylim(1) & Q(isurf,2) <= ylim(2));
if numel(isurf) < 3, return; end

% Drop the ends of the surface, near the drum wall
xs = Q(isurf,1);
L  = max(xs) - min(xs);
isurf = isurf(xs >= min(xs) + trim*L & xs <= max(xs) - trim*L);
if numel(isurf) < 3, return; end

% Fit, drop outliers (> 3 sigma), fit again
[m, b, res] = line_fit(Q(isurf,1), Q(isurf,3));
keep = abs(res) <= 3*std(res);
if any(~keep) && nnz(keep) >= 3
    isurf = isurf(keep);
    [m, b] = line_fit(Q(isurf,1), Q(isurf,3));
end

% Angle and its standard error
x  = Q(isurf,1);
z  = Q(isurf,3);
n  = numel(isurf);
res  = z - (m*x + b);
se_m = sqrt(sum(res.^2) / max(n - 2, 1) / sum((x - mean(x)).^2));
f = struct('theta', atand(abs(m)), 'err', rad2deg(se_m / (1 + m^2)), ...
    'm', m, 'b', b, 'idx', idx(isurf), 'n', n);
end

% -------------------------------------------------------------------------
% Grains visible from above (indices into Q). Sample points on a square
% x-y grid with spacing ds, only where ylim(1) <= y <= ylim(2); at each
% point, the surface grain is the one whose top is highest right above
% it: z + sqrt(r^2 - d^2), d = distance from the grain center. A grain
% covers many points, so each is kept once.
% -------------------------------------------------------------------------
function isurf = surface_grains(Q, r, ds, ylim)

N  = size(Q,1);
x0 = min(Q(:,1) - r);
y0 = min(Q(:,2) - r);

% Offsets of the sample points around each grain's nearest point, wide
% enough to cover the largest grain
m = ceil(max(r)/ds) + 1;
[ox, oy] = meshgrid(-m:m);
ox = ox(:)';  oy = oy(:)';                % 1 x K

% Sample point indices and positions for every grain (N x K)
bx = round((Q(:,1) - x0)/ds);
by = round((Q(:,2) - y0)/ds);
ix = bx + ox;
iy = by + oy;
dx = x0 + ix*ds - Q(:,1);
dy = y0 + iy*ds - Q(:,2);
d2 = dx.^2 + dy.^2;
ys = y0 + iy*ds;                          % sample point y
in = d2 <= r.^2 & ys >= ylim(1) & ys <= ylim(2);   % points under the grain

% Height of each grain's top at each covered point
h  = Q(:,3) + sqrt(max(r.^2 - d2, 0));
gi = repmat((1:N)', 1, numel(ox));
key = (ix(in) + m) * (max(iy(:)) + 2*m + 2) + (iy(in) + m);

% Highest grain at each sample point, then unique grains
[~, order] = sortrows([key, -h(in)]);
first = [true; diff(key(order)) ~= 0];
g = gi(in);
isurf = unique(g(order(first)));

end

% -------------------------------------------------------------------------
% Least-squares line z = m*x + b, with residuals
% -------------------------------------------------------------------------
function [m, b, res] = line_fit(x, z)
A   = [x, ones(size(x))];
c   = A \ z;
m   = c(1);
b   = c(2);
res = z - A*c;
end
