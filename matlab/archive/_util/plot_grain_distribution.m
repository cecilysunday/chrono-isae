% ------------------------------------------------------------------------
% Show the size distribution of the grains in the system
%
% Input:   dat   Table containing the particle information
% Output:        Plot of grain size distribution    
% ------------------------------------------------------------------------

function plot_grain_distribution(dat)

% Remove all wall items from the data table, assuming that walls have a
% negetive ID number
dat = dat(dat.body_id >= 0,:);

% Fit a normal distribution to the particles
dia = dat.radius * 2.0;
ndist = fitdist(dia,'Normal');
str = {['\mu = ',num2str(ndist.mu)],['\sigma = ',num2str(ndist.sigma)],...
       ['min = ',num2str(min(dia))], ['max = ',num2str(max(dia))]};

% Create a histogram of the distribution
figure('name', 'system_grain_size_distribution')
set(gcf, 'Position',  [100, 100, 400, 400])

histfit(dia,25,'Normal');

ylim = get(gca,'ylim');
xlim = get(gca,'xlim');
shift = (xlim(2)-xlim(1))/100;
text(xlim(1) + shift, ylim(2) - shift,...
     str, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');

box on
set(gcf,'Color','w');

end