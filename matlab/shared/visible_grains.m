% -------------------------------------------------------------------------
% FUNCTION  visible_grains      Find the grains that can be seen by a
%                               viewer looking along one axis
% INPUTS    u, v                N x 1 grain centers in the view plane
%                               (horizontal, vertical)
%           depth               N x 1 grain center position toward the
%                               viewer (larger = nearer)
%           r                   N x 1 grain radii
%           ds                  Spacing of the sample points (see NOTES)
% OPTS      'VRange'            [min max]: only use sample points with v in
%                               this range. Default: [-inf inf]
% OUTPUTS   idx                 Sorted indices of the visible grains
%
% NOTES     - Sample points lie on a square u-v grid with spacing ds. At
%             each point, the visible grain is the one whose sphere surface
%             is nearest the viewer right at that point:
%             depth + sqrt(r^2 - d^2), d = distance from the grain center.
%             A grain covers many points but is listed once
%           - A grain that only shows in a sliver narrower than ds can be
%             missed. Use ds well below the smallest radius when drawing
% -------------------------------------------------------------------------
function idx = visible_grains(u, v, depth, r, ds, opts)

arguments
    u (:,1) double
    v (:,1) double
    depth (:,1) double
    r (:,1) double
    ds (1,1) double {mustBePositive}
    opts.VRange (1,2) double = [-inf inf]
end

N = numel(u);
idx = zeros(0,1);
if N == 0, return; end
u0 = min(u - r);
v0 = min(v - r);

% Offsets of the sample points around each grain's nearest point, wide
% enough to cover the largest grain
m = ceil(max(r)/ds) + 1;
[ox, oy] = meshgrid(-m:m);
ox = ox(:)';  oy = oy(:)';                % 1 x K
NV = ceil((max(v + r) - v0)/ds) + 2*m + 3;

% Covered sample points of every grain, in chunks to limit memory
chunk = 5000;
nc = ceil(N/chunk);
keys = cell(nc,1);  hts = cell(nc,1);  gis = cell(nc,1);
for c = 1:nc
    j  = ((c-1)*chunk + 1 : min(c*chunk, N))';
    ix = round((u(j) - u0)/ds) + ox;
    iy = round((v(j) - v0)/ds) + oy;
    vs = v0 + iy*ds;
    d2 = (u0 + ix*ds - u(j)).^2 + (vs - v(j)).^2;
    in = d2 <= r(j).^2 & vs >= opts.VRange(1) & vs <= opts.VRange(2);
    h  = depth(j) + sqrt(max(r(j).^2 - d2, 0));
    G  = repmat(j, 1, numel(ox));
    keys{c} = (ix(in) + m + 1) * NV + (iy(in) + m + 1);
    hts{c}  = h(in);
    gis{c}  = G(in);
end
key = vertcat(keys{:});
h   = vertcat(hts{:});
g   = vertcat(gis{:});
if isempty(key), return; end

% Nearest grain at each sample point, then unique grains
[~, order] = sortrows([key, -h]);
first = [true; diff(key(order)) ~= 0];
idx = unique(g(order(first)));

end
