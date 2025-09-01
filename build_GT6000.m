function build_GT6000
% build_GT6000  Create Simulink model GTES6000GZh programmatically.
% The model represents a 6 MW GTES-6000-\u0413\u0416 gas-turbine generator
% using Simscape Electrical Specialized Power Systems.
% After execution, file GTES6000GZh.slx is saved.

    mdl = 'GTES6000GZh';
    if bdIsLoaded(mdl)
        close_system(mdl,0);
    end
    new_system(mdl); open_system(mdl);

    x0 = 30; y0 = 30; dx = 140; dy = 80;

    %% Powergui -------------------------------------------------------------
    add_block('powerlib/Elements/Powergui',[mdl '/powergui'], ...
        'Position',[x0 y0 x0+60 y0+40], ...
        'SimulationMode','Phasor', ...
        'SampleTime','60'); % from spec: 60 s for yearly run

    %% Control inputs -------------------------------------------------------
    add_block('built-in/Inport',[mdl '/Pref'], ...
        'Position',[x0-60 y0+dy+180 x0-30 y0+dy+200]);
    add_block('built-in/Inport',[mdl '/BrkCmd'], ...
        'Position',[x0+3*dx+180 y0+80 x0+3*dx+210 y0+100]);

    %% Synchronous Generator ------------------------------------------------
    add_block('powerlib/Machines/Synchronous Machine (pu Fundamental)', ...
        [mdl '/Generator'], ...
        'Position',[x0+dx y0 x0+dx+120 y0+160], ...
        'Sn','6e6', ...                   % from spec 6 MW
        'Vn','6300', ...                 % assumed 6.3 kV
        'fn','50', ...                   % from spec 50 Hz
        'Ra','0.003', ...                % assumed
        'Xd','1.8', ...                  % assumed
        'Xq','1.7', ...                  % assumed
        'Xdp','0.3', ...                 % assumed
        'Xddp','0.2', ...                % assumed
        'Xqqp','0.2', ...                % assumed
        'Tdp0','8', ...                  % assumed
        'Tddp0','0.03', ...              % assumed
        'Tqqp0','0.05');                 % assumed

    %% Gas Turbine + Governor (GGOV1) subsystem -----------------------------
    add_block('built-in/Subsystem',[mdl '/GT'], ...
        'Position',[x0 y0+dy+120 x0+200 y0+dy+300]);
    open_system([mdl '/GT']);
    add_block('built-in/Inport',[mdl '/GT/Pref'], 'Position',[30 40 60 60]);
    add_block('built-in/Inport',[mdl '/GT/Speed'], 'Position',[30 90 60 110]);
    add_block('built-in/S-Function',[mdl '/GT/GGOV1'], ...
        'Position',[120 40 200 110], ...
        'FunctionName','ggov1_sfunc', ...
        'Parameters','[0.04 0.5 0.05 0.5 0.3 1 0 0.1 6 1830 46.2 0.25]');
    add_block('built-in/Outport',[mdl '/GT/Pm'], 'Position',[260 40 290 60]);
    add_block('built-in/Outport',[mdl '/GT/FuelFlow'], 'Position',[260 80 290 100]);
    add_block('built-in/Outport',[mdl '/GT/HeatRate'], 'Position',[260 120 290 140]);
    add_block('built-in/Outport',[mdl '/GT/ExhaustFlow'], 'Position',[260 160 290 180]);
    add_line([mdl '/GT'],'Pref/1','GGOV1/1');
    add_line([mdl '/GT'],'Speed/1','GGOV1/2');
    add_line([mdl '/GT'],'GGOV1/1','Pm/1');
    add_line([mdl '/GT'],'GGOV1/2','FuelFlow/1');
    add_line([mdl '/GT'],'GGOV1/3','HeatRate/1');
    add_line([mdl '/GT'],'GGOV1/4','ExhaustFlow/1');
    close_system([mdl '/GT']);

    %% Excitation System and PSS -------------------------------------------
    add_block('powerlib/Extra/Excitation System IEEE Type 1', ...
        [mdl '/AVR'], 'Position',[x0+dx+160 y0-20 x0+dx+310 y0+120]);
    add_block('powerlib/Extra/Power System Stabilizer (PSS2B)', ...
        [mdl '/PSS'], 'Position',[x0+dx+160 y0+150 x0+dx+310 y0+250]);

    %% Transformer ----------------------------------------------------------
    add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
        [mdl '/GSU'], ...
        'Position',[x0+2*dx+200 y0 x0+2*dx+360 y0+160], ...
        'Sn','6.3e6', ...                 % from spec 6.3 MVA
        'V1','6300', ...                  % assumed LV voltage
        'V2','20000', ...                 % from spec HV voltage
        'Uk','7.5', ...                   % from spec uk=7.5%
        'Pcu','46500', ...                % from spec Pk=46.5 kW
        'Po','9250');                     % from spec P0=9.25 kW

    %% Measurements and Grid ------------------------------------------------
    add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
        [mdl '/VIMeas'], 'Position',[x0+2*dx+400 y0+40 x0+2*dx+450 y0+120]);
    add_block('powerlib/Measurements/Power Measurement', ...
        [mdl '/PQMeas'], 'Position',[x0+2*dx+400 y0+160 x0+2*dx+450 y0+240]);
    add_block('powerlib/Elements/Breaker',[mdl '/Breaker'], ...
        'Position',[x0+3*dx+240 y0+40 x0+3*dx+290 y0+120]);
    add_block('powerlib/Sources/Three-Phase Programmable Voltage Source', ...
        [mdl '/Grid'], 'Position',[x0+3*dx+330 y0 x0+3*dx+450 y0+160], ...
        'PhaseAngle','0','Vll','20000','Frequency','50'); % from spec

    %% Logging --------------------------------------------------------------
    add_block('simulink/Sinks/To Workspace',[mdl '/ToWorkspace'], ...
        'Position',[x0+3*dx+470 y0+200 x0+3*dx+520 y0+240], ...
        'VariableName','logsout','SaveFormat','Dataset');

    %% Connections ----------------------------------------------------------
    % Inputs
    add_line(mdl,'Pref/1','GT/1'); % Pref -> GGOV1
    add_line(mdl,'Generator/6','GT/2','autorouting','on'); % Speed -> GGOV1
    add_line(mdl,'BrkCmd/1','Breaker/2');
    % Mechanical power
    add_line(mdl,'GT/1','Generator/1');
    % AVR & PSS
    add_line(mdl,'Generator/5','AVR/1');
    add_line(mdl,'Generator/6','PSS/1','autorouting','on');
    add_line(mdl,'PSS/1','AVR/2');
    add_line(mdl,'AVR/1','Generator/2');
    % Electrical path
    add_line(mdl,'Generator/3','GSU/1');
    add_line(mdl,'GSU/2','VIMeas/1');
    add_line(mdl,'VIMeas/1','Breaker/1');
    add_line(mdl,'Breaker/1','Grid/1');
    add_line(mdl,'VIMeas/1','PQMeas/1');
    add_line(mdl,'PQMeas/1','ToWorkspace/1');

    %% Rename generator ports for clarity
    set_param([mdl '/Generator/1'],'Name','Pm');
    set_param([mdl '/Generator/2'],'Name','Vf');
    set_param([mdl '/Generator/3'],'Name','ABC');
    set_param([mdl '/Generator/5'],'Name','Vt');
    set_param([mdl '/Generator/6'],'Name','Speed');

    save_system(mdl); close_system(mdl);
end
