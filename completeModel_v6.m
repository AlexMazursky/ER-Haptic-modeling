%% Model of Predicted Force vs. Depth plots
% Written by: Alex J. Mazursky
%             Master's student
%             Miami University
%             June, 2018
% This script has been written as a method of modeling a haptic actuator
% based on ER fluid in flow mode.

%% Clean-up
close all
clear all
clc
%% Import Experimental Data and Assign Vectors
[dry_run] = xlsread('ER_DryRun_1mms_051117');
[DC_0kV] = xlsread('ER_0kV_DC_042017.xlsx');
[DC_1kV] = xlsread('ER_1kV_DC_042017.xlsx');
[DC_2kV] = xlsread('ER_2kV_DC_042017.xlsx');
[DC_3kV] = xlsread('ER_3kV_DC_042017.xlsx');

Depth_dry_run = -dry_run(1:102,2);
Force_dry_run = -dry_run(1:102,3)/101.971621; % (N)
% plot(Depth_dry_run, Force_dry_run)
Depth_DC_0kV = -DC_0kV(1:102,2);
Force_DC_0kV = -DC_0kV(1:102,3)/101.971621; % (N)
Depth_DC_1kV = -DC_1kV(1:102,2);
Force_DC_1kV = -DC_1kV(1:102,3)/101.971621; % (N)
Depth_DC_2kV = -DC_2kV(1:102,2);
Force_DC_2kV = -DC_2kV(1:102,3)/101.971621; % (N)
Depth_DC_3kV = -DC_3kV(1:102,2);
Force_DC_3kV = -DC_3kV(1:102,3)/101.971621; % (N)
%% Excitation Parameters
Freq = 3; % (Hz) Applied Frequency
waveform = 1; % 0 for DC, 1 for sin, 2 for square
V_max = linspace(0, 3000, 4)'; % (V) Max Applied Voltage
%% Indentation Parameters
% Time Frame ------------------------------------------
t0 = 0; % (s) Starting Time
tf = 1; % (s) Final Time
t_pts = 5001; % Time Resolution
t = linspace(t0, tf, t_pts)'; % Time Vector
% Depth & Velocity ------------------------------------
V_p = 1; % (mm/s) Indentation Rate
d_p = V_p*tf; % (mm) Final Depth
d_pts = t_pts; % Sample at same time and depth intervals
d = linspace(0, d_p, d_pts)'; % Depth Vector

%% Device Parameters
% Gap Size and Field Strength -------------------------
h = 1; % (mm) Gap Size
E_mag = (V_max/2)/h; % (V/mm)
DC_offset = E_mag; % (V/mm)
% Electrode Geometry ----------------------------------
r_OUT = 12; % (mm) Outer Radius
r_IN = 7.5; % (mm) Inner Radius
c_OUT = 0.75; % Effectiveness Constant
c_IN = 1.25; % Effectiveness Constant
r1 = c_OUT*r_OUT; % (mm) Effective Outer Radius
r0 = c_IN*r_IN; % (mm) Effective Inner Radius
L = r1-r0; % (mm) Electrode "Length"
% r_avg = (r0+r1)/2; % {rough idea}
% b = 2*pi*r_avg; % (mm) Electrode "Width"
% Piston Geometry -------------------------------------
rp0 = 0; % (mm) Initial Radius
rpf = 5; % (mm) Final Radius
% Membrane Parameters ---------------------------------
p1 = 0.29401; % Coefficients of the quadratic curve fit to experiment
p2 = 0.21655;

%% GER Fluid Properties
mu = 0.06; % (Pa*sec) Viscosity from SML, Hong Kong
% Shear stress, tau_y, is a function of applied electric field. This model
% uses Hyoung J. Choi's model to relate the two. 
Ec = 2000; % (V) Critical Electric Field 
        % (Junction between polarization and conductivity models)
% kb = 0.69503476; % (1/cm*K) Boltzmann Constant
% T = 300; % (K) Operating Temperature
% m = ?;
alpha = 0.010; % m^2/(3*kb*T) % alpha parameter, a measure of Polarizability
        % depends on the dielectric constant of the fluid, 
        % the particle volume fraction, and beta
res_time = 3; % (ms) Response time
res_time_SI = res_time/1000; % (sec)
        
%% ER Fluid Curve
E = linspace(0,5000,101)'; % (kV)
% pre-allocate
Ty = zeros(length(E),1);
Er = zeros(length(E),1);
for k = 1:length(E)
    Er(k,1) = E(k,1)/Ec; % ratio of applied to critical
    Ty(k,1) = (alpha*E(k,1)^2*besseli(1,Er(k,1)))/(Er(k,1)*besseli(0,Er(k,1))); % (Pa) Vemuri Model
end
figure('Name','ER Curve','NumberTitle','off', 'pos',[10 10 800 600])
plot(E, Ty, 'LineWidth', 2.5)
title('Stress as Function of Electric Field Strength','interpreter','latex')
%% Plot Settings
xlabel('Electric Field Strength (kV/mm)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'$\tau_y$ (Pa)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%print('ER_Curve','-depsc')
%% Indentation Loop
% Preallocate vectors
r_p = zeros(length(d),1);
A_p = zeros(length(d),1);
A_p_SI = zeros(length(d),1);
Q_p = zeros(length(d),1);
vol_p = zeros(length(d),1);
F_Fluid_me = zeros(length(d),length(E_mag));
F_Membrane_center = zeros(length(d),1);
F_Membrane_outer = zeros(length(d),1);
F_tot_me = zeros(length(d),length(E_mag));
E = zeros(length(d),length(E_mag));

for j = 1:length(E_mag) % Loops through applied voltage magnitudes
for i = 1:length(d) % loops through the indentation positions
    % Describes radius of piston as function of depth
    r_p(i,1) = (d(i,1)./d(end,1)).*(rpf-rp0)+rp0; % (mm)
    % Describes area of piston as function of depth
    A_p(i,1) = pi.*r_p(i,1)^2; % (mm^2)
    % Volume flow calculation
    Q_p(i,1) = V_p.*A_p(i,1); % (mm^3/s)
    % Total displaced volume calculation
    vol_p(i,1) = Q_p(i,1).*t(i,1); % (mm^3)
    
    % Handles the NaN at (0,0)
    if E_mag(j,1) == 0
        Ty = 0;
    else
        % Frequency
        if waveform == 0 % DC
            E(i,j) = abs(E_mag(j,1)+DC_offset(j,1));
        elseif waveform == 1 % SIN
            E(i,j) = abs(E_mag(j,1)*cos(2*pi*Freq*d(i,1)+res_time_SI)+DC_offset(j,1));
        elseif waveform == 2 % SQ
            E(i,j) = abs(E_mag(j,1)*square(2*pi*Freq*d(i,1)+res_time_SI)+DC_offset(j,1)); % [WORK IN PROGRESS]
        end
        Er = E(i,j)/Ec; % Ratio of applied to critical
        Ty = (alpha*E(i,j)^2*besseli(1,Er))/(Er*besseli(0,Er)); % (Pa) Vemuri Model
    end
    
    % Unit Corrections to SI
    A_p_SI(i,1) = A_p(i,1)*10^-6; % (m^2, from mm^2)
    Ty_SI = Ty; % (Pa, from kPa)
    V_p_SI = V_p*10^-3; % (m/s, from mm/s)
    % mu already in SI (Pa*s)
    r0_SI = r0*10^-3; % (m, from mm)
    r1_SI = r1*10^-3; % (m, from mm)
    h_SI = h*10^-3; % (m, from mm)
    
    % Pressure Drop (Pa)
    dP_me = ((2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)^3/(h_SI^9*pi^3) + (2*Ty_SI^3*(r0_SI - r1_SI)^3)/h_SI^3 + (2*2^(1/2)*A_p_SI(i,1)^(1/2)*Ty_SI^(3/2)*V_p_SI^(1/2)*mu^(1/2)*(r0_SI - r1_SI)^(3/2)*(4*A_p_SI(i,1)^2*V_p_SI^2*mu^2 - 6*pi*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r0_SI + 6*pi*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r1_SI + 3*pi^2*Ty_SI^2*h_SI^4*r0_SI^2 - 6*pi^2*Ty_SI^2*h_SI^4*r0_SI*r1_SI + 3*pi^2*Ty_SI^2*h_SI^4*r1_SI^2)^(1/2))/(h_SI^6*pi^(3/2)))^(1/3) + (2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)/(h_SI^3*pi) + (2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)^2/(h_SI^6*pi^2*((2*A_p_SI(i,1)*V_p_SI*mu - Ty_SI*h_SI^2*r0_SI*pi + Ty_SI*h_SI^2*r1_SI*pi)^3/(h_SI^9*pi^3) + (2*Ty_SI^3*(r0_SI - r1_SI)^3)/h_SI^3 + (2*2^(1/2)*A_p_SI(i,1)^(1/2)*Ty_SI^(3/2)*V_p_SI^(1/2)*mu^(1/2)*(r0_SI - r1_SI)^(3/2)*(4*A_p_SI(i,1)^2*V_p_SI^2*mu^2 + 3*Ty_SI^2*h_SI^4*r0_SI^2*pi^2 + 3*Ty_SI^2*h_SI^4*r1_SI^2*pi^2 - 6*Ty_SI^2*h_SI^4*r0_SI*r1_SI*pi^2 - 6*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r0_SI*pi + 6*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r1_SI*pi)^(1/2))/(h_SI^6*pi^(3/2)))^(1/3));
    %((2*2^(1/2)*((A_p_SI(i,1)*Ty_SI^3*V_p_SI*mu*(r0_SI - r1_SI)^3*(4*A_p_SI(i,1)^2*V_p_SI^2*mu^2 - 6*pi*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r0_SI + 6*pi*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r1_SI + 3*pi^2*Ty_SI^2*h_SI^4*r0_SI^2 - 6*pi^2*Ty_SI^2*h_SI^4*r0_SI*r1_SI + 3*pi^2*Ty_SI^2*h_SI^4*r1_SI^2))/h_SI^12)^(1/2))/pi^(3/2) + (2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)^3/(h_SI^9*pi^3) + (2*Ty_SI^3*(r0_SI - r1_SI)^3)/h_SI^3)^(1/3) + (2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)/(h_SI^3*pi) + (2*A_p_SI(i,1)*V_p_SI*mu - pi*Ty_SI*h_SI^2*r0_SI + pi*Ty_SI*h_SI^2*r1_SI)^2/(h_SI^6*pi^2*((2*2^(1/2)*((A_p_SI(i,1)*Ty_SI^3*V_p_SI*mu*(r0_SI - r1_SI)^3*(4*A_p_SI(i,1)^2*V_p_SI^2*mu^2 + 3*Ty_SI^2*h_SI^4*r0_SI^2*pi^2 + 3*Ty_SI^2*h_SI^4*r1_SI^2*pi^2 - 6*Ty_SI^2*h_SI^4*r0_SI*r1_SI*pi^2 - 6*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r0_SI*pi + 6*A_p_SI(i,1)*Ty_SI*V_p_SI*h_SI^2*mu*r1_SI*pi))/h_SI^12)^(1/2))/pi^(3/2) + (2*A_p_SI(i,1)*V_p_SI*mu - Ty_SI*h_SI^2*r0_SI*pi + Ty_SI*h_SI^2*r1_SI*pi)^3/(h_SI^9*pi^3) + (2*Ty_SI^3*(r0_SI - r1_SI)^3)/h_SI^3)^(1/3));
    %dP_coulter = (8*mu*Q_p(i,1)*L)/(b*h^3)+2*(L/h)*Ty;
    
    % Force due to Fluid Estimate
    F_Fluid_me(i,j) = dP_me*A_p_SI(i,1); % (Pa*m^2) = (N)
    %F_Fluid_coulter(i,j) = dP_coulter*A_p(i,1)*10^-6; % (Pa*mm^2*1E-6) = (N)
    
    % Force due to Membrane
    if j == 1
    F_Membrane_center(i,1) = p1*d(i,1)^2 + p2*d(i,1);
    F_Membrane_outer(i,1) = 3.1*p1*d(i,1)^2;
    end
    
    % Total Force (N)
    F_tot_me(i,j) = F_Fluid_me(i,j)+F_Membrane_center(i,1)+F_Membrane_outer(i,1);
end
end
%plot(d,F_tot_me(:,1),Depth_DC_0kV,Force_DC_0kV)
%% Post-Processing
%% Applied Signal
figure('Name','Applied Signal','NumberTitle','off', 'pos',[10 10 800 600])
plot(t, E, 'LineWidth', 2)
title('Applied Voltage','interpreter','latex')
%% Flow Profiles
figure('Name','Fluid Flow','NumberTitle','off', 'pos',[10 10 800 600])
subplot(2,1,1)
plot(t, Q_p, 'LineWidth', 2)
title('Volumetric Flow Rate','interpreter','latex')
%%
xlabel('Time (s)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'Volumetric flow rate (mm$^3$/s)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%%
subplot(2,1,2)
plot(t, vol_p, 'LineWidth', 2)
title('Volume Displaced','interpreter','latex')
%%
xlabel('Time (s)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'Volume Displaced (mm$^3$)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%print('Flow_Curves','-depsc')
%% Force Due to Fluid
figure('Name','Force Profiles','NumberTitle','off', 'pos',[10 10 800 600])
subplot(2,1,1)
plot(d, F_Fluid_me(:,1),'b', ...
    Depth_DC_0kV,Force_DC_0kV-Force_dry_run, 'r', ...
    d, F_Fluid_me(:,2), 'b--', ...
    Depth_DC_1kV,Force_DC_1kV-Force_dry_run, 'r--',...
    d, F_Fluid_me(:,3), 'b-.',...
    Depth_DC_2kV,Force_DC_2kV-Force_dry_run, 'r-.',...
    d, F_Fluid_me(:,4), 'b:',...
    Depth_DC_3kV,Force_DC_3kV-Force_dry_run, 'r:',...
    'LineWidth', 2.5)
title('Force due to fluid','interpreter','latex')
l1 = legend('0 kV/mm (Model)', '0 kV/mm (Exp)',...
            '1 kV/mm (Model)', '1 kV/mm (Exp)',...
            '2 kV/mm (Model)', '2 kV/mm (Exp)',...
            '3 kV/mm (Model)', '3 kV/mm (Exp)',...
            'Location', 'NorthWest');
set([l1, gca]             , ...
    'FontSize'   , 16           );
%%
xlabel('Depth (mm)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'Force (N)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%% Force Due to Membrane
subplot(2,1,2)
plot(d, F_Membrane_center, 'b', ...
    Depth_dry_run, Force_dry_run, 'r', ...
    'LineWidth', 2)
title('Force due to membrane','interpreter','latex')
l1 = legend('Model', 'Experiment',...
    'Location', 'NorthWest');
set([l1, gca]             , ...
    'FontSize'   , 16           );
axis([0 1 0 0.6]);
%%
xlabel('Depth (mm)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'Force (N)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%print('Force_Components', '-depsc')
%% Total Force
% figure('Name','Total Force','NumberTitle','off', 'pos',[10 10 800 600])
% plot(d, F_tot_me,'LineWidth', 2.5)
% title('Total Force', 'interpreter','latex')
% l1 = legend('0 kV/mm','1 kV/mm','2 kV/mm','3 kV/mm',...
%     'Location', 'NorthWest');
% set([l1, gca]             , ...
%     'FontSize'   , 16           );
% %%
% xlabel('Depth (mm)',...
% 'FontUnits','points',...
% 'interpreter','latex',...
% 'FontWeight','normal',...
% 'FontSize',16,...
% 'FontName','Times')
% ylabel({'Force (N)'},...
% 'FontUnits','points',...
% 'interpreter','latex',...
% 'FontWeight','normal',...
% 'FontSize',16,...
% 'FontName','Times')
% set(gca, ...
%   'FontName','Times',...
%   'FontSize'    , 16, ...
%   'Box'         , 'off'     , ...
%   'TickDir'     , 'out'     , ...
%   'XMinorTick'  , 'on'      , ...
%   'YMinorTick'  , 'on'      , ...
%   'YGrid'       , 'on'      , ...
%   'LineWidth'   , 1         );
%% Overlay Model Data w/ Experimental Data from 04/20/2017
figure('Name','Theoretical vs. Experimental Results','NumberTitle','off', 'pos',[10 10 800 600])
plot(d, F_tot_me(:,1),'b', ...
    Depth_DC_0kV,Force_DC_0kV, 'r', ...
    d, F_tot_me(:,2), 'b--', ...
    Depth_DC_1kV,Force_DC_1kV, 'r--',...
    d, F_tot_me(:,3), 'b-.',...
    Depth_DC_2kV,Force_DC_2kV, 'r-.',...
    d, F_tot_me(:,4), 'b:',...
    Depth_DC_3kV,Force_DC_3kV, 'r:',...
    'LineWidth', 2.5)
axis([0 1 0 2.75]);
title('Modeled vs. Experimental Force vs. Depth Plots', 'interpreter','latex')
l1 = legend('0 kV/mm (Model)', '0 kV/mm (Exp)',...
            '1 kV/mm (Model)', '1 kV/mm (Exp)',...
            '2 kV/mm (Model)', '2 kV/mm (Exp)',...
            '3 kV/mm (Model)', '3 kV/mm (Exp)',...
            'Location', 'NorthWest');
set([l1, gca]             , ...
    'FontSize'   , 16           );
xlabel('Depth (mm)',...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
ylabel({'Force (N)'},...
'FontUnits','points',...
'interpreter','latex',...
'FontWeight','normal',...
'FontSize',16,...
'FontName','Times')
set(gca, ...
  'FontName','Times',...
  'FontSize'    , 16, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'LineWidth'   , 1         );
%print('Total_Force', '-depsc')