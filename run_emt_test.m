function run_emt_test
% run_emt_test  Short 120-s electromagnetic transient test for GTES6000GZh
% Inserts a 100 ms three-phase fault to verify governor and AVR dynamics.

    mdl = 'GTES6000GZh';
    if ~exist([mdl '.slx'],'file')
        build_GT6000;
    end
    load_system(mdl);

    %% Configure EMT simulation -----------------------------------------
    set_param([mdl '/powergui'],'SimulationMode','Continuous');
    set_param(mdl,'Solver','ode23tb','StopTime','120');

    %% Insert three-phase fault at 5 s lasting 0.1 s -------------------
    if isempty(find_system(mdl,'Name','Fault'))
        delete_line(mdl,'Breaker/1','Grid/1');
        add_block('powerlib/Elements/Three-Phase Fault',[mdl '/Fault'], ...
            'Position',[600 120 660 200], ...
            'InitialStepTime','5', ...
            'FinalStepTime','5.1', ...
            'FaultResistance','0.001'); % assumed
        add_line(mdl,'Breaker/1','Fault/1');
        add_line(mdl,'Fault/1','Grid/1');
    end

    %% Input profiles ---------------------------------------------------
    t = linspace(0,120,12001)';
    Pref_ts = timeseries(6*ones(size(t)),t); % from spec 6 MW
    Brk_ts  = timeseries(ones(size(t)),t);
    assignin('base','Pref',Pref_ts);
    assignin('base','BrkCmd',Brk_ts);

    %% Run simulation ---------------------------------------------------
    simOut = sim(mdl);
    logs = simOut.logsout;

    %% Plot key signals ------------------------------------------------
    try
        pq = logs.get('PQMeas');
        P = pq.P.signals.values;
        Q = pq.Q.signals.values;
        figure; plot(simOut.tout,P); title('Active Power (MW)'); xlabel('s');
        figure; plot(simOut.tout,Q); title('Reactive Power (Mvar)'); xlabel('s');
    catch
    end

    try
        pm = logs.get('Pm');
        figure; plot(simOut.tout,pm.signals.values); title('Mechanical Power pu'); xlabel('s');
    catch
    end

    try
        vt = logs.get('Vt');
        figure; plot(simOut.tout,vt.signals.values); title('Terminal Voltage pu'); xlabel('s');
    catch
    end
end
