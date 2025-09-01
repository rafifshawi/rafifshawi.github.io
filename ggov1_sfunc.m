function ggov1_sfunc(block)
% ggov1_sfunc  Level-2 MATLAB S-function implementing a simplified
% IEEE GGOV1 gas-turbine governor and turbine model.
% Inputs:
%   u(1) - Pref in MW
%   u(2) - Speed in pu (1.0 at 50 Hz)
% Outputs:
%   y(1) - Pm in pu
%   y(2) - FuelFlow kg/h
%   y(3) - HeatRate kJ/kWh
%   y(4) - ExhaustFlow kg/s
%
% Parameters (all "assumed" unless noted):
%   R        droop (pu)                     (assumed 0.04 -> 4%)
%   T1       governor lead time constant s  (assumed 0.5)
%   T2       governor lag time constant s   (assumed 0.05)
%   T3       fuel system time constant s    (assumed 0.5)
%   T4       turbine lag time constant s    (assumed 0.3)
%   Vmax     valve upper limit pu           (assumed 1.0)
%   Vmin     valve lower limit pu           (assumed 0.0)
%   Rate     valve rate limit pu/s          (assumed 0.1)
%   Pbase    base power MW                  (from spec 6)
%   FuelNom  nominal fuel flow kg/h         (from spec 1830 kg/h gas)
%   ExhaustNom nominal exhaust kg/s         (from spec 46.2 kg/s)
%   Eff_elec electrical efficiency          (from spec 0.25)
%
% This implementation is simplified and intended for demonstration.

setup(block);

function setup(block)
    block.NumInputPorts  = 2;
    block.NumOutputPorts = 4;
    block.NumContStates  = 3;  % governor, fuel, turbine states
    block.NumDialogPrms  = 12;
    block.SampleTimes    = [0 0];

    block.SetPreCompPortInfoToDefaults;
    block.SimStateCompliance = 'DefaultSimState';

    block.InputPort(1).DirectFeedthrough = true;
    block.InputPort(2).DirectFeedthrough = true;

    block.RegBlockMethod('InitializeConditions', @InitConditions);
    block.RegBlockMethod('Derivatives',           @Derivatives);
    block.RegBlockMethod('Outputs',               @Outputs);
end

function InitConditions(block)
    block.ContStates.Data = zeros(3,1);
end

function Derivatives(block)
    Pref = block.InputPort(1).Data; % MW
    Speed = block.InputPort(2).Data; % pu

    R   = block.DialogPrm(1).Data;
    T1  = block.DialogPrm(2).Data;
    T2  = block.DialogPrm(3).Data;
    T3  = block.DialogPrm(4).Data;
    T4  = block.DialogPrm(5).Data;
    Vmax = block.DialogPrm(6).Data;
    Vmin = block.DialogPrm(7).Data;
    Rate = block.DialogPrm(8).Data;
    Pbase = block.DialogPrm(9).Data;
    % states
    x1 = block.ContStates.Data(1); % governor state
    x2 = block.ContStates.Data(2); % fuel system
    x3 = block.ContStates.Data(3); % turbine output

    % Speed error with droop
    werr = (Pref/Pbase - Speed)/R;

    % Governor lead-lag
    vg = (werr - x1)/T1;

    % Apply valve limits and rate limit
    v = x1 + vg*T1;
    v = max(min(v,Vmax),Vmin);
    % rate limit
    if vg > Rate
        vg = Rate;
    elseif vg < -Rate
        vg = -Rate;
    end

    % Fuel system
    vf = (v - x2)/T2;

    % Turbine
    vt = (x2 - x3)/T3;

    block.Derivatives.Data = [vg; vf; vt];
end

function Outputs(block)
    x3 = block.ContStates.Data(3); % turbine mechanical power pu
    Pref = block.InputPort(1).Data; %#ok<NASGU>
    Pbase = block.DialogPrm(9).Data; % MW
    FuelNom = block.DialogPrm(10).Data; % kg/h at rated
    ExhaustNom = block.DialogPrm(11).Data; % kg/s at rated
    Eff = block.DialogPrm(12).Data; % electrical efficiency

    Pm_pu = x3; % mechanical power pu
    FuelFlow = FuelNom * Pm_pu; % kg/h
    HeatRate = (FuelFlow*50e3)/(Pm_pu*Pbase*1e3); % kJ/kWh, assuming 50 MJ/kg fuel
    ExhaustFlow = ExhaustNom * Pm_pu; % kg/s

    block.OutputPort(1).Data = Pm_pu;
    block.OutputPort(2).Data = FuelFlow;
    block.OutputPort(3).Data = HeatRate;
    block.OutputPort(4).Data = ExhaustFlow;
end
