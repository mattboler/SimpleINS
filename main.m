clc; clear all; close all;

DATASET_FOLDER = '/disks/storage/Datasets/Navigation/Kitti_RAW/synced/2011_09_26/2011_09_26_drive_0001_sync/';

%% Assemble Filter Parameters
%{
Orientation is defined as q_b_n
Position is defined as p_b_n
Velocity is defined as v_b_n
%}

dt = 0.1;

% Noise Parameters for State Propagation
velocity_noise_sigma = 2 * ones(1,3);
orientation_noise_sigma = 2 * ones(1,3);
accel_bias_noise_sigma = 0.01 * ones(1,3);
gyro_bias_noise_sigma = 0.01 * ones(1,3);

imu_Q = dt^2 * diag([velocity_noise_sigma, orientation_noise_sigma, accel_bias_noise_sigma, gyro_bias_noise_sigma]).^2;

% Initial State
position = [0 0 0]';
velocity = [13.17 0 0]';
q_b_n = [1 0 0 0]';
accel_bias = [0 0 0]';
gyro_bias = [0 0 0]';

% Initial State Covariance (corresponds to error states, not nominal
% states)
p_sigma = 1e-3 * ones(1,3);
v_sigma = 1e-3 * ones(1,3);
theta_sigma = 1e-3 * ones(1,3);
accel_bias_sigma = 1e-3 * ones(1,3);
gyro_bias_sigma = 1e-3 * ones(1,3);

imu_P = diag([p_sigma, v_sigma, theta_sigma, accel_bias_sigma, gyro_bias_sigma]).^2;

% Error States
delta_position = [0 0 0]';
delta_velocity = [0 0 0]';
delta_theta = [0 0 0]';
delta_accel_bias = [0 0 0]';
delta_gyro_bias = [0 0 0]';

% Data Storage
positions = [];
orientations = [];



%% Collect IMU Data
imu_folder = [DATASET_FOLDER 'oxts' filesep 'data' filesep];
imu_filenames_struct = dir(fullfile(imu_folder, '*.txt'));
imu_filenames_cell_arr = cell(numel(imu_filenames_struct), 1);
imu_filenames_cell_arr = {};
for i = 1:numel(imu_filenames_struct)
    imu_filenames_cell_arr{i} = fullfile(imu_folder, imu_filenames_struct(i).name);
end
imu_filenames = sort(string(imu_filenames_cell_arr));

% Build imu measurements
imu_measurements = cell(length(imu_filenames),1);
for i = 1:length(imu_filenames)
    FID = fopen(imu_filenames(i));
    data = textscan(FID, '%s');
    data = str2double(string(data{:}));
    fclose(FID);
    
    gyro = data(18:20);
    accel = data(12:14);
    temp_measurement.gyro = gyro;
    temp_measurement.accel = accel;
    imu_measurements{i} = temp_measurement;
end

% Utilities
Z = zeros(3,3);
I = eye(3);
G = [0; 0; -9.81];

positions(1,:) = position';
velocities(1,:) = velocity';

for i = 1:numel(imu_measurements)
    measurement = imu_measurements{i};
    
    accel = measurement.accel;
    gyro = measurement.gyro;
    
    % Propagate Nominal State
    R = quatToDCM(q_b_n);
    
    position = position + dt * velocity + (1/2) * (R * (accel - accel_bias) + G)*dt^2;
    velocity = velocity + dt * ( R * (accel - accel_bias) + G);
    
    q_gyro = gyroToQuat(gyro - gyro_bias, dt);
    q_b_n = quatMult(q_b_n, q_gyro);
    q_b_n = q_b_n ./ norm(q_b_n);
    
    accel_bias = accel_bias;
    gyro_bias = gyro_bias;
    
    
    % Prediction Step

    % Partial F / partial err
    F_x = zeros(15,15);
    F_x(1:3, 1:3) = I;
    F_x(1:3, 4:6) = I * dt;
    
    F_x(4:6, 4:6) = I;
    F_x(4:6, 7:9) = -R * skew(accel - accel_bias) * dt;
    F_x(4:6, 10:12) = -R * dt;
    
    F_x(7:9, 7:9) = quatToDCM(q_gyro)';
    F_x(7:9, 13:15) = -I*dt;
    
    F_x(10:12, 10:12) = I;
    
    F_x(13:15, 13:15) = I;
    
    % Partial F / partial i
    F_i = zeros(15, 12);
    
    F_i(4:6, 1:3) = I;
    F_i(7:9, 4:6) = I;
    F_i(10:12, 7:9) = I;
    F_i(13:15, 10:12) = I;
    
    imu_P = F_x * imu_P * F_x' + F_i * imu_Q * F_i';
    
    positions(i+1,:) = position';
    velocities(i+1,:) = velocity';

end
