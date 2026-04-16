function PlotConfig(results, VSP, ac, clean, df, ds)
% PLOTCONFIG  Detailed view of a specific (df, ds) configuration.
%
%   Usage: PlotConfig(tradeResults, VSP, ac, clean, df, ds)
%
%   Three panels:
%     (1) Takeoff spanwise loading (baseline and with devices)
%     (2) Landing spanwise loading (baseline and with devices)
%     (3) CL vs alpha curves for both clean and flapped wings,
%         with CL_op, alpha_trim, alpha_stall, and CLmax annotated

    deltaSweep = results.deltaSweep;
    iFlap = find(deltaSweep == df, 1);
    iSlat = find(deltaSweep == ds, 1);

    if isempty(iFlap) || isempty(iSlat)
        fprintf(['PlotConfig: invalid deflection. df and ds must be in ' ...
            '[%d, %d, ..., %d].\n'], ...
            deltaSweep(1), deltaSweep(2), deltaSweep(end));
        return;
    end

    % Unpack grids at this (df, ds)
    modTO    = results.modTOall(:, iFlap, iSlat);
    modLD    = results.modLDall(:, iFlap, iSlat);
    baseTO   = results.baseTOall(:, iFlap, iSlat);
    baseLD   = results.baseLDall(:, iFlap, iSlat);
    CLTO     = results.CLTOgrid(iFlap, iSlat);
    CLLD     = results.CLLDgrid(iFlap, iSlat);
    CL_op_TO = results.CL_op_TO_grid(iFlap, iSlat);
    CL_op_LD = results.CL_op_LD_grid(iFlap, iSlat);
    a_TO     = results.alphaTrimTO_grid(iFlap, iSlat);
    a_LD     = results.alphaTrimLD_grid(iFlap, iSlat);
    CLmax    = results.CLmaxGrid(iFlap, iSlat);
    VS       = results.VSgrid(iFlap, iSlat);
    VLOF     = results.VLOFgrid(iFlap, iSlat);
    VAPP     = results.VAPPgrid(iFlap, iSlat);
    TOok     = results.TOpassGrid(iFlap, iSlat);
    LDok     = results.LDpassGrid(iFlap, iSlat);
    alphaStall = results.alphaStall;
    CLmaxClean = results.CLmax_clean;

    figure('Position', [100 100 1500 500]);

    % --- Panel 1: Takeoff spanwise loading ---
    subplot(1, 3, 1);
    plotSpanwise(clean.etaTO, baseTO, modTO, a_TO, CLTO, ...
        'Takeoff', results);

    % --- Panel 2: Landing spanwise loading ---
    subplot(1, 3, 2);
    plotSpanwise(clean.etaLD, baseLD, modLD, a_LD, CLLD, ...
        'Landing', results);

    % --- Panel 3: CL vs alpha ---
    subplot(1, 3, 3);
    plotCLvsAlpha(VSP, ac, clean, df, ds, ...
        a_TO, a_LD, CL_op_TO, CL_op_LD, CLmax, CLmaxClean, alphaStall, ...
        results, iFlap, iSlat);

    % Super-title with full summary
    TOstr = iff(TOok, 'TO: PASS', 'TO: FAIL');
    LDstr = iff(LDok, 'LD: PASS', 'LD: FAIL');
    sgtitle(sprintf(['\\delta_f=%d°, \\delta_s=%d°  |  CL_{max}=%.3f  |  ' ...
        'V_S=%.1f  V_{LOF}=%.1f  V_{APP}=%.1f kts  |  %s  |  %s'], ...
        df, ds, CLmax, VS*0.592484, VLOF*0.592484, VAPP*0.592484, ...
        TOstr, LDstr));
end

% =====================================================================
function plotSpanwise(eta, clBase, clMod, alphaTrim, CL, phase, results)
    yMin = 0;
    yMax = max(clMod) * 1.1;

    % Slat region (blue tint)
    patch([results.etaBeginSlat results.etaEndSlat ...
           results.etaEndSlat   results.etaBeginSlat], ...
          [yMin yMin yMax yMax], [0.3 0.6 0.9], ...
          'FaceAlpha', 0.12, 'EdgeColor', 'none');
    hold on;

    % Flap region (orange tint)
    patch([results.etaBeginFlap results.etaEndFlap ...
           results.etaEndFlap   results.etaBeginFlap], ...
          [yMin yMin yMax yMax], [0.9 0.5 0.2], ...
          'FaceAlpha', 0.18, 'EdgeColor', 'none');

    plot(eta, clBase, 'b--', 'LineWidth', 1.5);
    plot(eta, clMod,  'r-',  'LineWidth', 2);

    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('%s: \\alpha_{trim}=%.2f°, CL=%.3f', phase, alphaTrim, CL));
    legend({'Slat region','Flap region', ...
        sprintf('Baseline @ \\alpha=%.1f°', alphaTrim), ...
        'With devices'}, ...
        'Location', 'best');
    ylim([yMin yMax]);
    xlim([0 1]);
    grid on;
end

% =====================================================================
function plotCLvsAlpha(VSP, ac, clean, df, ds, ...
    a_TO, a_LD, CL_op_TO, CL_op_LD, CLmax, CLmaxClean, alphaStall, ...
    results, iFlap, iSlat)
% Plot CL vs alpha for the clean and flapped wings.

    cl_high = VSP.clDistroSpanTO(:);
    cl_low  = VSP.clDistroSpanLD(:);
    a_high  = ac.aoa.vspHigh;
    a_low   = ac.aoa.vspLow;

    % Sample CL vs alpha from -2 to alpha_stall+2
    alphas = linspace(-2, alphaStall + 2, 60);

    CL_clean   = zeros(size(alphas));
    CL_flapped = zeros(size(alphas));

    % Need device cfg for flapped curve (re-use precomputed modAll isn't
    % enough since we want CL at many alphas, not just at a_TO / a_LD).
    % Use the clean CLalpha slope for clean curve.
    CL_low_int = ComputeCL(VSP.b, VSP.sRef, cl_low,  clean.etaTO(:), VSP.cRef);
    CL_high_int = ComputeCL(VSP.b, VSP.sRef, cl_high, clean.etaTO(:), VSP.cRef);

    for k = 1:length(alphas)
        CL_clean(k) = CL_low_int + ...
            (CL_high_int - CL_low_int) * (alphas(k) - a_low) / (a_high - a_low);
    end

    % Flapped curve: anchor at (a_TO, CL_op_TO) with estimated slope to
    % (alpha_stall, CLmax). This is a two-point interpolation; for a more
    % accurate curve you'd re-run the integration at each trial alpha, but
    % the two-point line is visually correct and matches at the known points.
    slope_flap = (CLmax - CL_op_TO) / (alphaStall - a_TO);
    CL_flapped = CL_op_TO + slope_flap * (alphas - a_TO);

    % --- Plot ---
    plot(alphas, CL_clean,   'b-',  'LineWidth', 1.5); hold on;
    plot(alphas, CL_flapped, 'r-',  'LineWidth', 1.5);

    % CLmax lines
    yline(CLmaxClean, 'b:', 'LineWidth', 1);
    yline(CLmax,      'r:', 'LineWidth', 1);

    % Stall line
    xline(alphaStall, 'k:', 'LineWidth', 1);

    % Operating points
    plot(a_TO, CL_op_TO, 'ro', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'r', 'LineWidth', 1);
    plot(a_LD, CL_op_LD, 'mo', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'm', 'LineWidth', 1);

    % Labels on operating points
    text(a_TO+0.3, CL_op_TO, sprintf('TO (%.1f°, %.3f)', a_TO, CL_op_TO), ...
        'Color', 'r', 'FontWeight', 'bold');
    text(a_LD+0.3, CL_op_LD, sprintf('LD (%.1f°, %.3f)', a_LD, CL_op_LD), ...
        'Color', 'm', 'FontWeight', 'bold');

    xlabel('\alpha (deg)');
    ylabel('C_L');
    title(sprintf('C_L vs \\alpha  (\\alpha_{stall}=%.1f°)', alphaStall));
    legend({'Clean wing', 'Flapped wing', ...
        sprintf('CL_{max,clean} = %.3f', CLmaxClean), ...
        sprintf('CL_{max,dev} = %.3f', CLmax), ...
        sprintf('\\alpha_{stall} = %.1f°', alphaStall), ...
        'TO operating point', 'LD operating point'}, ...
        'Location', 'southeast');
    grid on;
    xlim([alphas(1) alphas(end)]);
end

% =====================================================================
function s = iff(cond, sTrue, sFalse)
    if cond, s = sTrue; else, s = sFalse; end
end
