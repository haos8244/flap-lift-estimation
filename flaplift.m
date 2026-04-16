function [tradeResults, VSP, ac, clean] = flaplift()

%% Banner
fprintf('\n');
fprintf('======================================================================\n');
fprintf('       HIGH-LIFT SYSTEM SIZING  --  ROSKAM PART VI, CH. 8\n');
fprintf('       Fowler Flaps + Leading Edge Slats Trade Study\n');
fprintf('======================================================================\n\n');

%% 1. Load Inputs
ac     = AircraftConfig();       % Aircraft geometry, airfoils, weights
roskam = LoadRoskamData();       % Digitized Roskam Part VI figures

fprintf('----------------------------------------------------------------------\n');
fprintf('  AIRCRAFT CONFIGURATION\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  Wing\n');
fprintf('    Aspect Ratio            = %.1f\n', ac.wing.AR);
fprintf('    Quarter-chord sweep     = %.1f deg\n', ac.wing.Lambda_c4);
fprintf('    Aileron span fraction   = %.2f (of semispan)\n', ac.wing.aileronSpan);
fprintf('    Section spans (ft)      = [');
fprintf('%.2f ', ac.wing.sectionSpans); fprintf(']\n');
fprintf('    Number of sections      = %d\n', length(ac.wing.sectionSpans));
fprintf('\n');
fprintf('  Airfoils (inboard -> outboard)\n');
fprintf('    %-10s', 'Section'); for k = 1:length(ac.airfoils.names); fprintf('%-8s', ac.airfoils.names{k}); end; fprintf('\n');
fprintf('    %-10s', 't/c (%)'); fprintf('%-8d', ac.airfoils.tc_pct); fprintf('\n');
fprintf('    %-10s', 'cl_max'); fprintf('%-8.4f', ac.airfoils.clMax); fprintf('\n');
fprintf('    %-10s', 'cl_alpha'); fprintf('%-8.3f', ac.airfoils.clAlpha); fprintf(' (per rad)\n');
fprintf('\n');
fprintf('  Weights\n');
fprintf('    W_TO  = %.0f lb\n', ac.weights.WTO);
fprintf('    W_LD  = %.0f lb \n', ac.weights.WLD);
fprintf('    Fuel fraction burned = %.0f%%\n', ...
    (ac.weights.WTO - ac.weights.WLD) / ac.weights.WTO * 100);
fprintf('\n');
fprintf('  Atmosphere\n');
fprintf('    rho = %.6f slug/ft^3  (sea level standard)\n', ac.atmo.density);
fprintf('\n');
fprintf('  High-Lift Devices\n');
fprintf('    Flap:  cf/c = %.2f   (Fig 8.17 row index = %d)\n', ...
    ac.flap.cfOverC, ac.flap.fig817_index);
fprintf('    Slat:  cf/c = %.2f   (Fig 8.26 index = %d)\n', ...
    ac.slat.cfOverC, ac.slat.fig826_index);
fprintf('\n');
fprintf('  Design Angles of Attack\n');
fprintf('    Takeoff alpha = %d deg\n', ac.aoa.takeoff);
fprintf('    Landing alpha = %d deg\n', ac.aoa.landing);
fprintf('\n');
fprintf('  Design Takeoff and Landing Velocity Constraints\n');
fprintf('    Takeoff VLOF = %d kts\n', ac.spdcnst.VLOFcnst);
fprintf('    Landing VAPP = %d kts\n', ac.spdcnst.VAPPcnst);
fprintf('----------------------------------------------------------------------\n\n');

%% 2. Read OpenVSP Aerodynamic & Geometry Data
fprintf('----------------------------------------------------------------------\n');
fprintf('  READING OPENVSP DATA\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  Aero file : %s\n', ac.files.directory + ac.files.aeroFile);

VSP = ReadFileAero( ...
    ac.files.directory + ac.files.aeroFile, ...
    ac.aoa.takeoff, ac.aoa.landing);

fprintf('  Geom file : %s\n', ac.files.directory + ac.files.degenFile);
fprintf('\n');
fprintf('  OpenVSP Reference Values\n');
fprintf('    b     = %.4f ft    (wingspan)\n', VSP.b);
fprintf('    S_ref = %.4f ft^2  (reference area)\n', VSP.sRef);
fprintf('    c_ref = %.4f ft    (reference chord)\n', VSP.cRef);
fprintf('    Spanwise stations = %d\n', length(VSP.clDistroSpanTO));
fprintf('\n');
fprintf('  Spanwise cl*c/cref range (TO): [%.4f, %.4f]\n', ...
    min(VSP.clDistroSpanTO), max(VSP.clDistroSpanTO));
fprintf('  Spanwise cl*c/cref range (LD): [%.4f, %.4f]\n', ...
    min(VSP.clDistroSpanLD), max(VSP.clDistroSpanLD));
fprintf('  Chord range: [%.4f, %.4f] ft\n', min(VSP.cDistro), max(VSP.cDistro));
fprintf('----------------------------------------------------------------------\n\n');

%% 3. Compute Wing Section Eta Breakpoints
spanSum = 0;
nSections = length(ac.wing.sectionSpans);
sectionEta = zeros(1, nSections);
for i = 1:nSections
    spanSum = spanSum + ac.wing.sectionSpans(i);
    sectionEta(i) = spanSum / (VSP.b / 2.0);
end

fprintf('----------------------------------------------------------------------\n');
fprintf('  WING SECTION ETA BREAKPOINTS\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  Semi-span = %.4f ft\n\n', VSP.b / 2);
fprintf('  Section    Airfoil   Span (ft)   Cumul. (ft)    eta\n');
fprintf('  -------    -------   ---------   -----------    ------\n');
cumSpan = 0;
for i = 1:nSections
    cumSpan = cumSpan + ac.wing.sectionSpans(i);
    fprintf('    %d        %-6s     %6.2f       %7.2f      %.4f\n', ...
        i, ac.airfoils.names{i}, ac.wing.sectionSpans(i), cumSpan, sectionEta(i));
end
fprintf('----------------------------------------------------------------------\n\n');

%% 4. Clean Wing Analysis
clean = ComputeCleanWing(VSP, ac, sectionEta);

fprintf('----------------------------------------------------------------------\n');
fprintf('  CLEAN WING ANALYSIS\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  CL at takeoff (alpha = %d deg) = %.4f\n', ac.aoa.takeoff, clean.CL_TO);
fprintf('  CL at landing (alpha = %d deg) = %.4f\n', ac.aoa.landing, clean.CL_LD);
fprintf('  Delta CL / Delta alpha = (%.4f - %.4f) / (%d - %d) deg\n', ...
    clean.CL_TO, clean.CL_LD, ac.aoa.takeoff, ac.aoa.landing);
fprintf('  CL_alpha_W = %.4f /rad  (= %.5f /deg)\n', ...
    clean.CLalpha_W, clean.CLalpha_W * pi / 180);
fprintf('\n');
fprintf('  Stall Characteristics\n');
fprintf('    alpha_stall = %.2f deg\n', clean.alphaStall);
fprintf('    Stall eta   = %.4f  (first spanwise station to stall)\n', clean.stallEta);
fprintf('    CLmax_W (clean) = %.4f\n', clean.CLmax_W);
fprintf('\n');
VS_clean = sqrt((2 * ac.weights.WTO) / ...
    (ac.atmo.density * VSP.sRef * clean.CLmax_W));
fprintf('  Clean Wing Stall Speed (at WTO)\n');
fprintf('    V_S = sqrt(2 * %.0f / (%.6f * %.2f * %.4f))\n', ...
    ac.weights.WTO, ac.atmo.density, VSP.sRef, clean.CLmax_W);
fprintf('        = %.2f ft/s  (%.1f kts)\n', VS_clean, VS_clean * 0.592484);
fprintf('----------------------------------------------------------------------\n\n');

%% 5. Precompute High-Lift Increments
hl = ComputeHighLiftIncrements(VSP, ac, roskam, clean, sectionEta);

clAlphaRatio = clean.CLalpha_W / ac.airfoils.clAlpha(1);

fprintf('----------------------------------------------------------------------\n');
fprintf('  HIGH-LIFT PRECOMPUTATION\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  Deflection sweep: %d deg to %d deg  (step = %d deg, %d points)\n', ...
    hl.deltaSweep(1), hl.deltaSweep(end), ...
    hl.deltaSweep(2)-hl.deltaSweep(1), length(hl.deltaSweep));
fprintf('\n');
fprintf('  Flap Spanwise Extent\n');
fprintf('    eta_begin = %.4f    eta_end = %.4f\n', hl.etaBeginFlap, hl.etaEndFlap);
fprintf('    Flapped fraction of semispan = %.1f%%\n', ...
    (hl.etaEndFlap - hl.etaBeginFlap) * 100);
fprintf('  Slat Spanwise Extent\n');
fprintf('    eta_begin = %.4f    eta_end = %.4f\n', hl.etaBeginSlat, hl.etaEndSlat);
fprintf('    Slatted fraction of semispan = %.1f%%\n', ...
    (hl.etaEndSlat - hl.etaBeginSlat) * 100);
fprintf('\n');
fprintf('  3D Correction Factors (Eq 8.27)\n');
fprintf('    CL_alpha_W / cl_alpha_2D           = %.4f\n', clAlphaRatio);
fprintf('    Fig 8.53 (a_d)_CL/(a_d)_cl  flap  = %.4f\n', hl.alphaDeltaRatio3D_flap);
fprintf('    Fig 8.53 (a_d)_CL/(a_d)_cl  slat  = %.4f\n', hl.alphaDeltaRatio3D_slat);
fprintf('    Combined 3D correction  (flap)     = %.4f\n', ...
    clAlphaRatio * hl.alphaDeltaRatio3D_flap);
fprintf('    Combined 3D correction  (slat)     = %.4f\n', ...
    clAlphaRatio * hl.alphaDeltaRatio3D_slat);
fprintf('\n');
fprintf('  K_Delta Sweep Correction (Fig 8.55)\n');
fprintf('    Lambda_c/4 = %.1f deg  ->  K_Delta = %.4f\n', ...
    ac.wing.Lambda_c4, hl.KDelta);
fprintf('\n');
fprintf('  Slat cl_delta (Fig 8.26)\n');
fprintf('    At cf/c = %.2f  ->  cl_delta = %.4f /rad  (%.6f /deg)\n', ...
    ac.slat.cfOverC, hl.clDelta_slat, hl.clDelta_slat * pi/180);
fprintf('\n');
fprintf('  Alpha_delta Lookup (Fig 8.17, cf/c = %.2f)\n', ac.flap.cfOverC);
fprintf('    delta_f (deg) : ');
sampleIdx = 1:5:length(hl.deltaSweep);
if sampleIdx(end) ~= length(hl.deltaSweep); sampleIdx(end+1) = length(hl.deltaSweep); end
for si = sampleIdx; fprintf('%6d', hl.deltaSweep(si)); end; fprintf('\n');
fprintf('    alpha_delta    : ');
for si = sampleIdx; fprintf('%6.3f', hl.alphaDelta_row(si)); end; fprintf('\n');
fprintf('\n');
fprintf('  c''/c at Selected Deflections (Fowler extension)\n');
fprintf('    delta_f (deg) : ');
for si = sampleIdx; fprintf('%6d', hl.deltaSweep(si)); end; fprintf('\n');
fprintf('    c''/c   flap   : ');
for si = sampleIdx; fprintf('%6.3f', hl.cPrimeOverC_flap(si)); end; fprintf('\n');
fprintf('    c''/c   slat   : ');
for si = sampleIdx; fprintf('%6.3f', hl.cPrimeOverC_slat(si)); end; fprintf('\n');
fprintf('----------------------------------------------------------------------\n\n');

%% 6. Trade Study: Sweep Flap and Slat Deflections
fprintf('======================================================================\n');
fprintf('  TRADE STUDY: Flap & Slat Deflection Sweep\n');
fprintf('  Grid: %d flap x %d slat = %d configurations\n', ...
    length(hl.deltaSweep), length(hl.deltaSweep), length(hl.deltaSweep)^2);
fprintf('======================================================================\n\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('  Design Takeoff and Landing Velocity Constraints\n');
fprintf('    Takeoff VLOF = %d kts\n', ac.spdcnst.VLOFcnst);
fprintf('    Landing VAPP = %d kts\n', ac.spdcnst.VAPPcnst);
fprintf('----------------------------------------------------------------------\n\n');

tradeResults = RunTradeSweep(VSP, ac, clean, hl, sectionEta);

%% 7. Print Best Configuration
fprintf('\n');
fprintf('======================================================================\n');
fprintf('  tradeResults SUMMARY\n');
fprintf('======================================================================\n\n');

if ~isempty(tradeResults.bestTO) && ~isempty(tradeResults.bestLD)
    fprintf('  BEST TAKEOFF CONFIGURATION\n');
    fprintf('  --------------------------\n');
    fprintf('    Flap:  cf/c = %.2f,  delta_f = %d deg\n', ...
        ac.flap.cfOverC, tradeResults.bestTO.df);
    fprintf('    Slat:  cf/c = %.2f,  delta_s = %d deg\n', ...
        ac.slat.cfOverC, tradeResults.bestTO.ds);
    fprintf('    CL achieved  = %.4f\n', tradeResults.bestTO.CLTO);
    fprintf('    CL required  = %.4f\n', tradeResults.bestTO.CLreq);
    fprintf('    CL margin    = %.4f  (%.1f%%)\n', ...
        tradeResults.bestTO.CLTO - tradeResults.bestTO.CLreq, ...
        (tradeResults.bestTO.CLTO - tradeResults.bestTO.CLreq) / tradeResults.bestTO.CLreq * 100);
    fprintf('    V_stall      = %.2f ft/s  (%.1f kts)\n', ...
        tradeResults.bestTO.VS, tradeResults.bestTO.VS * 0.592484);
    fprintf('    V_LOF (1.1Vs)= %.2f ft/s  (%.1f kts)\n', ...
        1.1 * tradeResults.bestTO.VS, 1.1 * tradeResults.bestTO.VS * 0.592484);
    fprintf('\n');

    fprintf('  BEST LANDING CONFIGURATION\n');
    fprintf('  --------------------------\n');
    fprintf('    Flap:  cf/c = %.2f,  delta_f = %d deg\n', ...
        ac.flap.cfOverC, tradeResults.bestLD.df);
    fprintf('    Slat:  cf/c = %.2f,  delta_s = %d deg\n', ...
        ac.slat.cfOverC, tradeResults.bestLD.ds);
    fprintf('    CL achieved  = %.4f\n', tradeResults.bestLD.CLLD);
    fprintf('    CL required  = %.4f\n', tradeResults.bestLD.CLreq);
    fprintf('    CL margin    = %.4f  (%.1f%%)\n', ...
        tradeResults.bestLD.CLLD - tradeResults.bestLD.CLreq, ...
        (tradeResults.bestLD.CLLD - tradeResults.bestLD.CLreq) / tradeResults.bestLD.CLreq * 100);
    fprintf('    V_stall      = %.2f ft/s  (%.1f kts)\n', ...
        tradeResults.bestLD.VS, tradeResults.bestLD.VS * 0.592484);
    fprintf('    V_APP(1.23Vs)= %.2f ft/s  (%.1f kts)\n', ...
        1.23 * tradeResults.bestLD.VS, 1.23 * tradeResults.bestLD.VS * 0.592484);
    fprintf('\n');

    % Count total passing configs
    nPassTO = sum(tradeResults.CLTOgrid(:) >= tradeResults.CLreqTOgrid(:));
    nPassLD = sum(tradeResults.CLLDgrid(:) >= tradeResults.CLreqLDgrid(:));
    nPassBoth = sum(tradeResults.CLTOgrid(:) >= tradeResults.CLreqTOgrid(:) & ...
                    tradeResults.CLLDgrid(:) >= tradeResults.CLreqLDgrid(:));
    nTotal = numel(tradeResults.CLTOgrid);
    fprintf('  CONFIGURATION STATISTICS\n');
    fprintf('  ------------------------\n');
    fprintf('    Configs meeting TO requirement : %d / %d  (%.1f%%)\n', ...
        nPassTO, nTotal, nPassTO/nTotal*100);
    fprintf('    Configs meeting LD requirement : %d / %d  (%.1f%%)\n', ...
        nPassLD, nTotal, nPassLD/nTotal*100);
    fprintf('    Configs meeting BOTH           : %d / %d  (%.1f%%)\n', ...
        nPassBoth, nTotal, nPassBoth/nTotal*100);
else
    fprintf('  *** NO CONFIGURATION MET BOTH TO AND LD REQUIREMENTS ***\n');
    nPassTO = sum(tradeResults.CLTOgrid(:) >= tradeResults.CLreqTOgrid(:));
    nPassLD = sum(tradeResults.CLLDgrid(:) >= tradeResults.CLreqLDgrid(:));
    nTotal = numel(tradeResults.CLTOgrid);
    fprintf('    Configs meeting TO only : %d / %d\n', nPassTO, nTotal);
    fprintf('    Configs meeting LD only : %d / %d\n', nPassLD, nTotal);
end

fprintf('\n');

%% 8. Plot tradeResults
PlotResults(tradeResults, VSP, ac, clean);

fprintf('======================================================================\n');
fprintf('  Analysis complete. Plots generated.\n');
fprintf('======================================================================\n');

end