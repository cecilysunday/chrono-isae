% -------------------------------------------------------------------------
% FUNCTION  plot_format     Applies a standard formatting to every axes in
%                           a figure after a plot is created
% INPUTS    F (optional)    Optional figure handle. Defaults to current figure
% OPTS      'PanelLabels'   true/false. Add (a), (b), ... to the top right
%                           of each panel. Default: true when the figure
%                           has more than one axes.
%           'PanelLabelLocation' 'inside' (default) puts the label just
%                           inside the top right corner; 'outside' puts it
%                           just above the top right corner, level with
%                           the title (use when data fills the axes)
%           'FontSize'      Font size in pt for axis labels, titles,
%                           legends, text and panel labels. Tick labels
%                           are always 1 pt smaller. Default: 12
%           'DecadeTicks'   true/false. On log-scale axes (x and/or y),
%                           pad the limits out to whole decades and put a
%                           tick on every decade. Default: false
%           'DecadeHeadroom' Extra empty decades added above the data on
%                           log axes (e.g. 1 to make room for a legend).
%                           Only used when DecadeTicks is true. Default: 0
% -------------------------------------------------------------------------
function plot_format(F, opts)

arguments
    F = gcf
    opts.PanelLabels = []
    opts.PanelLabelLocation {mustBeMember(opts.PanelLabelLocation, {'inside','outside'})} = 'inside'
    opts.FontSize (1,1) double {mustBePositive} = 12
    opts.DecadeTicks (1,1) logical = false
    opts.DecadeHeadroom (1,1) double {mustBeInteger, mustBeNonnegative} = 0
end

font  = 'Times New Roman';
fsize = opts.FontSize;
acol  = [0.25 0.25 0.25];
[C, P] = plot_colors();

set(F, 'Color', 'w');

AX = sort_axes(findobj(F, 'Type', 'axes'));
if isempty(opts.PanelLabels)
    opts.PanelLabels = numel(AX) > 1;
end

for i = 1:numel(AX)
    ax = AX(i);

    % Colors (only affects series without an explicit color)
    colororder(ax, C);

    % Axes, ticks, box, grid
    set(ax, 'FontName', font, 'FontSize', fsize - 1, ...   % tick labels
        'LineWidth', 0.75, 'Box', 'on', 'TickDir', 'in', ...
        'XMinorTick', 'off', 'YMinorTick', 'off', 'ZMinorTick', 'off', ...
        'XGrid', 'off', 'YGrid', 'off', 'ZGrid', 'off', ...
        'XMinorGrid', 'off', 'YMinorGrid', 'off', 'ZMinorGrid', 'off', ...
        'XColor', acol, 'YColor', acol, 'ZColor', acol, ...
        'Layer', 'top');
    ax.Toolbar.Visible = 'off';

    % Minor ticks only on log-scale axes
    for dim = 'XYZ'
        if strcmp(ax.([dim 'Scale']), 'log')
            ax.([dim 'MinorTick']) = 'on';
        end
    end

    % Whole-decade limits and ticks on log axes
    if opts.DecadeTicks
        decade_ticks(ax, opts.DecadeHeadroom);
    end

    % Labels and titles get exactly fsize below (no automatic scaling)
    ax.LabelFontSizeMultiplier = 1;
    ax.TitleFontSizeMultiplier = 1;

    % Labels and title
    for L = [ax.XLabel, ax.YLabel, ax.ZLabel]
        set(L, 'FontName', font, 'FontSize', fsize, 'Color', acol);
    end
    ax.TitleHorizontalAlignment = 'center';
    set(ax.Title, 'FontName', font, 'FontSize', fsize, ...
        'FontWeight', 'bold', 'Color', P.ink);

    % Legend
    if ~isempty(ax.Legend)
        set(ax.Legend, 'FontName', font, 'FontSize', fsize, ...
            'TextColor', P.ink, 'EdgeColor', acol, 'LineWidth', 0.5);
    end

    % Any other text objects (annotations, but not the panel labels)
    T = findobj(ax, 'Type', 'text', '-not', 'Tag', 'panel_label');
    set(T, 'FontName', font, 'FontSize', fsize);

    % Panel label (replaced, not duplicated, if called again)
    delete(findobj(ax, 'Tag', 'panel_label'));
    if opts.PanelLabels
        if strcmp(opts.PanelLabelLocation, 'inside')
            xy = [0.98 0.96];  valign = 'top';
        else
            xy = [1.00 1.01];  valign = 'bottom';
        end
        text(ax, xy(1), xy(2), sprintf('(%c)', 'a' + i - 1), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', valign, 'FontName', font, ...
            'FontSize', fsize, 'Color', P.ink, 'Tag', 'panel_label');
    end
end

% Colorbars
CB = findobj(F, 'Type', 'colorbar');
set(CB, 'FontName', font, 'FontSize', fsize - 1, 'TickDirection', 'in', ...
    'Color', acol, 'LineWidth', 0.75);
for i = 1:numel(CB)
    set(CB(i).Label, 'FontName', font, 'FontSize', fsize);
end

end

% -------------------------------------------------------------------------
% For each log-scale axis direction, pad the limits out to whole decades
% (plus 'headroom' extra decades at the top) and tick every decade
% -------------------------------------------------------------------------
function decade_ticks(ax, headroom)

H = findobj(ax, '-property', 'YData', '-property', 'XData');
for dim = 'XY'
    if ~strcmp(ax.([dim 'Scale']), 'log')
        continue;
    end
    L = [inf -inf];
    for h = H'
        v = h.([dim 'Data']);
        v = v(isfinite(v) & v > 0);
        if ~isempty(v)
            L = [min(L(1), min(v)), max(L(2), max(v))];
        end
    end
    if all(isfinite(L))
        d = floor(log10(L(1))) : ceil(log10(L(2))) + headroom;
        if isscalar(d), d = [d d+1]; end   % data within a single decade
        ax.([dim 'Lim'])  = 10.^d([1 end]);
        ax.([dim 'Tick']) = 10.^d;
    end
end

end

% -------------------------------------------------------------------------
% Order axes the way a reader sees them: tile order for tiledlayout,
% otherwise top-to-bottom then left-to-right by on-screen position
% -------------------------------------------------------------------------
function AX = sort_axes(AX)

if numel(AX) < 2
    return;
end

tiles = nan(numel(AX), 1);
for i = 1:numel(AX)
    if isa(AX(i).Parent, 'matlab.graphics.layout.TiledChartLayout') ...
            && isnumeric(AX(i).Layout.Tile)
        tiles(i) = AX(i).Layout.Tile;
    end
end

if all(~isnan(tiles))
    [~, k] = sort(tiles);
else
    pos = zeros(numel(AX), 2);
    for i = 1:numel(AX)
        p = getpixelposition(AX(i), true);
        pos(i,:) = [-(p(2) + p(4)), p(1)];   % top edge (desc), left (asc)
    end
    [~, k] = sortrows(round(pos));
end
AX = AX(k);

end
