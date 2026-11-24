% -------------------------------------------------------------------------
% FUNCTION  draw_single_view    Draw one view of the grains and container
%                               outline, looking along one coordinate axis
% INPUTS    ax                  Axes to draw in
%           P                   N x 3 grain positions (mm)
%           r                   N x 1 grain radii (mm)
%           geo                 Struct from get_container_geometry
%           col                 One RGB color for all grains, or an N x 3
%                               RGB color per grain
%           a, h, v             Viewing, horizontal and vertical axis
%                               (1 = x, 2 = y, 3 = z)
%           s                   Side of the viewer along the viewing axis
%                               (+1 or -1)
% OPTS      'Cull'              true (default): draw only the grains that
%                               can be seen from the viewer (see
%                               visible_grains), which is much faster for
%                               large beds. false: draw all grains
% OUTPUTS   ztop                Depth just above all grains and the
%                               outline; draw anything at a larger depth
%                               to put it on top
%
% NOTES     - Grains are drawn as circles at their true radius. The depth
%             buffer shows only the grains visible from that side
%           - Culling samples the view on a grid with spacing of half the
%             smallest grain radius, so only slivers far below a pixel can
%             be lost
%           - A cylinder is drawn as a circle when viewed along its axis
%             and as a rectangle otherwise
% -------------------------------------------------------------------------
function ztop = draw_single_view(ax, P, r, geo, col, a, h, v, s, opts)

arguments
    ax
    P
    r
    geo
    col
    a
    h
    v
    s
    opts.Cull (1,1) logical = true
end

names = 'xyz';
cyl   = geo.cyl;
hold(ax, 'on');

% Grains as true-size circles. Depth = distance toward the viewer.
depth = s * P(:,a);
if opts.Cull && ~isempty(depth)
    k = visible_grains(P(:,h), P(:,v), depth, r, min(r)/4);
    P = P(k,:);  r = r(k);  depth = depth(k);
    if ~isequal(size(col), [1 3]), col = col(k,:); end
end
if ~isempty(depth)                        % e.g. an empty slice
    draw_circles(ax, P(:,h), P(:,v), depth, r, col);
end

% Container outline (above all grains)
ztop = max([depth; 0]) + 1;
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
ztop = ztop + 1;

view(ax, 2);
axis(ax, 'equal');
xlim(ax, geo.ctr(h) + [-geo.hw geo.hw]);
ylim(ax, geo.ctr(v) + [-geo.hw geo.hw]);
xlabel(ax, sprintf('%s (mm)', names(h)));
ylabel(ax, sprintf('%s (mm)', names(v)));

end
