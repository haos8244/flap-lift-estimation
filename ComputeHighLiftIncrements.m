function [hl] = ComputeHighLiftIncrements(VSP, ac, roskam, clean, sectionEta)
% COMPUTEHIGHLIFTINCREMENTS  Precompute all high-lift arrays for the trade study.
%
%   hl = ComputeHighLiftIncrements(VSP, ac, roskam, clean, sectionEta)
%
%   Precomputes everything that does not depend on the (df, ds) loop indices
%   but does depend on the aircraft config + Roskam data:
%     - Sweep distributions (hinge line, leading edge)
%     - c'/c arrays for all deflections
%     - c/cref distribution
%     - alpha_delta row for the design cf/c
%     - cl_delta for the design slat cf/c
%     - 3D correction factors (Fig 8.53)
%     - K_Delta sweep correction
%     - TE delta_cl_max table (stations x deflections)
%     - LE delta_cl_max table (stations x deflections)
%     - Flap/slat spanwise extent (eta begin/end)
%
%   These arrays are indexed by the trade study deflection vector.

    etaTO = clean.etaTO;
    nStations = length(etaTO);

    %% Deflection sweep vector (shared by flap and slat sweeps)
    hl.deltaSweep = 0:1:40;
    nDefl = length(hl.deltaSweep);

    %% Flap/slat spanwise extent
    hl.etaBeginFlap = sectionEta(2);
    hl.etaEndFlap   = sectionEta(end-1) - ac.wing.aileronSpan;
    hl.etaBeginSlat = sectionEta(2);
    hl.etaEndSlat   = sectionEta(end-1);

    %% Sweep distributions from DegenGeom LE positions
    DEGEN = ReadFileGeom( ...
        ac.files.directory + ac.files.degenFile, ac.files.wingCompName);

    xLEDistro = interp1(DEGEN.ley, DEGEN.lex, VSP.avgSpanLocTO, ...
        'linear', 'extrap');

    cfDistroFlap = ac.flap.cfOverC .* VSP.cDistro;
    xHLDistro    = xLEDistro + (VSP.cDistro - cfDistroFlap);

    hl.hingeLineSweep    = atan2d(diff(xHLDistro), diff(VSP.avgSpanLocTO));
    hl.hingeLineSweep(end+1) = hl.hingeLineSweep(end);

    hl.leadingEdgeSweep  = atan2d(diff(xLEDistro), diff(VSP.avgSpanLocTO));
    hl.leadingEdgeSweep(end+1) = hl.leadingEdgeSweep(end);

    fprintf('  [HighLift] Sweep Distributions (sampled stations)\n');
    fprintf('    Station   eta       Hinge Sweep   LE Sweep\n');
    sampleK = round(linspace(1, nStations, min(6, nStations)));
    for kk = sampleK
        fprintf('    %3d       %.4f    %+6.2f deg    %+6.2f deg\n', ...
            kk, etaTO(kk), hl.hingeLineSweep(kk), hl.leadingEdgeSweep(kk));
    end

    %% c/cref distribution
    hl.cOverCref = VSP.cDistro ./ VSP.cRef;

    %% c'/c arrays for all deflections
    %  Fowler: c'/c = 1 + cf/c * cos(delta_f)
    hl.cPrimeOverC_flap = 1 + ac.flap.cfOverC .* cosd(hl.deltaSweep);
    hl.cPrimeOverC_slat = 1 + ac.slat.cfOverC .* cosd(hl.deltaSweep);

    %% Swf/S — Ratio of flapped wing area to total wing reference area
    %  Integrate the chord distribution over the flap spanwise extent.
    %  For a half-wing:  S_wf_half = integral of c(y) dy from y_begin to y_end
    %  Converting to eta:  dy = (b/2) * d(eta)
    %  Full-wing flapped area:  S_wf = 2 * (b/2) * integral( c d(eta) )
    %                                = b * trapz( eta, c )   over flap region
    flapMask = (etaTO >= hl.etaBeginFlap) & (etaTO <= hl.etaEndFlap);
    if sum(flapMask) >= 2
        hl.Swf_over_S = VSP.b * trapz(etaTO(flapMask), VSP.cDistro(flapMask)) / VSP.sRef;
    else
        hl.Swf_over_S = 0;
    end

    %% K_Delta — sweep correction on CLmax (Fig 8.55, p263)
    Lambda = ac.wing.Lambda_c4;
    hl.KDelta = (1 - 0.08 * cosd(Lambda)^2) * cosd(Lambda)^(3/4);

    %% Figure 8.17 — alpha_delta row for the design flap cf/c
    alphaDeltaInterp = zeros(size(roskam.fig817.alphaDelta, 1), nDefl);
    for i = 1:size(roskam.fig817.alphaDelta, 1)
        alphaDeltaInterp(i, :) = interp1(roskam.fig817.delta_f, ...
            roskam.fig817.alphaDelta(i, :), hl.deltaSweep, 'linear', 'extrap');
    end
    hl.alphaDelta_row = alphaDeltaInterp(ac.flap.fig817_index, :);

    %% Figure 8.26 — cl_delta for the design slat cf/c
    clDeltaSlatsInterp = interp1(roskam.fig826.cfOverC, ...
        roskam.fig826.clDelta_per_rad, ...
        0.00:0.01:0.50, 'linear', 'extrap');
    hl.clDelta_slat = clDeltaSlatsInterp(ac.slat.fig826_index);

    %% Figure 8.53 — 3D correction factors
    alphaDeltaCl_flap = interp1(roskam.fig853.cfOverC, ...
        roskam.fig853.alphaDeltaCl, ac.flap.cfOverC, 'linear', 'extrap');
    alphaDeltaCl_slat = interp1(roskam.fig853.cfOverC, ...
        roskam.fig853.alphaDeltaCl, ac.slat.cfOverC, 'linear', 'extrap');

    hl.alphaDeltaRatio3D_flap = interp2( ...
        roskam.fig853.AR_grid, roskam.fig853.alphaDeltaCl_grid, ...
        roskam.fig853.ratio_grid, ac.wing.AR, alphaDeltaCl_flap, 'linear');

    hl.alphaDeltaRatio3D_slat = interp2( ...
        roskam.fig853.AR_grid, roskam.fig853.alphaDeltaCl_grid, ...
        roskam.fig853.ratio_grid, ac.wing.AR, alphaDeltaCl_slat, 'linear');

    fprintf('  [HighLift] Fig 8.53 Lookup\n');
    fprintf('    Flap cf/c=%.2f -> alpha_delta_cl=%.4f -> ratio_3D=%.4f (at AR=%.1f)\n', ...
        ac.flap.cfOverC, alphaDeltaCl_flap, hl.alphaDeltaRatio3D_flap, ac.wing.AR);
    fprintf('    Slat cf/c=%.2f -> alpha_delta_cl=%.4f -> ratio_3D=%.4f (at AR=%.1f)\n', ...
        ac.slat.cfOverC, alphaDeltaCl_slat, hl.alphaDeltaRatio3D_slat, ac.wing.AR);

    %% TE flap delta_cl_max table — Eq 8.18: k1 * k2 * k3 * dclmax_base
    %  Result: (nStations x nDefl) matrix

    % k1 from Fig 8.32
    k1 = interp1(roskam.fig832.cfOverC_pct, roskam.fig832.k1, ...
        ac.flap.cfOverC * 100, 'linear', 'extrap');

    % k2 from Fig 8.33 (vector over deflections)
    k2 = interp1(roskam.fig833.delta_f, roskam.fig833.k2, ...
        hl.deltaSweep, 'linear', 'extrap');

    % k3 from Fig 8.34 (vector over deflections)
    k3 = interp1(roskam.fig834.deltaRatio, roskam.fig834.k3, ...
        hl.deltaSweep / roskam.fig834.deltaRef, 'linear', 'extrap');

    % Base dclmax per airfoil section from Fig 8.31
    dclmaxBase = zeros(length(ac.airfoils.tc_pct), 1);
    for i = 1:length(ac.airfoils.tc_pct)
        dclmaxBase(i) = interp1(roskam.fig831.tc_pct, roskam.fig831.dclmax, ...
            ac.airfoils.tc_pct(i), 'linear', 'extrap');
    end

    fprintf('  [HighLift] TE Flap delta_cl_max Factors (Eq 8.18)\n');
    fprintf('    k1 (Fig 8.32, cf/c=%.0f%%) = %.4f\n', ac.flap.cfOverC*100, k1);
    fprintf('    k2 (Fig 8.33) at selected deflections:\n');
    fprintf('      delta_f: '); fprintf('%5d ', hl.deltaSweep(1:5:end)); fprintf('deg\n');
    fprintf('      k2:      '); fprintf('%.3f ', k2(1:5:end)); fprintf('\n');
    fprintf('    k3 (Fig 8.34) at selected deflections:\n');
    fprintf('      k3:      '); fprintf('%.3f ', k3(1:5:end)); fprintf('\n');
    fprintf('    dclmax_base per section (Fig 8.31):\n');
    for i = 1:length(ac.airfoils.tc_pct)
        fprintf('      Section %d (t/c=%2d%%): dclmax_base = %.4f\n', ...
            i, ac.airfoils.tc_pct(i), dclmaxBase(i));
    end

    % Map to stations and apply k1*k2*k3 (only in flap span)
    hl.dclmaxTE = zeros(nStations, nDefl);
    for k = 1:nStations
        etaK = etaTO(k);
        idx = find(etaK <= sectionEta, 1, 'first');
        if isempty(idx), idx = length(sectionEta); end

        if etaK >= hl.etaBeginFlap && etaK <= hl.etaEndFlap
            hl.dclmaxTE(k, :) = k1 .* k2 .* k3 .* dclmaxBase(idx);
        end
    end

    %% LE slat delta_cl_max table — Eq 8.19: clDeltaMax * etaMax * etaDelta * delta * c'/c
    %  Result: (nStations x nDefl) matrix

    % cl_delta_max from Fig 8.35
    clDeltaMax_LE = interp1(roskam.fig835.cfOverC, roskam.fig835.clDeltaMax, ...
        ac.slat.cfOverC, 'linear', 'extrap');

    % LER/tc empirical formula and eta_max from Fig 8.36
    LER_tc_func = @(tc_pct) 0.0447 + (tc_pct - 4) * 0.01394;

    etaMaxDistro = zeros(length(ac.airfoils.tc_pct), 1);
    for i = 1:length(ac.airfoils.tc_pct)
        ler = LER_tc_func(ac.airfoils.tc_pct(i));
        etaMaxDistro(i) = interp1(roskam.fig836.LER_tc, roskam.fig836.etaMax, ...
            ler, 'linear', 'extrap');
    end

    % Map eta_max to stations
    etaMaxEta = zeros(nStations, 1);
    for k = 1:nStations
        idx = find(etaTO(k) <= sectionEta, 1, 'first');
        if isempty(idx), idx = length(sectionEta); end
        etaMaxEta(k) = etaMaxDistro(idx);
    end

    % eta_delta from Fig 8.37
    etaDelta = interp1(roskam.fig837.delta_s, roskam.fig837.etaDelta, ...
        hl.deltaSweep, 'linear', 'extrap');
    etaDelta = max(etaDelta, 0);

    fprintf('  [HighLift] LE Slat delta_cl_max Factors (Eq 8.19)\n');
    fprintf('    cl_delta_max (Fig 8.35, cf/c=%.2f) = %.4f\n', ac.slat.cfOverC, clDeltaMax_LE);
    fprintf('    eta_max per section (Fig 8.36):\n');
    for i = 1:length(ac.airfoils.tc_pct)
        ler = LER_tc_func(ac.airfoils.tc_pct(i));
        fprintf('      Section %d (t/c=%2d%%): LER/tc=%.4f -> eta_max=%.4f\n', ...
            i, ac.airfoils.tc_pct(i), ler, etaMaxDistro(i));
    end
    fprintf('    eta_delta (Fig 8.37) at selected deflections:\n');
    fprintf('      delta_s: '); fprintf('%5d ', hl.deltaSweep(1:5:end)); fprintf('deg\n');
    fprintf('      eta_d:   '); fprintf('%.3f ', etaDelta(1:5:end)); fprintf('\n');

    % Build LE dclmax table
    hl.dclmaxLE = zeros(nStations, nDefl);
    for k = 1:nStations
        if etaTO(k) >= hl.etaBeginSlat && etaTO(k) <= hl.etaEndSlat
            hl.dclmaxLE(k, :) = clDeltaMax_LE ...
                              * etaMaxEta(k) ...
                              .* etaDelta ...
                              .* (hl.deltaSweep * pi/180) ...
                              .* hl.cPrimeOverC_slat;
        end
    end

    %% Store section data needed by ModifiedCLDistro
    hl.clAlphaDistro = ac.airfoils.clAlpha;
    hl.CLalpha_W     = clean.CLalpha_W;

    %% Store VSP baseline samples for alpha_trim interpolation
    %  RunTradeSweep will interpolate cl*c/cref from these two samples
    %  (at vspLow and vspHigh) to alpha_trim for each config.
    hl.alpha_vspHigh        = ac.aoa.vspHigh;        % deg
    hl.alpha_vspLow         = ac.aoa.vspLow;         % deg
    hl.clDistroSpan_vspHigh = VSP.clDistroSpanTO;    % at vspHigh (10 deg)
    hl.clDistroSpan_vspLow  = VSP.clDistroSpanLD;    % at vspLow  (5 deg)

end
