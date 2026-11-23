% -------------------------------------------------------------------------
% FUNCTION  plot_colors     Standard color palette for all plots
% INPUTS    n   (optional)  Number of series colors to return (1-8).
%                           Default returns all 8.
% OUTPUTS   C               n x 3 RGB matrix of series colors, always in the
%                           same fixed order (blue, orange, aqua, yellow,
%                           magenta, green, violet, red). Assign them in
%                           order -- series 1 gets C(1,:), etc.
%           P               Structure of neutral colors:
%                           P.ink    primary text / axes
%                           P.ink2   secondary text / annotations
%                           P.gray   reference lines, fills
%
% NOTES     - The first 3 colors stay distinguishable for colorblind
%             readers in any arrangement (scatter, overlapping lines).
%             Colors 4-8 are reliable for lines/bars next to each other,
%             but pair them with a legend or direct labels.
%           - More than 8 series is an error on purpose: group extra
%             series into "Other" or split into more panels instead of
%             repeating colors.
%
% EXAMPLE   C = plot_colors(3);
%           plot(x, y1, 'Color', C(1,:)); hold on
%           plot(x, y2, 'Color', C(2,:));
% -------------------------------------------------------------------------
function [C, P] = plot_colors(n)

hex = { ...
    '2a78d6'   % 1 blue
    'eb6834'   % 2 orange
    '1baf7a'   % 3 aqua
    'eda100'   % 4 yellow
    'e87ba4'   % 5 magenta
    '008300'   % 6 green
    '6250d6'   % 7 violet
    'e34948'   % 8 red
    };

C = zeros(numel(hex), 3);
for i = 1:numel(hex)
    C(i,:) = sscanf(hex{i}, '%2x%2x%2x', [1 3]) / 255;
end

if nargin > 0
    if n > size(C,1)
        error('plot_colors:tooMany', ...
            ['Requested %d colors but the palette has %d. Group extra ' ...
             'series into "Other" or split into more panels.'], n, size(C,1));
    end
    C = C(1:n,:);
end

P.ink  = [0.043 0.043 0.043];   % #0b0b0b
P.ink2 = [0.322 0.318 0.306];   % #52514e
P.gray = [0.70  0.70  0.69];

end
