%% High-Lift System Sizing Script
% Fowler Flap (Eq. 8.6) + Leading Edge Slats (Eq. 8.15)
% Modified Roskam Part VI methodology

clc; clear; close all

%% Emperical Data - Figure 8.17 - Fowler Flaps for Eq 8.6

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
            LeadingEdgeSweep ...
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
            LeadingEdgeSweep ...
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