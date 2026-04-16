function [tradeResults] = RunTradeSweep(VSP, ac, clean, hl, sectionEta)
% RUNTRADESWEEP  Sweep flap/slat deflections using operating-CL alpha-trim.
%
%   For each (df, ds):
%     1. CLmax_devices from spanwise delta_cl_max integration
%     2. V_S = sqrt(2W / (rho S CLmax))
%        V_LOF = 1.1*V_S   (takeoff, with stall margin)
%        V_APP = 1.23*V_S  (landing, with stall margin)
%     3. Operating CL at those speeds:
%          CL_op_TO = 2*WTO / (rho * V_LOF^2 * S)
%          CL_op_LD = 2*WLD / (rho * V_APP^2 * S)
%     4. Solve for alpha_trim such that the integrated flapped spanwise
%        loading produces exactly CL_op (bisection).  This is the physical
%        statement: alpha_trim is the angle where L = W is satisfied when
%        the wing is evaluated station-by-station with devices deployed.
%     5. Pass/fail: V_LOF/V_APP below user-specified speed limits.
%     6. Best config: among passing configs, pick the one with minimum
%        total deflection (df + ds).  Clean aerodynamically.

    deltaSweep = hl.deltaSweep;
    nDefl      = length(deltaSweep);
    etaTO      = clean.etaTO;
    etaLD      = clean.etaLD;
    nStations  = length(etaTO);

    % VSP sample alphas for baseline interpolation
    a_high  = hl.alpha_vspHigh;
    a_low   = hl.alpha_vspLow;
    cl_high = hl.clDistroSpan_vspHigh(:);
    cl_low  = hl.clDistroSpan_vspLow(:);

    % Preallocate output grids
    CLTOgrid         = zeros(nDefl, nDefl);
    CLLDgrid         = zeros(nDefl, nDefl);
    CL_op_TO_grid    = zeros(nDefl, nDefl);
    CL_op_LD_grid    = zeros(nDefl, nDefl);
    alphaTrimTO_grid = zeros(nDefl, nDefl);
    alphaTrimLD_grid = zeros(nDefl, nDefl);
    CLmaxGrid        = zeros(nDefl, nDefl);
    VSgrid           = zeros(nDefl, nDefl);
    VLOFgrid         = zeros(nDefl, nDefl);
    VAPPgrid         = zeros(nDefl, nDefl);

    TOpassGrid       = false(nDefl, nDefl);
    LDpassGrid       = false(nDefl, nDefl);

    % Device config fixed fields
    deviceCfg.clAlphaDistro          = hl.clAlphaDistro;
    deviceCfg.CLalpha_W              = hl.CLalpha_W;
    deviceCfg.etaBeginFlap           = hl.etaBeginFlap;
    deviceCfg.etaEndFlap             = hl.etaEndFlap;
    deviceCfg.etaBeginSlat           = hl.etaBeginSlat;
    deviceCfg.etaEndSlat             = hl.etaEndSlat;
    deviceCfg.hingeLineSweep         = hl.hingeLineSweep;
    deviceCfg.cOverCref              = hl.cOverCref;
    deviceCfg.leadingEdgeSweep       = hl.leadingEdgeSweep;
    deviceCfg.alphaDeltaRatio3D_flap = hl.alphaDeltaRatio3D_flap;
    deviceCfg.alphaDeltaRatio3D_slat = hl.alphaDeltaRatio3D_slat;
    deviceCfg.clDelta_slat           = hl.clDelta_slat;

    % Table header
    fprintf('  df  ds  | CLmax   V_S   V_LOF  V_APP | a_TO    CL_op_TO CL_TO   TO | a_LD    CL_op_LD CL_LD   LD\n');
    fprintf('  --- --- | ------- ----- ------ ----- | ------- -------- ------- -- | ------- -------- ------- --\n');

    % Spanwise distribution storage
    modTOall  = zeros(nStations, nDefl, nDefl);
    modLDall  = zeros(nStations, nDefl, nDefl);
    baseTOall = zeros(nStations, nDefl, nDefl);
    baseLDall = zeros(nStations, nDefl, nDefl);

    for i = 1:nDefl      % flap index
        for j = 1:nDefl  % slat index

            df = deltaSweep(i);
            ds = deltaSweep(j);

            % Per-iteration device settings
            deviceCfg.alphaDelta       = hl.alphaDelta_row(i);
            deviceCfg.cPrimeOverC_flap = hl.cPrimeOverC_flap(i);
            deviceCfg.delta_f          = df;
            deviceCfg.cPrimeOverC_slat = hl.cPrimeOverC_slat(j);
            deviceCfg.delta_s          = ds;

            % --- CLmax with devices ---
            dclmaxTE_ccref = hl.dclmaxTE(:, i) .* hl.cOverCref(:);
            dclmaxLE_ccref = hl.dclmaxLE(:, j) .* hl.cOverCref(:);

            deltaCLmax_TE = ComputeCL(VSP.b, VSP.sRef, ...
                dclmaxTE_ccref, etaTO(:), VSP.cRef) * hl.KDelta;
            deltaCLmax_LE = ComputeCL(VSP.b, VSP.sRef, ...
                dclmaxLE_ccref, etaTO(:), VSP.cRef) * hl.KDelta;

            CLmax = clean.CLmax_W + deltaCLmax_TE + deltaCLmax_LE;

            % --- Reference speeds (from CLmax + stall margin factors) ---
            VS   = sqrt(2 * ac.weights.WTO / (ac.atmo.density * VSP.sRef * CLmax));
            VLOF = 1.1  * VS;
            VAPP = 1.23 * VS;

            % --- Operating CL at reference speeds ---
            CL_op_TO = 2 * ac.weights.WTO / ...
                       (ac.atmo.density * VLOF^2 * VSP.sRef);
            CL_op_LD = 2 * ac.weights.WLD / ...
                       (ac.atmo.density * VAPP^2 * VSP.sRef);

            % --- Solve alpha_trim by bisection: integrated loading = CL_op ---
            [alpha_trim_TO, modTO, cl_base_TO, CLTO] = solveAlphaTrim( ...
                CL_op_TO, a_low, a_high, cl_low, cl_high, ...
                etaTO, sectionEta, deviceCfg, VSP);

            [alpha_trim_LD, modLD, cl_base_LD, CLLD] = solveAlphaTrim( ...
                CL_op_LD, a_low, a_high, cl_low, cl_high, ...
                etaLD, sectionEta, deviceCfg, VSP);

            % --- Pass/fail (speed constraint is the real filter) ---
            TOok = (VLOF * 0.592484 <= ac.spdcnst.VLOFcnst);
            LDok = (VAPP * 0.592484 <= ac.spdcnst.VAPPcnst);

            fprintf('  %2d  %2d  | %.4f  %5.1f  %5.1f  %5.1f | %+6.2f   %.4f   %.4f %d  | %+6.2f   %.4f   %.4f %d \n', ...
                df, ds, ...
                CLmax, VS * 0.592484, VLOF * 0.592484, VAPP * 0.592484, ...
                alpha_trim_TO, CL_op_TO, CLTO, TOok, ...
                alpha_trim_LD, CL_op_LD, CLLD, LDok);

            % Store
            CLTOgrid(i, j)         = CLTO;
            CLLDgrid(i, j)         = CLLD;
            CL_op_TO_grid(i, j)    = CL_op_TO;
            CL_op_LD_grid(i, j)    = CL_op_LD;
            alphaTrimTO_grid(i, j) = alpha_trim_TO;
            alphaTrimLD_grid(i, j) = alpha_trim_LD;
            CLmaxGrid(i, j)        = CLmax;
            VSgrid(i, j)           = VS;
            VLOFgrid(i, j)         = VLOF;
            VAPPgrid(i, j)         = VAPP;
            TOpassGrid(i, j)       = TOok;
            LDpassGrid(i, j)       = LDok;

            modTOall(:, i, j)   = modTO;
            modLDall(:, i, j)   = modLD;
            baseTOall(:, i, j)  = cl_base_TO;
            baseLDall(:, i, j)  = cl_base_LD;
        end
    end

    % ---- Best config selection: minimum total deflection among passers ----
    [bestTO_i, bestTO_j] = pickMinDeflection(TOpassGrid, deltaSweep);
    [bestLD_i, bestLD_j] = pickMinDeflection(LDpassGrid, deltaSweep);

    bestTO = packBestConfig(bestTO_i, bestTO_j, deltaSweep, ...
        CLmaxGrid, VSgrid, VLOFgrid, VAPPgrid, ...
        CL_op_TO_grid, CLTOgrid, alphaTrimTO_grid, ...
        modTOall, baseTOall, 'TO');

    bestLD = packBestConfig(bestLD_i, bestLD_j, deltaSweep, ...
        CLmaxGrid, VSgrid, VLOFgrid, VAPPgrid, ...
        CL_op_LD_grid, CLLDgrid, alphaTrimLD_grid, ...
        modLDall, baseLDall, 'LD');

    if ~isempty(bestTO)
        fprintf('\n  >>> Best TO (min deflection): df=%d, ds=%d, a_trim=%.2f, V_LOF=%.1f kts\n', ...
            bestTO.df, bestTO.ds, bestTO.alphaTrim, bestTO.VLOF*0.592484);
    else
        fprintf('\n  >>> No TO config passes speed constraint\n');
    end
    if ~isempty(bestLD)
        fprintf('  >>> Best LD (min deflection): df=%d, ds=%d, a_trim=%.2f, V_APP=%.1f kts\n\n', ...
            bestLD.df, bestLD.ds, bestLD.alphaTrim, bestLD.VAPP*0.592484);
    else
        fprintf('  >>> No LD config passes speed constraint\n\n');
    end

    % Pack outputs
    tradeResults.CLTOgrid         = CLTOgrid;
    tradeResults.CLLDgrid         = CLLDgrid;
    tradeResults.CL_op_TO_grid    = CL_op_TO_grid;
    tradeResults.CL_op_LD_grid    = CL_op_LD_grid;
    tradeResults.CLreqTOgrid      = CL_op_TO_grid;
    tradeResults.CLreqLDgrid      = CL_op_LD_grid;
    tradeResults.alphaTrimTO_grid = alphaTrimTO_grid;
    tradeResults.alphaTrimLD_grid = alphaTrimLD_grid;
    tradeResults.alphaTrimGrid    = alphaTrimTO_grid;
    tradeResults.CLmaxGrid        = CLmaxGrid;
    tradeResults.VSgrid           = VSgrid;
    tradeResults.VLOFgrid         = VLOFgrid;
    tradeResults.VAPPgrid         = VAPPgrid;
    tradeResults.TOpassGrid       = TOpassGrid;
    tradeResults.LDpassGrid       = LDpassGrid;
    tradeResults.bestTO           = bestTO;
    tradeResults.bestLD           = bestLD;
    tradeResults.deltaSweep       = deltaSweep;
    tradeResults.modTOall         = modTOall;
    tradeResults.modLDall         = modLDall;
    tradeResults.baseTOall        = baseTOall;
    tradeResults.baseLDall        = baseLDall;
    tradeResults.alphaStall       = clean.alphaStall;
    tradeResults.CLmax_clean      = clean.CLmax_W;
    tradeResults.etaBeginFlap     = hl.etaBeginFlap;
    tradeResults.etaEndFlap       = hl.etaEndFlap;
    tradeResults.etaBeginSlat     = hl.etaBeginSlat;
    tradeResults.etaEndSlat       = hl.etaEndSlat;
end

% =====================================================================
function [alpha_trim, modCL, cl_base, CL_integrated] = solveAlphaTrim( ...
    CL_target, a_low, a_high, cl_low, cl_high, etaVec, sectionEta, ...
    deviceCfg, VSP)
% Find alpha such that integrated (baseline_interp + device_increments) = CL_target.
% Linear search then bisection. Baseline interp is linear in alpha between
% the two VSP sample angles.  Device increments are evaluated at the trial
% alpha (the alphaDelta lookup is deflection-based, so the increments depend
% only weakly on alpha through ModifiedCLDistro's internal use of alpha).

    % Bracket by trying [a_low - 2, a_high + 5] (wide enough for any CL_op)
    alpha_lo = a_low - 2;
    alpha_hi = a_high + 5;

    CL_at = @(alpha) evalCL(alpha, a_low, a_high, cl_low, cl_high, ...
                            etaVec, sectionEta, deviceCfg, VSP);

    CL_lo = CL_at(alpha_lo);
    CL_hi = CL_at(alpha_hi);

    % If target is outside bracket, widen
    while CL_lo > CL_target && alpha_lo > -10
        alpha_lo = alpha_lo - 2;
        CL_lo    = CL_at(alpha_lo);
    end
    while CL_hi < CL_target && alpha_hi < 25
        alpha_hi = alpha_hi + 2;
        CL_hi    = CL_at(alpha_hi);
    end

    % Bisection
    for iter = 1:40
        alpha_mid = 0.5 * (alpha_lo + alpha_hi);
        CL_mid    = CL_at(alpha_mid);
        if abs(CL_mid - CL_target) < 1e-5 || (alpha_hi - alpha_lo) < 1e-4
            break;
        end
        if CL_mid < CL_target
            alpha_lo = alpha_mid;
        else
            alpha_hi = alpha_mid;
        end
    end
    alpha_trim = alpha_mid;

    % Final evaluation with all outputs
    cl_base = cl_low + (cl_high - cl_low) * (alpha_trim - a_low) / (a_high - a_low);
    modCL   = ModifiedCLDistro(cl_base, etaVec, sectionEta, deviceCfg);
    CL_integrated = ComputeCL(VSP.b, VSP.sRef, modCL, etaVec(:), VSP.cRef);
end

% =====================================================================
function CL = evalCL(alpha, a_low, a_high, cl_low, cl_high, ...
                    etaVec, sectionEta, deviceCfg, VSP)
    cl_base = cl_low + (cl_high - cl_low) * (alpha - a_low) / (a_high - a_low);
    modCL   = ModifiedCLDistro(cl_base, etaVec, sectionEta, deviceCfg);
    CL      = ComputeCL(VSP.b, VSP.sRef, modCL, etaVec(:), VSP.cRef);
end

% =====================================================================
function [iBest, jBest] = pickMinDeflection(passGrid, deltaSweep)
% Among passing configs, pick the one with smallest df+ds.
% Ties broken by smallest df.
    [I, J] = find(passGrid);
    if isempty(I)
        iBest = []; jBest = [];
        return;
    end
    totals = deltaSweep(I) + deltaSweep(J);
    totals = totals(:);
    [minSum, ~] = min(totals);
    tiedMask = (totals == minSum);
    tiedIdx  = find(tiedMask);
    if length(tiedIdx) > 1
        % Break ties by smaller df
        dfs = deltaSweep(I(tiedIdx));
        [~, subBest] = min(dfs);
        bestIdx = tiedIdx(subBest);
    else
        bestIdx = tiedIdx;
    end
    iBest = I(bestIdx);
    jBest = J(bestIdx);
end

% =====================================================================
function best = packBestConfig(i, j, deltaSweep, CLmaxGrid, VSgrid, ...
    VLOFgrid, VAPPgrid, CLopGrid, CLachGrid, alphaGrid, ...
    modAll, baseAll, tag)
    if isempty(i)
        best = [];
        return;
    end
    best.df        = deltaSweep(i);
    best.ds        = deltaSweep(j);
    best.CLmax     = CLmaxGrid(i, j);
    best.VS        = VSgrid(i, j);
    best.VLOF      = VLOFgrid(i, j);
    best.VAPP      = VAPPgrid(i, j);
    best.CL_op     = CLopGrid(i, j);
    best.alphaTrim = alphaGrid(i, j);
    if strcmp(tag, 'TO')
        best.CLTO   = CLachGrid(i, j);
        best.modTO  = modAll(:, i, j);
        best.baseTO = baseAll(:, i, j);
    else
        best.CLLD   = CLachGrid(i, j);
        best.modLD  = modAll(:, i, j);
        best.baseLD = baseAll(:, i, j);
    end
end
