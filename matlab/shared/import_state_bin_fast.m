% -------------------------------------------------------------------------
% FUNCTION  import_state_bin_fast  Import the binary data file for the
%                               granular bed. Same output as
%                               import_state_bin, but reads the whole file
%                               at once instead of value by value
% INPUTS    fname               Full file path and name of the data file
% OUTPUTS   dat                 Imported data structure
%           count               Number of particles in the system
%
% NOTES     - Each body is one 232-byte record:
%               int64   body_id
%               int32   collision_state, then 4 padding bytes
%               27 x double: time, radius, pos_x/y/z, rot_0/1/2/3,
%                            vel_x/y/z, wvel_x/y/z, acc_x/y/z,
%                            wacc_x/y/z, force_x/y/z, torque_x/y/z
%           - The magnitudes (pos_m, vel_m, ...) are added as in
%             import_state_bin. All fields are double column vectors
%           - Assumes the file was written on a little-endian machine
%             (x86), as import_state_bin does
% -------------------------------------------------------------------------
function [dat,count] = import_state_bin_fast(fname)

rec = 232;
fid = fopen(fname, 'rb');
if fid < 0
    error('import_state_bin_fast:open', 'Cannot open %s.', fname);
end
raw = fread(fid, inf, '*uint8');
fclose(fid);
if mod(numel(raw), rec) ~= 0
    error('import_state_bin_fast:size', ...
        '%s is %d bytes, not a whole number of %d-byte records.', fname, numel(raw), rec);
end
B = reshape(raw, rec, []);                % one column per body

% Integer fields
dat.body_id = double(typecast(reshape(B(1:8,:), [], 1), 'int64'));
dat.collision_state = double(typecast(reshape(B(9:12,:), [], 1), 'int32'));

% The 27 doubles, one row per field
D = reshape(typecast(reshape(B(17:end,:), [], 1), 'double'), 27, []);
names = {'time','radius','pos_x','pos_y','pos_z', ...
         'rot_0','rot_1','rot_2','rot_3', ...
         'vel_x','vel_y','vel_z','wvel_x','wvel_y','wvel_z', ...
         'acc_x','acc_y','acc_z','wacc_x','wacc_y','wacc_z', ...
         'force_x','force_y','force_z','torque_x','torque_y','torque_z'};
for k = 1:numel(names)
    dat.(names{k}) = D(k,:)';
    % Magnitude after each x-y-z group, as in import_state_bin
    if endsWith(names{k}, '_z')
        b = extractBefore(names{k}, '_z');
        dat.([b '_m']) = sqrt(dat.([b '_x']).^2 + dat.([b '_y']).^2 + dat.([b '_z']).^2);
    end
end

count = nnz(dat.body_id >= 0);

end
