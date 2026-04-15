%% High-Lift System Sizing Script
% Fowler Flap (Eq. 8.6) + Leading Edge Slats (Eq. 8.15)
% Modified Roskam Part VI methodology

clc; clear; close all

%% Emperical Data - Figure 8.53 - Flap Effectiveness with AR + cf/c Eq 8.27

alphaDeltacf = [0.00, 0.20, 0.40, 0.55, 0.60, 0.75, 0.80, 0.90, 0.95, 1.00];
cfOverCratio = [0.00, 0.05, 0.10, 0.20, 0.25, 0.40, 0.45, 0.60, 0.80, 1.00];

% cf/c = 0.1
AR01 = [1.416, 1.645, 2.014, 2.400, 2.892, 3.628, 4.766, 6.516, 8.020, 9.996];
alphaDeltaRatio01 = [2.000, 1.903, 1.802, 1.700, 1.603, 1.501, 1.404, 1.305, 1.250, 1.203];

% cf/c = 0.2
AR02 = [0.577, 0.701, 0.843, 1.107, 1.493, 2.002, 2.755, 3.998, 6.010, 8.022, 10.015];
alphaDeltaRatio02 = [2.000, 1.903, 1.802, 1.702, 1.601, 1.501, 1.405, 1.302, 1.201, 1.158, 1.138];

% cf/c = 0.3
AR03 = [0.280, 0.316, 0.406, 0.530, 0.759, 1.110, 1.654, 2.565, 4.000, 6.029, 8.023, 10.016];
alphaDeltaRatio03 = [2.000, 1.901, 1.797, 1.700, 1.600, 1.501, 1.402, 1.302, 1.203, 1.145, 1.111, 1.095];

% cf/c = 0.4
AR04 = [0.054, 0.126, 0.215, 0.357, 0.603, 0.989, 1.603, 2.689, 4.018, 6.012, 8.006, 10.016];
alphaDeltaRatio04 = [1.903, 1.801, 1.700, 1.601, 1.499, 1.402, 1.302, 1.203, 1.147, 1.102, 1.078, 1.066];

% cf/c = 0.5
AR05 = [0.023, 0.129, 0.253, 0.500, 0.921, 1.815, 3.005, 4.019, 5.034, 6.030, 8.041, 9.999];
alphaDeltaRatio05 = [1.700, 1.600, 1.503, 1.405, 1.305, 1.203, 1.133, 1.106, 1.083, 1.072, 1.056, 1.049];

% cf/c = 0.6
AR06 = [0.009, 0.168, 0.467, 1.028, 2.026, 3.040, 5.016, 8.006, 10.017];
alphaDeltaRatio06 = [1.499, 1.404, 1.302, 1.201, 1.135, 1.095, 1.060, 1.036, 1.032];

% cf/c = 0.7
AR07 = [-0.007, 0.100, 0.521, 1.781, 4.020, 6.013, 8.007, 10.000];
alphaDeltaRatio07 = [1.402, 1.305, 1.201, 1.101, 1.051, 1.034, 1.024, 1.022];

% cf/c = 0.8
AR08 = [-0.004, 0.977, 2.027, 5.017, 8.007, 9.982];
alphaDeltaRatio08 = [1.201, 1.099, 1.058, 1.022, 1.017, 1.010];

% cf/c = 0.9 (and 1.0 — same data)
AR09 = [-0.002, 1.013, 2.587, 6.014, 10.017];
alphaDeltaRatio09 = [1.104, 1.048, 1.022, 1.010, 1.005];

% Post Processing
ARraw = {AR01, AR02, AR03, AR04, AR05, AR06, AR07, AR08, AR09};
ratioRaw = {alphaDeltaRatio01, alphaDeltaRatio02, alphaDeltaRatio03, ...
            alphaDeltaRatio04, alphaDeltaRatio05, alphaDeltaRatio06, ...
            alphaDeltaRatio07, alphaDeltaRatio08, alphaDeltaRatio09};

cfcValues = 0.1:0.1:0.9;
ARcommon = linspace(1, 20, 100);
ratioTable = zeros(length(cfcValues), length(ARcommon));

for i = 1:length(cfcValues)
    ar = ARraw{i};
    ar(ar < 0.01) = 0.01;
    ratioTable(i, :) = interp1(ar, ratioRaw{i}, ARcommon, ...
        'linear', 'extrap');
end

ratioTable(ratioTable < 1.0) = 1.0;
[ARgrid, cfcGrid] = meshgrid(ARcommon, cfcValues);

%% Emperical Data - Figure 8.17 - Fowler Flaps Eq 8.6

alphaDelta40 = [0.60, 0.60, 0.60, 0.59, 0.58, 0.57, 0.55, 0.52, 0.49];
alphaDelta30 = [0.55, 0.55, 0.54, 0.53, 0.52, 0.51, 0.50, 0.48, 0.44];
alphaDelta25 = [0.52, 0.52, 0.51, 0.50, 0.49, 0.48, 0.46, 0.43, 0.39];
alphaDelta20 = [0.45, 0.45, 0.44, 0.43, 0.42, 0.41, 0.39, 0.36, 0.33];
alphaDelta15 = [0.38, 0.38, 0.38, 0.37, 0.36, 0.35, 0.32, 0.30, 0.27];

deltaFlaps = [0, 5, 10, 15, 20, 25, 30, 35, 40];
cfOvercFlaps = [0.15, 0.20, 0.25, 0.30, 0.40];

alphaDeltaTable = [
    alphaDelta15;
    alphaDelta20;
    alphaDelta25;
    alphaDelta30;
    alphaDelta40
];

deltaFlapsInterp = 0:1:40;
alphaDeltaInterp = zeros(size(alphaDeltaTable, 1), length(deltaFlapsInterp));

for i = 1:size(alphaDeltaTable, 1)
    alphaDeltaInterp(i, :) = ...
    interp1(deltaFlaps, alphaDeltaTable(i, :), deltaFlapsInterp, 'linear');
end

%% Empirical Data - Figure 8.26 - Slats

clDeltaSlats = ...
    [0, 0.0005, 0.0015, 0.0028, 0.0045, 0.0065, 0.0088, 0.0112, ...
    0.0138, 0.0160, 0.0185]; % 1/deg

clDeltaSlats = clDeltaSlats * (180/pi); % 1/rad

cfOvercSlats = ...
    [0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50];

cfOvercSlatsInterp = 0.00:0.01:0.50;

clDeltaSlatsInterp = ...
    interp1(cfOvercSlats, clDeltaSlats, cfOvercSlatsInterp, 'linear');

%% Aircraft Parameters

cfOverCFlapDesignIndex = 3; % 0.25
cfOverCSlatDesignIndex = 11; % 0.10

cfOverCFlapDesign = cfOvercFlaps(cfOverCFlapDesignIndex);
cfOverCSlatDesign = cfOvercSlatsInterp(cfOverCSlatDesignIndex);

ComplexSectionsSpan = [6.35, 6.49, 12.98, 19.47, 19.47, 6.49];

clAlpha0612 = 2*pi;
clAlpha0610 = 2*pi;
clAlpha0606 = 2*pi;
clAlpha0404 = 2*pi;

clAlphaDistro = [
    clAlpha0612;
    clAlpha0612;
    clAlpha0612;
    clAlpha0610;
    clAlpha0606;
    clAlpha0404;
];

if length(clAlphaDistro) ~= length (ComplexSectionsSpan)
    error('"%s" and "%s" are not equal length.', ...
        clAlphaDistro, ComplexSectionsSpan ...
    );
end

aileronLength = 0.15; % eta normalized already (% of single wing span)

airDensity = 0.002378;

ARdesign = 15;

alphaDeltaRatio3Dflap = interp2(ARgrid, cfcGrid, ratioTable, ...
    ARdesign, cfOverCFlapDesign, 'linear');

alphaDeltaRatio3Dslat = interp2(ARgrid, cfcGrid, ratioTable, ...
    ARdesign, cfOverCSlatDesign, 'linear');

aoaTO = 10;
VLOF = 1.1 * 140;
WTO = 163800;

aoaLD = 5;
VAPP = 1.23 * 130;
WLD = WTO - (0.9*31600);


%% Step 1: Read OpenVSP Data & DegenGeom

filelocation  = "./test/";
filenameAero  = "BAAT4_polar.csv";
filenameDegen = "BAAT3_FuselageWingChanged_DegenGeom.csv";
wingCompName  = "Aero New Main";

filenameAndPathAero  = filelocation + filenameAero;
filenameAndPathDegen = filelocation + filenameDegen;

VSP = ReadFileAero(filenameAndPathAero, aoaTO, aoaLD);
DEGEN = ReadFileGeom(filenameAndPathDegen, wingCompName);

xLEDistro = interp1(DEGEN.ley, DEGEN.lex, VSP.avgSpanLocTO, 'linear');

%% Step 1b: Compute eta
etaDistroTO = ComputeEta(VSP.avgSpanLocTO, VSP.b);
etaDistroLD = ComputeEta(VSP.avgSpanLocLD, VSP.b);

sum = 0;
ComplexSectionEta = zeros(1,6);

for i = 1:length(ComplexSectionsSpan)
    sum = sum + ComplexSectionsSpan(i);
    ComplexSectionEta(i) = sum / (VSP.b / 2.0);
end

etaBeginFlap = ComplexSectionEta(2);
etaEndFlap   = ComplexSectionEta(end-1) - aileronLength;

etaBeginSlat = ComplexSectionEta(2);
etaEndSlat   = ComplexSectionEta(end-1);

%% Step 2: Clean wing CL

CLcleanTO = ComputeCL( ...
    VSP.b, ...
    VSP.sRef, ...
    VSP.clDistroSpanTO, ...
    etaDistroTO, ...
    VSP.cRef ...
);

CLcleanLD = ComputeCL( ...
    VSP.b, ...
    VSP.sRef, ...
    VSP.clDistroSpanLD, ...
    etaDistroLD, ...
    VSP.cRef ...
);

%% Step 2b: Compute Clean Wing Lift Curve Slope + Wing Lift Increment

CLalphaWing = (abs(CLcleanTO - CLcleanLD)) ...
                / (abs(aoaTO - aoaLD) * (pi/180));

%% Step 3: Required CL

CLreqTO = CLtoWeight(WTO, airDensity, VLOF, VSP.sRef, aoaTO);
CLreqLD = CLtoWeight(WLD, airDensity, VAPP, VSP.sRef, aoaLD);

%% Step 4: Deficit

CLdiffTO = DeltaCL(CLreqTO, CLcleanTO);
CLdiffLD = DeltaCL(CLreqLD, CLcleanLD);

fprintf('=== Clean Wing Results ===\n');
fprintf('CL_clean TO = %.4f, CL_req TO = %.4f, Deficit = %.4f\n', ...
    CLcleanTO, CLreqTO, CLdiffTO ...
);
fprintf('CL_clean LD = %.4f, CL_req LD = %.4f, Deficit = %.4f\n', ...
    CLcleanLD, CLreqLD, CLdiffLD ...
);
fprintf('\n');

%% Steps 5-8: Trade Study
fprintf('=== Trade Study Results ===\n');
fprintf('%-6s %-5s | %-12s %-8s %-1s | %-12s %-8s %-1s\n', ...
    'df', 'ds', 'CL_TO', 'req_TO', 'TO_ok', 'CL_LD', 'req_LD', 'LD_ok');
fprintf('%s\n', repmat('-', 1, 80));

cfDistroFlap = cfOverCFlapDesign .* VSP.cDistro;
cfDistroSlat = cfOverCSlatDesign .* VSP.cDistro;

xHLDistro = xLEDistro + (VSP.cDistro - cfDistroFlap);
HingeLineSweep   = atan2d(diff(xHLDistro), diff(VSP.avgSpanLocTO));
HingeLineSweep(end+1) = HingeLineSweep(end);
LeadingEdgeSweep = atan2d(diff(xLEDistro), diff(VSP.avgSpanLocTO));
LeadingEdgeSweep(end+1) = LeadingEdgeSweep(end);

cPrimeOverCFlaps = 1 + (cfOverCFlapDesign .* cosd(deltaFlapsInterp));
cPrimeOverCSlats = 1 + (cfOverCSlatDesign .* cosd(deltaFlapsInterp));

cOvercref = VSP.cDistro ./ VSP.cRef;

alphaDeltaRow     = alphaDeltaInterp(cfOverCFlapDesignIndex, :);
clDeltaSlatDesign = clDeltaSlatsInterp(cfOverCSlatDesignIndex);

bestTO = [];
bestLD = [];

for i = 1:length(deltaFlapsInterp) % flap deflection
    for j = 1:length(deltaFlapsInterp) % slat deflection

        deltaFlaps = deltaFlapsInterp(i);
        deltaSlats = deltaFlapsInterp(j);

        alphaDelta = alphaDeltaRow(i);
        cPrimeOverCFlap = cPrimeOverCFlaps(i);

        cPrimeOverCSlat = cPrimeOverCSlats(j);

        modTO = ModifiedCLDistro( ...
            VSP.clDistroSpanTO, ...
            etaDistroTO, ...
            ComplexSectionEta, ...
            clAlphaDistro, ...
            etaBeginFlap, ...
            etaEndFlap, ...
            etaBeginSlat, ...
            etaEndSlat, ...
            alphaDelta, ...
            cPrimeOverCFlap, ...
            deltaFlaps, ...
            HingeLineSweep, ...
            cOvercref, ...
            clDeltaSlatDesign, ...
            deltaSlats, ...
            cPrimeOverCSlat, ...
            LeadingEdgeSweep, ...
            alphaDeltaRatio3Dflap, ...
            alphaDeltaRatio3Dslat, ...
            CLalphaWing ...
        );

        modLD = ModifiedCLDistro( ...
            VSP.clDistroSpanLD, ...
            etaDistroLD, ...
            ComplexSectionEta, ...
            clAlphaDistro, ...
            etaBeginFlap, ...
            etaEndFlap, ...
            etaBeginSlat, ...
            etaEndSlat, ...
            alphaDelta, ...
            cPrimeOverCFlap, ...
            deltaFlaps, ...
            HingeLineSweep, ...
            cOvercref, ...
            clDeltaSlatDesign, ...
            deltaSlats, ...
            cPrimeOverCSlat, ...
            LeadingEdgeSweep, ...
            alphaDeltaRatio3Dflap, ...
            alphaDeltaRatio3Dslat, ...
            CLalphaWing ...
        );

        CLTO = ComputeCL(VSP.b, VSP.sRef, modTO, etaDistroTO, VSP.cRef);
        CLLD = ComputeCL(VSP.b, VSP.sRef, modLD, etaDistroLD, VSP.cRef);

        TOok = CLTO >= CLreqTO;
        LDok = CLLD >= CLreqLD;

        fprintf(['df=%2d  ds=%2d | CL_TO=%.4f (req %.4f) %d | ' ...
            'CL_LD=%.4f (req %.4f) %d\n'], ...
            deltaFlaps, deltaSlats, ...
            CLTO, CLreqTO, TOok, CLLD, CLreqLD, LDok);
        
        CLTOgrid(i, j) = CLTO;
        CLLDgrid(i, j) = CLLD;

        if TOok && isempty(bestTO)
            bestTO.df = deltaFlaps;
            bestTO.ds = deltaSlats;
            bestTO.modTO = modTO;
            bestTO.CLTO = CLTO;
        end
        
        if LDok && isempty(bestLD)
            bestLD.df = deltaFlaps;
            bestLD.ds = deltaSlats;
            bestLD.modLD = modLD;
            bestLD.CLLD = CLLD;
        end
    end
end

%% Plot Heat Maps
figure;

subplot(1,2,1);
contourf(deltaFlapsInterp, deltaFlapsInterp, CLTOgrid', 20);
hold on;
contour(deltaFlapsInterp, deltaFlapsInterp, CLTOgrid', [CLreqTO CLreqTO], 'r-', 'LineWidth', 2);
colorbar;
xlabel('Flap Deflection (deg)');
ylabel('Slat Deflection (deg)');
title(sprintf('Takeoff C_L (req = %.3f)', CLreqTO));
grid on;

subplot(1,2,2);
contourf(deltaFlapsInterp, deltaFlapsInterp, CLLDgrid', 20);
hold on;
contour(deltaFlapsInterp, deltaFlapsInterp, CLLDgrid', [CLreqLD CLreqLD], 'r-', 'LineWidth', 2);
colorbar;
xlabel('Flap Deflection (deg)');
ylabel('Slat Deflection (deg)');
title(sprintf('Landing C_L (req = %.3f)', CLreqLD));
grid on;

sgtitle(sprintf('High-Lift Trade Study: c_f/c_{flap}=%.2f, c_f/c_{slat}=%.2f', ...
    cfOverCFlapDesign, cfOverCSlatDesign));

%% Plot Best Configuration
if ~isempty(bestTO) && ~isempty(bestLD)
    fprintf('\n=== Best Configuration ===\n');
    fprintf('Flap Takeoff: cf/c=%.2f, delta_f=%d deg\n', cfOverCFlapDesign, bestTO.df);
    fprintf('Slat Takeoff: cf/c=%.2f, delta_s=%d deg\n', cfOverCSlatDesign, bestTO.ds);
    fprintf('CLTO = %.4f (req %.4f)\n', bestTO.CLTO, CLreqTO);
    fprintf('Flap Landing: cf/c=%.2f, delta_f=%d deg\n', cfOverCFlapDesign, bestLD.df);
    fprintf('Slat Landing: cf/c=%.2f, delta_s=%d deg\n', cfOverCSlatDesign, bestLD.ds);
    fprintf('CLLD = %.4f (req %.4f)\n', bestLD.CLLD, CLreqLD);
    
    figure;
    
    subplot(1,2,1);
    plot(etaDistroTO, VSP.clDistroSpanTO, 'b-', 'LineWidth', 1.5); hold on;
    plot(etaDistroTO, bestTO.modTO, 'r-', 'LineWidth', 1.5);
    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('Takeoff: \\delta_f=%d°, \\delta_s=%d°', bestTO.df, bestTO.ds));
    legend('Clean', 'With Flaps+Slats');
    grid on;
    
    subplot(1,2,2);
    plot(etaDistroLD, VSP.clDistroSpanLD, 'b-', 'LineWidth', 1.5); hold on;
    plot(etaDistroLD, bestLD.modLD, 'r-', 'LineWidth', 1.5);
    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('Landing: \\delta_f=%d°, \\delta_s=%d°', bestLD.df, bestLD.ds));
    legend('Clean', 'With Flaps+Slats');
    grid on;
    
    sgtitle('Spanwise Loading: Clean vs Modified');
else
    fprintf('\n*** No configuration met both TO and LD requirements ***\n');
end