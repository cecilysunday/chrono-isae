% -------------------------------------------------------------------------
% FUNCTION  get_container_geometry
%                   Container outline and the common axis
%                   range used by view_static and view_dynamic
% INPUTS    c       Struct describing the container (mm):
%                   Cylinder:
%                       .shape       'cylinder'
%                       .diameter    inner diameter
%                       .height      inner height (along axis)
%                       .orientation axis direction 'x','y','z'
%                    Box:
%                        .shape       'box'
%                        .x, .y, .z   inner dimensions
%                    Both (optional):
%                        .center      [x y z] of the container center. Default [0 0 0]
%           P        N x 3 grain positions (mm)
%           r        N x 1 grain radii (mm)
% OUTPUTS   geo      Struct with fields
%                    geo.lo, geo.hi   container bounds [x y z]
%                    geo.cyl          [] for a box and struct(axis, center,R) for cyl
%                    geo.ctr          container center
%                    geo.hw           half-width of the axis range shared by all views
%
% NOTES     - The axis range covers the container and any grains outside
%             it, so all views use the same scale
% -------------------------------------------------------------------------
function geo = get_container_geometry(c, P, r)

if ~isfield(c, 'shape')
    error('get_container_geometry:badContainer',...
    'container must have a ''shape'' field of ''cylinder'' or ''box''.');
end

% Center (optional, default origin)
ctr = [0 0 0];
if isfield(c, 'center') && ~isempty(c.center)
    ctr = c.center;
    if ~isnumeric(ctr) || numel(ctr) ~= 3
        error('get_container_geometry:badContainer', ...
            'container.center must contain numerical [x y z] values.');
    end
    ctr = double(ctr(:)');
end

cyl = [];
switch lower(char(c.shape))
    case {'cylinder', 'cyl'}
        D = get_dim(c, 'diameter');
        H = get_dim(c, 'height');
        if ~isfield(c, 'orientation')
            error('get_container_geometry:badContainer', ...
                'A cylinder needs container.orientation (''x'', ''y'' or ''z'').');
        end
        a = find(strcmpi(char(c.orientation), {'x','y','z'}));
        if isempty(a)
            error('get_container_geometry:badContainer', ...
                'container.orientation must be ''x'', ''y'' or ''z''.');
        end
        ax2 = setdiff(1:3, a);
        L = zeros(1,3);
        L(a)   = H;
        L(ax2) = D;
        cyl = struct('axis', a, 'center', ctr(ax2), 'R', D/2);
    case 'box'
        L = [get_dim(c, 'x'), get_dim(c, 'y'), get_dim(c, 'z')];
    otherwise
        error('get_container_geometry:badContainer', ...
            'container.shape must be ''cylinder'' or ''box''.');
end
lo = ctr - L/2;
hi = ctr + L/2;

% Same axis range in every view, covering the container and any grains outside
elo = min(lo, min(P - r, [], 1));
ehi = max(hi, max(P + r, [], 1));
pad = 0.03 * max(ehi - elo);
geo = struct('lo', lo, 'hi', hi, 'cyl', cyl, ...
    'hw', max(ehi - elo)/2 + pad, 'ctr', (elo + ehi)/2);

end

% -------------------------------------------------------------------------
% Positive scalar dimension 'name' from the container struct
% -------------------------------------------------------------------------
function d = get_dim(c, name)
if ~isfield(c, name) || ~isnumeric(c.(name)) || ~isscalar(c.(name)) || c.(name) <= 0
    error('get_container_geometry:badContainer', ...
        'Container.%s must be a positive scalar (mm).', name);
end
d = double(c.(name));
end
