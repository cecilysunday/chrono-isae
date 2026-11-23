% -------------------------------------------------------------------------
% FUNCTION  slice_grains        Keep only the grains inside a slab of
%                               thickness t centered on the plane
%                               <axis> = value
% INPUTS    dat                 Data structure from import_state_bin
%           axis                Normal of the plane: 'x', 'y' or 'z'
%           value               Position of the plane along that axis (mm)
% OPTS      'Thickness'         Slab thickness t (mm). Default: 2 mean
%                               grain diameters
% OUTPUTS   dsl                 Copy of dat with only the grains in the
%                               slab (other bodies, body_id < 0, are kept)
%           in                  Logical mask over the rows of dat: true
%                               for the rows kept in dsl
%           t                   Slab thickness used (mm)
%
% NOTES     - A grain is in the slab when its center is: |pos - value| <= t/2.
% -------------------------------------------------------------------------
function [dsl, in, t] = slice_grains(dat, axis, value, opts)

arguments
    dat
    axis {mustBeMember(axis, {'x','y','z'})}
    value (1,1) double
    opts.Thickness (1,1) double = NaN
end

g = dat.body_id >= 0;
if ~any(g)
    error('slice_grains:noGrains', ...
        'No grains (body_id >= 0) in the data. Check the input file.');
end
t = opts.Thickness;
if isnan(t)
    t = 2 * mean(2*dat.radius(g));
elseif t <= 0
    error('slice_grains:badThickness', 'Thickness must be positive.');
end

pos = dat.(['pos_' char(axis)]);
in  = ~g | abs(pos - value) <= t/2;

% Same rows from every per-body field
dsl = dat;
n   = numel(dat.body_id);
for f = fieldnames(dat)'
    x = dat.(f{1});
    if size(x, 1) == n
        dsl.(f{1}) = x(in, :);
    end
end

end
