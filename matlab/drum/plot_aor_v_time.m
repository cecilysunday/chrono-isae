% -------------------------------------------------------------------------
% FUNCTION  plot_aor_v_time     Plot the mean angle of repose over time,
%                               with its error (+/-) as a shaded band
%                               behind the line, and save the values
% INPUTS    t                   Times (s)
%           theta               Mean angle of repose at each time (deg),
%                               from find_angle_of_repose
%           err                 Error of each mean (deg)
%           rpath (optional)    Filepath to results folder. If given, the
%                               figure is saved there as
%                               angle_of_repose_time.png and the values as
%                               angle_of_repose_time.csv
% OUTPUTS   F                   Figure handle
% -------------------------------------------------------------------------
function F = plot_aor_v_time(t, theta, err, rpath)

arguments
    t (:,1) double
    theta (:,1) double
    err (:,1) double
    rpath = ''
end

[t, order] = sort(t);
theta = theta(order);
err   = err(order);

[C, ~] = plot_colors(1);
F  = figure('Name','angle_of_repose_time','Units','centimeters','Position',[2 2 14 9]);
ax = axes(F);
hold(ax, 'on');
% Shaded band of theta +/- err behind the line (times without a value are
% left out of the band)
ok = ~isnan(theta) & ~isnan(err);
tb = t(ok);
fill(ax, [tb; flipud(tb)], [theta(ok) - err(ok); flipud(theta(ok) + err(ok))], C(1,:), ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(ax, t, theta, 'o-', 'Color', C(1,:), 'MarkerFaceColor', C(1,:), ...
    'MarkerSize', 4, 'LineWidth', 1);
xlabel(ax, 'Time (s)');
ylabel(ax, 'Angle of repose (\circ)');
title(ax, 'Angle of repose over time');
yl = ylim(ax);
ylim(ax, yl + [-1 1]*0.1*diff(yl));
plot_format(F);

if ~isempty(rpath)
    if ~isfolder(rpath)
        mkdir(rpath);
    end
    exportgraphics(F, fullfile(rpath,'angle_of_repose_time.png'), 'Resolution', 300, 'Padding', 'figure');
    writetable(table(t, theta, err, 'VariableNames', {'time_s','theta_deg','err_deg'}), ...
        fullfile(rpath,'angle_of_repose_time.csv'));
end

end
