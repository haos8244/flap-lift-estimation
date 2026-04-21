function [tradeResults] = RunTradeSweep(VSP, ac, clean, hl, sectionEta)
% RUNTRADESWEEP  Sweep flap/slat deflections using operating-CL alpha balance.
%
%   For each (df, ds):
%     1. CLmax_devices from spanwise delta_cl_max integration
%     2. V_S = sqrt(2W / (rho S CLmax))
%        V_LOF = 1.1*V_S   (takeoff, with stall margin)
%        V_APP = 1.23*V_S  (landing, with stall margin)
%     3. Operating CL at those speeds:
%          CL_op_TO = 2*WTO / (rho * V_LOF^2 * S)
%          CL_op_LD = 2*WLD / (rho * V_APP^2 * S)
%     4. Solve for alpha_op such that the integrated flapped spanwise
%        loading produces exactly CL_op (bisection).  This is the physical
%        statement: alpha_op is the angle where wing L = W is satisfied
%        when the wing is evaluated station-by-station with devices
%        deployed.
%     5. Flapped stall AOA (Roskam Fig 8.58 Step 4):
%          alpha_stall_delta = alpha_stall_clean
%                            + (deltaCLmax - deltaCL_w) / (CL_alpha_W)_delta
%        where  deltaCL_w  is the vertical shift of the lift curve at the
%        operating alpha, and (CL_alpha_W)_delta is the flapped slope from
%        Roskam Eq 8.28 (precomputed in hl.CLalpha_flapped).
%     6. Pass/fail:
%          - Speed:  V_LOF <= V_LOF_max,  V_APP <= V_APP_max
%          - Stall:  alpha_op < alpha_stall_delta  (positive margin)
%        Both must hold.
%     7. Best config selection:
%          - Takeoff: minimize flap deflection first (drag penalty),
%                     then minimize slat among ties.
%          - Landing: minimize slat deflection first,
%                     then minimize flap among ties (flap drag aids decel).

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

    % Flapped-stall-AOA grids (Roskam Fig 8.58 Step 4)
    alphaStallGrid      = zeros(nDefl, nDefl);
    deltaCLw_grid       = zeros(nDefl, nDefl);
    CLalphaFlappedGrid  = zeros(nDefl, nDefl);
    stallMarginTO_grid  = zeros(nDefl, nDefl);
    stallMarginLD_grid  = zeros(nDefl, nDefl);

    TOpassGrid       = false(nDefl, nDefl);
    LDpassGrid       = false(nDefl, nDefl);
    TOpassV_Grid     = false(nDefl, nDefl);
    LDpassV_Grid     = false(nDefl, nDefl);
    TOpassA_Grid     = false(nDefl, nDefl);
    LDpassA_Grid     = false(nDefl, nDefl);

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
    fprintf('  df  ds  | CLmax   a_st*  V_S   V_LOF  V_APP | a_TO    CL_op_TO CL_TO   margin TO | a_LD    CL_op_LD CL_LD   margin LD\n');
    fprintf('  --- --- | ------- ------ ----- ------ ----- | ------- -------- ------- ------ -- | ------- -------- ------- ------ --\n');

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

            deltaCLmax_total = deltaCLmax_TE + deltaCLmax_LE;
            CLmax = clean.CLmax_W + deltaCLmax_total;

            % --- Reference speeds (from CLmax + stall margin factors) ---
            VS   = sqrt(2 * ac.weights.WTO / (ac.atmo.density * VSP.sRef * CLmax));
            VLOF = 1.1  * VS;
            VAPP = 1.23 * VS + 5;

            % --- Operating CL at reference speeds ---
            CL_op_TO = 2 * ac.weights.WTO / ...
                       (ac.atmo.density * VLOF^2 * VSP.sRef);
            CL_op_LD = 2 * ac.weights.WLD / ...
                       (ac.atmo.density * VAPP^2 * VSP.sRef);

            % --- Solve alpha_op by bisection: integrated loading = CL_op ---
            [alpha_op_TO, modTO, cl_base_TO, CLTO] = solveAlphaTrim( ...
                CL_op_TO, a_low, a_high, cl_low, cl_high, ...
                etaTO, sectionEta, deviceCfg, VSP);

            [alpha_op_LD, modLD, cl_base_LD, CLLD] = solveAlphaTrim( ...
                CL_op_LD, a_low, a_high, cl_low, cl_high, ...
                etaLD, sectionEta, deviceCfg, VSP);

            % === Flapped stall AOA — Roskam Fig 8.58 Step 4 ===
            %
            %   alpha_stall_delta = alpha_stall_clean
            %                     + (deltaCLmax - deltaCL_w) / (CL_alpha_W)_delta
            %
            % Step 1 (Fig 8.58): vertical shift of the lift curve at the
            % operating alpha. The device increments in ModifiedCLDistro
            % are independent of alpha, so this is just (flapped CL) -
            % (clean CL at the same alpha).
            CL_clean_atOp = ComputeCL(VSP.b, VSP.sRef, ...
                cl_base_TO, etaTO(:), VSP.cRef);
            deltaCL_w = CLTO - CL_clean_atOp;

            % Step 2: flapped lift-curve slope from Eq 8.28 (precomputed)
            CLalpha_flapped = hl.CLalpha_flapped(i);   % /rad

            % Step 4: geometric construction
            alpha_stall_delta = clean.alphaStall + ...
                (deltaCLmax_total - deltaCL_w) / (CLalpha_flapped * pi/180);

            stallMargin_TO = alpha_stall_delta - alpha_op_TO;
            stallMargin_LD = alpha_stall_delta - alpha_op_LD;

            % --- Pass/fail: BOTH speed and AOA margin must hold ---
            TOok_V = (VLOF * 0.592484 <= ac.spdcnst.VLOFcnst);
            LDok_V = (VAPP * 0.592484 <= ac.spdcnst.VAPPcnst);
            TOok_A = (stallMargin_TO > 0);
            LDok_A = (stallMargin_LD > 0);
            TOok   = TOok_V && TOok_A;
            LDok   = LDok_V && LDok_A;

            fprintf(['  %2d  %2d  | %.4f  %+5.2f %5.1f %5.1f  %5.1f | ' ...
                    '%+6.2f  %.4f   %.4f  %+5.2f  %d  |' ...
                    '%+6.2f   %.4f   %.4f %+6.2f  %d \n'], ...
                df, ds, ...
                CLmax, alpha_stall_delta, ...
                VS * 0.592484, VLOF * 0.592484, VAPP * 0.592484, ...
                alpha_op_TO, CL_op_TO, CLTO, stallMargin_TO, TOok, ...
                alpha_op_LD, CL_op_LD, CLLD, stallMargin_LD, LDok);

            % Store
            CLTOgrid(i, j)         = CLTO;
            CLLDgrid(i, j)         = CLLD;
            CL_op_TO_grid(i, j)    = CL_op_TO;
            CL_op_LD_grid(i, j)    = CL_op_LD;
            alphaTrimTO_grid(i, j) = alpha_op_TO;
            alphaTrimLD_grid(i, j) = alpha_op_LD;
            CLmaxGrid(i, j)        = CLmax;
            VSgrid(i, j)           = VS;
            VLOFgrid(i, j)         = VLOF;
            VAPPgrid(i, j)         = VAPP;

            alphaStallGrid(i, j)     = alpha_stall_delta;
            deltaCLw_grid(i, j)      = deltaCL_w;
            CLalphaFlappedGrid(i, j) = CLalpha_flapped;
            stallMarginTO_grid(i, j) = stallMargin_TO;
            stallMarginLD_grid(i, j) = stallMargin_LD;

            TOpassGrid(i, j)       = TOok;
            LDpassGrid(i, j)       = LDok;
            TOpassV_Grid(i, j)     = TOok_V;
            LDpassV_Grid(i, j)     = LDok_V;
            TOpassA_Grid(i, j)     = TOok_A;
            LDpassA_Grid(i, j)     = LDok_A;

            modTOall(:, i, j)   = modTO;
            modLDall(:, i, j)   = modLD;
            baseTOall(:, i, j)  = cl_base_TO;
            baseLDall(:, i, j)  = cl_base_LD;
        end
    end

    % ---- Best config selection ----
    % Takeoff: minimize flap first (flaps produce more drag, bad for climb)
    % Landing: minimize slat first (flap drag aids deceleration)
    [bestTO_i, bestTO_j] = pickMinDeflection(TOpassGrid, deltaSweep, 'takeoff');
    [bestLD_i, bestLD_j] = pickMinDeflection(LDpassGrid, deltaSweep, 'takeoff'); % using takeoff because unrealistic

    bestTO = packBestConfig(bestTO_i, bestTO_j, deltaSweep, ...
        CLmaxGrid, VSgrid, VLOFgrid, VAPPgrid, ...
        CL_op_TO_grid, CLTOgrid, alphaTrimTO_grid, ...
        alphaStallGrid, stallMarginTO_grid, ...
        modTOall, baseTOall, 'TO');

    bestLD = packBestConfig(bestLD_i, bestLD_j, deltaSweep, ...
        CLmaxGrid, VSgrid, VLOFgrid, VAPPgrid, ...
        CL_op_LD_grid, CLLDgrid, alphaTrimLD_grid, ...
        alphaStallGrid, stallMarginLD_grid, ...
        modLDall, baseLDall, 'LD');

    if ~isempty(bestTO)
        fprintf(['\n  >>> Best TO (min flap): df=%d, ds=%d, ' ...
                 'a_op=%.2f, a_stall=%.2f (margin %+.2f), V_LOF=%.1f kts\n'], ...
            bestTO.df, bestTO.ds, bestTO.alphaTrim, bestTO.alphaStall, ...
            bestTO.stallMargin, bestTO.VLOF*0.592484);
    else
        fprintf('\n  >>> No TO config passes (speed + stall margin)\n');
    end
    if ~isempty(bestLD)
        fprintf(['  >>> Best LD (min slat): df=%d, ds=%d, ' ...
                 'a_op=%.2f, a_stall=%.2f (margin %+.2f), V_APP=%.1f kts\n\n'], ...
            bestLD.df, bestLD.ds, bestLD.alphaTrim, bestLD.alphaStall, ...
            bestLD.stallMargin, bestLD.VAPP*0.592484);
    else
        fprintf('  >>> No LD config passes (speed + stall margin)\n\n');
    end

    % Pack outputs
    tradeResults.CLTOgrid            = CLTOgrid;
    tradeResults.CLLDgrid            = CLLDgrid;
    tradeResults.CL_op_TO_grid       = CL_op_TO_grid;
    tradeResults.CL_op_LD_grid       = CL_op_LD_grid;
    tradeResults.CLreqTOgrid         = CL_op_TO_grid;
    tradeResults.CLreqLDgrid         = CL_op_LD_grid;
    tradeResults.alphaTrimTO_grid    = alphaTrimTO_grid;
    tradeResults.alphaTrimLD_grid    = alphaTrimLD_grid;
    tradeResults.alphaTrimGrid       = alphaTrimTO_grid;
    tradeResults.CLmaxGrid           = CLmaxGrid;
    tradeResults.VSgrid              = VSgrid;
    tradeResults.VLOFgrid            = VLOFgrid;
    tradeResults.VAPPgrid            = VAPPgrid;

    % Flapped stall AOA grids
    tradeResults.alphaStallGrid      = alphaStallGrid;
    tradeResults.deltaCLw_grid       = deltaCLw_grid;
    tradeResults.CLalphaFlappedGrid  = CLalphaFlappedGrid;
    tradeResults.stallMarginTO_grid  = stallMarginTO_grid;
    tradeResults.stallMarginLD_grid  = stallMarginLD_grid;

    tradeResults.TOpassGrid          = TOpassGrid;
    tradeResults.LDpassGrid          = LDpassGrid;
    tradeResults.TOpassV_Grid        = TOpassV_Grid;
    tradeResults.LDpassV_Grid        = LDpassV_Grid;
    tradeResults.TOpassA_Grid        = TOpassA_Grid;
    tradeResults.LDpassA_Grid        = LDpassA_Grid;

    tradeResults.bestTO              = bestTO;
    tradeResults.bestLD              = bestLD;
    tradeResults.deltaSweep          = deltaSweep;
    tradeResults.modTOall            = modTOall;
    tradeResults.modLDall            = modLDall;
    tradeResults.baseTOall           = baseTOall;
    tradeResults.baseLDall           = baseLDall;
    tradeResults.alphaStall          = clean.alphaStall;
    tradeResults.CLmax_clean         = clean.CLmax_W;
    tradeResults.etaBeginFlap        = hl.etaBeginFlap;
    tradeResults.etaEndFlap          = hl.etaEndFlap;
    tradeResults.etaBeginSlat        = hl.etaBeginSlat;
    tradeResults.etaEndSlat          = hl.etaEndSlat;
end

% =====================================================================
function [alpha_op, modCL, cl_base, CL_integrated] = solveAlphaTrim( ...
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
    alpha_op = alpha_mid;

    % Final evaluation with all outputs
    cl_base = cl_low + (cl_high - cl_low) * (alpha_op - a_low) / (a_high - a_low);
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
function [iBest, jBest] = pickMinDeflection(passGrid, deltaSweep, mode)
% Select best passing config based on drag philosophy:
%   'takeoff' — minimize flap first (flap drag hurts climb), then slat
%   'landing' — minimize slat first (flap drag aids deceleration), then flap
    [I, J] = find(passGrid);
    if isempty(I)
        iBest = []; jBest = [];
        return;
    end

    if strcmp(mode, 'takeoff')
        primary   = deltaSweep(I);   % minimize flap
        secondary = deltaSweep(J);   % then minimize slat
    else
        primary   = deltaSweep(J);   % minimize slat
        secondary = deltaSweep(I);   % then minimize flap
    end

    primary = primary(:);
    [minVal, ~] = min(primary);
    tiedMask = (primary == minVal);
    tiedIdx  = find(tiedMask);

    if length(tiedIdx) > 1
        [~, subBest] = min(secondary(tiedIdx));
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
    alphaStallGrid, stallMarginGrid, ...
    modAll, baseAll, tag)
    if isempty(i)
        best = [];
        return;
    end
    best.df          = deltaSweep(i);
    best.ds          = deltaSweep(j);
    best.CLmax       = CLmaxGrid(i, j);
    best.VS          = VSgrid(i, j);
    best.VLOF        = VLOFgrid(i, j);
    best.VAPP        = VAPPgrid(i, j);
    best.CL_op       = CLopGrid(i, j);
    best.alphaTrim   = alphaGrid(i, j);
    best.alphaStall  = alphaStallGrid(i, j);
    best.stallMargin = stallMarginGrid(i, j);
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