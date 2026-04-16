function [ac] = AircraftConfig()
% AIRCRAFTCONFIG  Define all aircraft-specific parameters for high-lift sizing.
%
%   ac = AircraftConfig()
%
%   Returns a struct with sub-structs:
%     ac.wing      — Planform: AR, sweep, span sections, aileron
%     ac.airfoils  — Per-section cl_alpha, cl_max, thickness ratio
%     ac.weights   — WTO, WLD
%     ac.atmo      — Air density
%     ac.flap      — Flap chord ratio, design index
%     ac.slat      — Slat chord ratio, design index
%     ac.aoa       — Takeoff/landing angles of attack
%     ac.files     — File paths for OpenVSP data
%     ac.spdcnst   — Takeoff and Landing speed upper limit

    %% Wing Planform
    wing.AR         = 15;
    wing.Lambda_c4  = 31.0;                          % quarter-chord sweep [deg]
    wing.sectionSpans = [6.35, 6.49, 12.98, 19.47, 19.47, 6.49];  % ft, per section
    wing.aileronSpan  = 0.15;                        % fraction of semispan

    ac.wing = wing;

    %% Airfoil Properties (per wing section, inboard to outboard)
    %  Sections: 0612, 0612, 0612, 0610, 0606, 0404
    airfoils.names   = {'0612','0612','0612','0610','0606','0404'};
    airfoils.tc_pct  = [12, 12, 12, 10, 6, 4];      % thickness ratio [%]

    airfoils.clAlpha = [2*pi; 2*pi; 2*pi; 2*pi; 2*pi; 2*pi];  % per rad
    airfoils.clMax   = [1.6581; 1.6581; 1.6581; 1.5252; 0.9342; 0.8204];

    ac.airfoils = airfoils;

    %% Weights
    weights.WTO = 163800;                            % lb
    weights.WLD = 163800 - (0.9 * 31600);            % lb (WTO - 90% fuel)

    ac.weights = weights;

    %% Atmosphere
    atmo.density = 0.002378;                         % slug/ft^3, sea level std

    ac.atmo = atmo;

    %% High-Lift Device Chord Ratios
    %  Indices into the Roskam figure interpolation tables
    flap.cfOverC      = 0.25;
    flap.fig817_index = 3;       % row index into fig817.cfOverC = [0.15,0.20,0.25,0.30,0.40]

    slat.cfOverC      = 0.10;
    slat.fig826_index = 11;      % index into 0.00:0.01:0.50 interpolated table

    ac.flap = flap;
    ac.slat = slat;

    %% Angles of Attack - Ran for lift cure slope
    aoa.takeoff = 10;   % deg
    aoa.landing = 5;    % deg

    ac.aoa = aoa;

    %% Takeoff and Landing Velocity Constraints - Limiting Factor

    spdcnst.VLOFcnst = 170; % kts (knots)
    spdcnst.VAPPcnst = 170; % kts (knots)

    ac.spdcnst = spdcnst;

    %% File Paths
    files.directory   = "./test/";
    files.aeroFile    = "BAAT4_polar.csv";
    files.degenFile   = "BAAT3_FuselageWingChanged_DegenGeom.csv";
    files.wingCompName = "Aero New Main";

    ac.files = files;

    %% Validation
    nSections = length(wing.sectionSpans);
    assert(length(airfoils.clAlpha) == nSections, ...
        'clAlpha length (%d) must match number of wing sections (%d).', ...
        length(airfoils.clAlpha), nSections);
    assert(length(airfoils.clMax) == nSections, ...
        'clMax length (%d) must match number of wing sections (%d).', ...
        length(airfoils.clMax), nSections);

end
