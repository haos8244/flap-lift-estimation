function [tradeResults] = RunTradeSweep(VSP, ac, clean, hl, sectionEta)
% RUNTRADESWEEP  Sweep flap/slat deflections and evaluate CL vs CLreq.

    deltaSweep = hl.deltaSweep;
    nDefl      = length(deltaSweep);
    etaTO      = clean.etaTO;
    etaLD      = clean.etaLD;

    % Preallocate output grids
    CLTOgrid    = zeros(nDefl, nDefl);
    CLLDgrid    = zeros(nDefl, nDefl);
    CLreqTOgrid = zeros(nDefl, nDefl);
    CLreqLDgrid = zeros(nDefl, nDefl);

    bestTO = [];
    bestLD = [];

    % Build the device config struct with fields that don't change per iteration
    deviceCfg.clAlphaDistro      = hl.clAlphaDistro;
    deviceCfg.CLalpha_W          = hl.CLalpha_W;
    deviceCfg.etaBeginFlap       = hl.etaBeginFlap;
    deviceCfg.etaEndFlap         = hl.etaEndFlap;
    deviceCfg.etaBeginSlat       = hl.etaBeginSlat;
    deviceCfg.etaEndSlat         = hl.etaEndSlat;
    deviceCfg.hingeLineSweep     = hl.hingeLineSweep;
    deviceCfg.cOverCref          = hl.cOverCref;
    deviceCfg.leadingEdgeSweep   = hl.leadingEdgeSweep;
    deviceCfg.alphaDeltaRatio3D_flap = hl.alphaDeltaRatio3D_flap;
    deviceCfg.alphaDeltaRatio3D_slat = hl.alphaDeltaRatio3D_slat;
    deviceCfg.clDelta_slat       = hl.clDelta_slat;

    % Table header
    fprintf('  df   ds  | CLmax_W   dCLmax_TE dCLmax_LE | V_S(kts) V_LOF   V_APP  | CL_TO   req_TO  TO | CL_LD   req_LD  LD\n');
    fprintf('  ---  --- | --------- --------- --------- | -------- ------- ------ | ------- ------- -- | ------- ------- --\n');

    firstTOFound = false;
    firstLDFound = false;

    % Preallocate all data storage
    nStations = length(etaTO);
    modTOall = zeros(nStations, nDefl, nDefl);
    modLDall = zeros(nStations, nDefl, nDefl);

    for i = 1:nDefl      % flap deflection index
        for j = 1:nDefl  % slat deflection index

            df = deltaSweep(i);
            ds = deltaSweep(j);

            % --- Per-iteration device settings ---
            deviceCfg.alphaDelta       = hl.alphaDelta_row(i);
            deviceCfg.cPrimeOverC_flap = hl.cPrimeOverC_flap(i);
            deviceCfg.delta_f          = df;
            deviceCfg.cPrimeOverC_slat = hl.cPrimeOverC_slat(j);
            deviceCfg.delta_s          = ds;

            % --- CLmax with devices (Eq 8.29, 8.30) ---
            dclmaxTE_ccref = hl.dclmaxTE(:, i) .* hl.cOverCref(:);
            dclmaxLE_ccref = hl.dclmaxLE(:, j) .* hl.cOverCref(:);

            deltaCLmax_TE = ComputeCL(VSP.b, VSP.sRef, ...
                dclmaxTE_ccref, etaTO(:), VSP.cRef) * hl.KDelta;
            deltaCLmax_LE = ComputeCL(VSP.b, VSP.sRef, ...
                dclmaxLE_ccref, etaTO(:), VSP.cRef) * hl.KDelta;

            CLmax = clean.CLmax_W + deltaCLmax_TE + deltaCLmax_LE;

            % --- Stall speed and reference speeds ---
            VS   = sqrt((2 * ac.weights.WTO) / ...
                        (ac.atmo.density * VSP.sRef * CLmax));
            VLOF = 1.1  * VS;
            VAPP = 1.23 * VS;

            % --- Required CL at reference speeds ---
            CLreqTO = CLtoWeight(ac.weights.WTO, ac.atmo.density, ...
                VLOF, VSP.sRef, ac.aoa.takeoff);
            CLreqLD = CLtoWeight(ac.weights.WLD, ac.atmo.density, ...
                VAPP, VSP.sRef, ac.aoa.landing);

            % --- Actual CL with devices deployed ---
            modTO = ModifiedCLDistro( ...
                VSP.clDistroSpanTO(:), etaTO, sectionEta, deviceCfg);
            modLD = ModifiedCLDistro( ...
                VSP.clDistroSpanLD(:), etaLD, sectionEta, deviceCfg);

            CLTO = ComputeCL(VSP.b, VSP.sRef, modTO, etaTO, VSP.cRef);
            CLLD = ComputeCL(VSP.b, VSP.sRef, modLD, etaLD, VSP.cRef);

            % --- Pass/fail ---
            TOok = CLTO >= CLreqTO && ...
                VLOF * 0.592484 <= ac.spdcnst.VLOFcnst;
            LDok = CLLD >= CLreqLD && ...
                VAPP * 0.592484 <= ac.spdcnst.VAPPcnst;

            % --- Markers for first pass ---
            toMark = ' ';
            ldMark = ' ';
            if TOok && ~firstTOFound
                toMark = '*';
            end
            if LDok && ~firstLDFound
                ldMark = '*';
            end

            % Print row with all key numbers
            fprintf('  %2d   %2d  | %.5f   %+.4f   %+.4f   |%6.1f    %5.1f%8.1f  | %.4f  %.4f  %d%s | %.4f  %.4f  %d%s\n', ...
                df, ds, ...
                CLmax, deltaCLmax_TE, deltaCLmax_LE, ...
                VS * 0.592484, VLOF * 0.592484, VAPP * 0.592484, ...
                CLTO, CLreqTO, TOok, toMark, ...
                CLLD, CLreqLD, LDok, ldMark);

            % --- Store ---
            CLTOgrid(i, j)    = CLTO;
            CLLDgrid(i, j)    = CLLD;
            CLreqTOgrid(i, j) = CLreqTO;
            CLreqLDgrid(i, j) = CLreqLD;

            modTOall(:, i, j) = modTO;
            modLDall(:, i, j) = modLD;

            if TOok && isempty(bestTO)
                bestTO.df    = df;
                bestTO.ds    = ds;
                bestTO.modTO = modTO;
                bestTO.CLTO  = CLTO;
                bestTO.VS    = VS;
                bestTO.CLreq = CLreqTO;
                firstTOFound = true;
                fprintf('  >>> First TO-passing config found: df=%d, ds=%d <<<\n', df, ds);
            end

            if LDok && isempty(bestLD)
                bestLD.df    = df;
                bestLD.ds    = ds;
                bestLD.modLD = modLD;
                bestLD.CLLD  = CLLD;
                bestLD.VS    = VS;
                bestLD.CLreq = CLreqLD;
                firstLDFound = true;
                fprintf('  >>> First LD-passing config found: df=%d, ds=%d <<<\n', df, ds);
            end
        end
    end

    % Pack outputs
    tradeResults.CLTOgrid    = CLTOgrid;
    tradeResults.CLLDgrid    = CLLDgrid;
    tradeResults.CLreqTOgrid = CLreqTOgrid;
    tradeResults.CLreqLDgrid = CLreqLDgrid;
    tradeResults.bestTO      = bestTO;
    tradeResults.bestLD      = bestLD;
    tradeResults.deltaSweep  = deltaSweep;
    tradeResults.modTOall    = modTOall;
    tradeResults.modLDall    = modLDall;
end
