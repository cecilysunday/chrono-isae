% ------------------------------------------------------------------------
% Function to import the body information in a simulation state file
%
% Input:   filename    Name of the bin file to import
% Output:  dat         Table containing all of the body information   
% ------------------------------------------------------------------------

function [dat] = import_state_bin(filename)

% Return a warning of the specified file does not exist
if ~isfile(filename)
    fprintf(2,'\nWARNING: requested file does not exist in the specified directory!!\n\n');
end

% Import the binary file using the ParticleData structure from WriteData.cpp
disp('Importing simulation data...');
fid = fopen(filename, 'rb');
body_id = fread(fid, 1, 'int64');

i = 1;
while ~isempty(body_id)
    dat.body_id(i,1) = body_id;
    dat.collision_state(i,1) = fread(fid, 1, 'int', 4);
    dat.time(i,1) = fread(fid, 1, 'double');
    dat.radius(i,1) = fread(fid, 1, 'double');
    dat.pos_x(i,1) = fread(fid, 1, 'double');
    dat.pos_y(i,1) = fread(fid, 1, 'double');
    dat.pos_z(i,1) = fread(fid, 1, 'double');
    dat.pos_m(i,1) = sqrt(dat.pos_x(i,1)^2 + dat.pos_y(i,1)^2 + dat.pos_z(i,1)^2 );
    dat.rot_0(i,1) = fread(fid, 1, 'double');
    dat.rot_1(i,1) = fread(fid, 1, 'double');
    dat.rot_2(i,1) = fread(fid, 1, 'double');
    dat.rot_3(i,1) = fread(fid, 1, 'double');
    dat.vel_x(i,1) = fread(fid, 1, 'double');
    dat.vel_y(i,1) = fread(fid, 1, 'double');
    dat.vel_z(i,1) = fread(fid, 1, 'double');
    dat.vel_m(i,1) = sqrt(dat.vel_x(i,1)^2 + dat.vel_y(i,1)^2 + dat.vel_z(i,1)^2 );
    dat.wvel_x(i,1) = fread(fid, 1, 'double');
    dat.wvel_y(i,1) = fread(fid, 1, 'double');
    dat.wvel_z(i,1) = fread(fid, 1, 'double');
    dat.wvel_m(i,1) = sqrt(dat.wvel_x(i,1)^2 + dat.wvel_y(i,1)^2 + dat.wvel_z(i,1)^2 );
    dat.acc_x(i,1) = fread(fid, 1, 'double');
    dat.acc_y(i,1) = fread(fid, 1, 'double');
    dat.acc_z(i,1) = fread(fid, 1, 'double');
    dat.acc_m(i,1) = sqrt(dat.acc_x(i,1)^2 + dat.acc_y(i,1)^2 + dat.acc_z(i,1)^2);
    dat.wacc_x(i,1) = fread(fid, 1, 'double');
    dat.wacc_y(i,1) = fread(fid, 1, 'double');
    dat.wacc_z(i,1) = fread(fid, 1, 'double');
    dat.wacc_m(i,1) = sqrt(dat.wacc_x(i,1)^2 + dat.wacc_y(i,1)^2 + dat.wacc_z(i,1)^2);
    dat.force_x(i,1) = fread(fid, 1, 'double');
    dat.force_y(i,1) = fread(fid, 1, 'double');
    dat.force_z(i,1) = fread(fid, 1, 'double');
    dat.force_m(i,1) = sqrt(dat.force_x(i,1)^2 + dat.force_y(i,1)^2 + dat.force_z(i,1)^2);
    dat.torque_x(i,1) = fread(fid, 1, 'double');
    dat.torque_y(i,1) = fread(fid, 1, 'double');
    dat.torque_z(i,1) = fread(fid, 1, 'double');
    dat.torque_m(i,1) = sqrt(dat.torque_x(i,1)^2 + dat.torque_y(i,1)^2 + dat.torque_z(i,1)^2);

    i = i+1;   
    body_id = fread(fid, 1, 'int64');
end

fclose(fid);
disp('Done importing data!');

% COnvert the data structure to a table
dat = struct2table(dat);

end
