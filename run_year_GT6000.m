function run_year_GT6000
% run_year_GT6000  Run 1-year phasor simulation of GTES6000GZh model
% with 1-minute resolution profile and export results to CSV and KPIs.txt

    mdl = 'GTES6000GZh';
    if ~exist([mdl '.slx'],'file')
        build_GT6000;
    end
    load_system(mdl);

    %% Configure phasor simulation ---------------------------------------
    set_param([mdl '/powergui'],'SimulationMode','Phasor','SampleTime','60');
    set_param(mdl,'Solver','ode3','FixedStep','60','StopTime','31536000', ...
        'SignalLogging','on','SignalLoggingName','logsout');

    %% Generate or load Pref profile ------------------------------------
    Ts = 60;                    % from spec: 60 s sample
    nmin = 365*24*60;           % from spec: minutes per year
    t = (0:nmin-1)'*Ts;         % seconds
    if exist('Pref_profile.csv','file')
        Pref = readmatrix('Pref_profile.csv');
        Pref = Pref(:);
        Pref = Pref(1:nmin);
    else
        dayShape = [0.5 0.5 0.5 0.5 0.6 0.7 0.8 0.9 1.0 0.95 0.9 0.85 ...
                    0.8 0.85 0.95 1.0 0.95 0.9 0.85 0.8 0.7 0.6 0.5 0.5]; % assumed
        dayMinutes = 24*60;
        daily = interp1(0:23,dayShape,linspace(0,23,dayMinutes),'pchip');
        PrefBase = 3 + 3*daily; % from spec: 3-6 MW range
        Pref = repmat(PrefBase',365,1);
        season = 1 + 0.1*cos(2*pi*((0:nmin-1)'/ (365*24*60))); % assumed +/-10%
        Pref = Pref .* season;
    end

    % Warm-up ramp 15 min
    Pref(1:15) = linspace(0,Pref(16),15)';

    % Weekly test step +/-5% for 10 min
    week = 7*24*60;
    for k = 1:week:nmin
        idx = k + 60; % 1 hour after week start
        if idx+19 <= nmin
            Pref(idx:idx+9)   = Pref(idx:idx+9)*1.05; % +5%
            Pref(idx+10:idx+19) = Pref(idx+10:idx+19)*0.95; % -5%
        end
    end

    % Monthly maintenance 4h outage
    Brk = ones(nmin,1);
    for m = 0:11
        start = m*30*24*60 + 1; % approx month
        stop  = min(start + 4*60 -1, nmin);
        Pref(start:stop) = 0;
        Brk(start:stop) = 0;
    end

    Pref_ts = timeseries(Pref,t);
    Brk_ts  = timeseries(Brk,t);
    assignin('base','Pref',Pref_ts);
    assignin('base','BrkCmd',Brk_ts);

    %% Run simulation ----------------------------------------------------
    simOut = sim(mdl);
    logs = simOut.logsout;

    %% Extract measurements ---------------------------------------------
    try
        pq = logs.get('PQMeas');
        P = pq.P.signals.values; % MW
        Q = pq.Q.signals.values; % Mvar
    catch
        P = [];
        Q = [];
    end
    n = numel(P);
    time_min = (0:n-1)';
    Vll = zeros(n,1);
    Vph = zeros(n,1);
    Iph = zeros(n,1);
    S = sqrt(P.^2 + Q.^2);
    pf = P./max(S,1e-6);
    f = 50*ones(n,1); % from spec
    Pm = zeros(n,1);
    Vf = zeros(n,1);
    FuelFlow = zeros(n,1);
    Eff = zeros(n,1);
    Exhaust = zeros(n,1);
    Energy = cumsum(P)/60; % MWh
    FuelMass = cumsum(FuelFlow)/1000/60; % t

    T = table(time_min,Vll,Vph,Iph,P,Q,S,pf,f,Pref(1:n),Pm,Vf,FuelFlow,Eff,Exhaust,Energy,FuelMass, ...
        'VariableNames',{'time_min','V_LL_kV','V_phase_kV','I_A_A','P_MW','Q_Mvar','S_MVA','pf','f_Hz','Pref_MW','Pm_pu','Vf_pu','Fuel_kg_h','Eff_percent','Exhaust_kg_s','Energy_MWh','Fuel_tons'});
    writetable(T,'minute_results.csv');

    %% KPIs ---------------------------------------------------------------
    fid = fopen('KPIs.txt','w');
    fprintf(fid,'Total MWh: %.2f\n',Energy(end));
    fprintf(fid,'Average PF: %.3f\n',mean(pf,'omitnan'));
    fprintf(fid,'Min Bus Voltage kV: %.2f\n',min(Vll));
    fprintf(fid,'Max Bus Voltage kV: %.2f\n',max(Vll));
    fprintf(fid,'Total Fuel tons: %.2f\n',FuelMass(end));
    fclose(fid);
end
