% ------------------------------------------------------------------------
% Function to import simulation energy file as a matlab table
%
% Input:   energy   Table containing the simulation kinetic energy data
% Output:           Plot of kinetic energy vs time    
% ------------------------------------------------------------------------

function plot_energy(energy)

figure('name', 'system_energy')
set(gcf, 'Position',  [100, 100, 400, 600])

var = {energy.time, energy.mean_KE_trn, energy.mean_KE_rot, energy.mean_KE};
var_names = {'time (s)', 'Translational KE', 'Rotational KE', 'Total KE'};

ax1 = subplot(3,1,1);
hold on
plot(var{1}, var{2});
xlabel(var_names{1});
ylabel(var_names{2});
set(gca, 'YScale', 'log')
box on

ax2 = subplot(3,1,2);
hold on
plot(var{1}, var{3});
xlabel(var_names{1});
ylabel(var_names{3});
set(gca, 'YScale', 'log')
box on

ax3 = subplot(3,1,3);
hold on
plot(var{1}, var{4});
xlabel(var_names{1});
ylabel(var_names{4});
set(gca, 'YScale', 'log')
box on

set(gcf,'Color','w');
linkaxes([ax3,ax1],'xy');
linkaxes([ax3,ax2],'xy');

end