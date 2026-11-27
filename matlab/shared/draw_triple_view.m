% -------------------------------------------------------------------------
% FUNCTION  draw_triple_view    Draw the top, side and front views of the
%                               grains and container in tiles 2-4
% INPUTS    T                   Tiled layout (2 x 2)
%           P                   N x 3 grain positions (mm)
%           r                   N x 1 grain radii (mm)
%           geo                 Struct from get_container_geometry
%           col                 One RGB color for all grains, or an N x 3
%                               RGB color per grain
% OPTS      'Slice'             [x y z] point the slices pass through.
%                               Default: [] (no slicing)
%           'SliceViews'        Views to slice, any of "top", "side",
%                               "front". Default: all three
%           'SliceThickness'    Slab thickness (mm). Default: 3 mean grain
%                               diameters
% OUTPUTS   AX                  The three axes [top, side, front]
%
% NOTES     - Each view is drawn by draw_single_view
%           - Viewers sit at +z (top), +x (side) and -y (front), so each
%             view is right-handed and not mirrored
%           - All three views use the same axis range (and so the same
%             scale)
%           - A sliced view shows only the grains whose centers lie within
%             +/- thickness/2 of the plane through the Slice point,
%             normal to the viewing direction (top: z, side: x, front: y),
%             the same rule as slice_grains. Its title gives the plane
% -------------------------------------------------------------------------
function AX = draw_triple_view(T, P, r, geo, col, opts)

arguments
    T
    P
    r
    geo
    col
    opts.Slice double = []
    opts.SliceViews string {mustBeMember(opts.SliceViews, ["top","side","front"])} = ["top","side","front"]
    opts.SliceThickness (1,1) double = NaN
end

% Slicing
dosl = ~isempty(opts.Slice);
if dosl
    if numel(opts.Slice) ~= 3
        error('draw_triple_view:badSlice', 'Slice must be an [x y z] point.');
    end
    t = opts.SliceThickness;
    if isnan(t)
        t = 3 * mean(2*r);
    elseif t <= 0
        error('draw_triple_view:badThickness', 'SliceThickness must be positive.');
    end
end
percol = ~isequal(size(col), [1 3]);

% {tile, title, key, viewing axis, horizontal axis, vertical axis, side}
% 'side' is where the viewer sits along the viewing axis (+1 or -1),
% chosen so (horizontal, vertical, toward viewer) is right-handed
views = {2, 'Top view',   "top",   3, 1, 2,  1;     % from +z: x right, y up
         3, 'Side view',  "side",  1, 2, 3, -1;     % from -x: y right, z up
         4, 'Front view', "front", 2, 1, 3, -1};    % from -y: x right, z up
names = 'xyz';

AX = gobjects(1, size(views,1));
for k = 1:size(views,1)
    [tile, name, key, a, h, v, s] = views{k,:};
    AX(k) = nexttile(T, tile);

    % Grains in this view: all, or the slab normal to the viewing axis
    m   = true(size(r));
    sub = '';
    if dosl && any(opts.SliceViews == key)
        p0  = opts.Slice(a);
        m   = abs(P(:,a) - p0) <= t/2;
        sub = sprintf('Slice %s = %.3g \\pm %.2g mm', names(a), p0, t/2);
    end
    c = col;
    if percol, c = col(m,:); end

    draw_single_view(AX(k), P(m,:), r(m), geo, c, a, h, v, s);
    title(AX(k), name);
    if ~isempty(sub)
        subtitle(AX(k), sub);
    end
end

end
