% -------------------------------------------------------------------------
% FUNCTION  draw_circles        Draw N circles as one patch
% INPUTS    ax                  Axes to draw in
%           u, v                N x 1 circle centers (horizontal, vertical)
%           d                   N x 1 depth (or a scalar for all), used as
%                               the z coordinate so the depth buffer puts
%                               nearer circles on top
%           r                   N x 1 radii
%           col                 One RGB color for all circles, or an N x 3
%                               RGB color per circle
% -------------------------------------------------------------------------
function draw_circles(ax, u, v, d, r, col)

n  = 16;                                  % vertices per circle
t  = (0:n-1) * 2*pi/n;
N  = numel(u);
X  = u + r .* cos(t);                     % N x n
Y  = v + r .* sin(t);
Z  = repmat(d(:) .* ones(N,1), 1, n);
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
