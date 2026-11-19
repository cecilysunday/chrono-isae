% ------------------------------------------------------------------------
% Generate a pie chart comparing the different simulation timers
%
% Input:   stats   Table containing the general simulation statistics
% Output:          Pie chart comparing simulation timers    
% ------------------------------------------------------------------------

function plot_stats(stats)

% Define timers
timers = [stats.timer_broad_collision stats.timer_narrow_collision stats.timer_custom_collision stats.timer_other_collision ... 
          stats.timer_total_update stats.timer_total_advance stats.timer_total_other];
labels = {'collision-broad ('; 'collision-narrow ('; 'collision-custom ('; 'collision-other ('; 'update ('; 'advance ('; 'other ('};
remove = find(timers == 0);
timers(remove) = [];
labels(remove) = [];

% Plot simulation timers as pie chart
figure('name', 'system_stats')
set(gcf, 'Position',  [100, 100, 600, 400])
p = pie(timers);
ptext = findobj(p, 'Type', 'text');
pvalues = get(ptext, 'String'); 
combinedtxt = strcat(labels, pvalues, ')'); 
for i = 1:length(ptext)
    ptext(i).String = combinedtxt(i);
end
set(gcf, 'Color', 'w');
title('Computation Time by Function Type');
box('on');

txt1 = strcat('Number of bodies =', " ", num2str(stats.num_shapes, 4));
txt2 = strcat('CPU time =', " ", num2str(stats.sim_cpu, 4), " ", 'sec per time-step per body');
text(0, min(ylim)-0.10, txt1, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center');
text(0, min(ylim)-0.22, txt2, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center');

end