function PlotConfig(results, VSP, ac, clean, df, ds)
% PLOTCONFIG  Detailed view of a specific (df, ds) configuration.

    deltaSweep = results.deltaSweep;
    iFlap = find(deltaSweep == df, 1);
    iSlat = find(deltaSweep == ds, 1);

    if isempty(iFlap) || isempty(iSlat)
        fprintf(['PlotConfig: invalid deflection. df and ds must be in ' ...
            '[%d, %d, ..., %d].\n'], ...
            deltaSweep(1), deltaSweep(2), deltaSweep(end));
        return;
    end

    % --- Global style settings ---
    pubFontName    = 'Times New Roman';
    labelFontSize  = 30;
    titleFontSize  = 32;
    tickFontSize   = 24;
    markerSize     = 22;
    axisLineW      = 1.5;

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

    % --- Flapped stall AOA and slope for this config ---
    aStall_delta  = results.alphaStallGrid(iFlap, iSlat);
    CLa_flap_rad  = results.CLalphaFlappedGrid(iFlap, iSlat);
    CLa_flap_dg   = CLa_flap_rad * pi/180;
    stallMargin_TO = results.stallMarginTO_grid(iFlap, iSlat);
    stallMargin_LD = results.stallMarginLD_grid(iFlap, iSlat);

    % --- Clean wing lift curve ---
    CLa_clean    = clean.CLalpha_W;
    CLa_clean_dg = CLa_clean * pi/180;
    a0_clean     = alphaStall - CLmaxClean / CLa_clean_dg;

    % --- Flapped lift curve ---
    a0_flap = aStall_delta - CLmax / CLa_flap_dg;

    fig = figure('Position', [100 100 1800 1400], 'Color', 'white');
    set(fig, 'DefaultAxesFontName', pubFontName, ...
             'DefaultAxesFontSize', tickFontSize, ...
             'DefaultTextFontName', pubFontName, ...
             'DefaultTextColor', 'k');

    colClean = [0.2 0.2 0.8];
    colTO    = [0.85 0.12 0.12];
    colLD    = [0.0 0.55 0.35];

    % ---------------------------------------------------------------
    % Panel 1: Takeoff spanwise loading
    % ---------------------------------------------------------------
    subplot(2,2,1);
    plotSpanwise(clean.etaTO, baseTO, modTO, a_TO, CLTO, df, ds, ...
        'Takeoff', results, pubFontName, labelFontSize, titleFontSize, ...
        tickFontSize, axisLineW);

    % ---------------------------------------------------------------
    % Panel 2: Landing spanwise loading
    % ---------------------------------------------------------------
    subplot(2,2,2);
    plotSpanwise(clean.etaLD, baseLD, modLD, a_LD, CLLD, df, ds, ...
        'Landing', results, pubFontName, labelFontSize, titleFontSize, ...
        tickFontSize, axisLineW);

    % ---------------------------------------------------------------
    % Panel 3: CL vs alpha (linearized)
    % ---------------------------------------------------------------
    ax3 = subplot(2,2,3);
    hold on;

    a_cleanVec = linspace(a0_clean, alphaStall, 100);
    a_flapVec  = linspace(a0_flap, aStall_delta, 100);

    hClean = plot(a_cleanVec, CLa_clean_dg*(a_cleanVec - a0_clean), ...
        '-', 'Color', colClean, 'LineWidth', 2.5);
    hFlap  = plot(a_flapVec, CLa_flap_dg*(a_flapVec - a0_flap), ...
        '-', 'Color', colTO, 'LineWidth', 2.5);

    % Stall peaks
    plot(alphaStall, CLmaxClean, 'o', 'MarkerSize', 12, ...
        'Color', colClean, 'MarkerFaceColor', colClean);
    plot(aStall_delta, CLmax, 'o', 'MarkerSize', 12, ...
        'Color', colTO, 'MarkerFaceColor', colTO);

    % CLmax labels above peaks
    text(alphaStall, CLmaxClean + 0.05, sprintf('%.3f', CLmaxClean), ...
        'HorizontalAlignment', 'center', 'Color', colClean, ...
        'FontSize', tickFontSize - 4, 'FontWeight', 'bold', ...
        'FontName', pubFontName);
    text(aStall_delta, CLmax + 0.05, sprintf('%.3f', CLmax), ...
        'HorizontalAlignment', 'center', 'Color', colTO, ...
        'FontSize', tickFontSize - 4, 'FontWeight', 'bold', ...
        'FontName', pubFontName);

    % Operating points
    CL_op_TO_line = CLa_flap_dg * (a_TO - a0_flap);
    CL_op_LD_line = CLa_flap_dg * (a_LD - a0_flap);

    plot(a_TO, CL_op_TO_line, 'p', 'MarkerSize', markerSize, ...
        'Color', colTO, 'MarkerFaceColor', colTO);
    plot(a_LD, CL_op_LD_line, 'p', 'MarkerSize', markerSize, ...
        'Color', colLD, 'MarkerFaceColor', colLD);

    % Operating point labels
    text(a_TO - 1.5, CL_op_TO_line, 'TO', ...
        'Color', colTO, 'FontSize', tickFontSize, ...
        'FontWeight', 'bold', 'FontName', pubFontName);
    text(a_LD - 1.5, CL_op_LD_line, 'LD', ...
        'Color', colLD, 'FontSize', tickFontSize, ...
        'FontWeight', 'bold', 'FontName', pubFontName);

    xlabel('\alpha (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('C_L', 'FontSize', labelFontSize, 'Color', 'k', ...
        'Rotation', 0, 'HorizontalAlignment', 'right');
    title(sprintf('C_L - \\alpha  |  \\alpha_{stall,\\delta} = %.1f°', aStall_delta), ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');

    lg = legend([hClean hFlap], ...
        {sprintf('Clean  (%.2f/rad)', CLa_clean), ...
         sprintf('Flapped  (%.2f/rad)', CLa_flap_rad)}, ...
        'Location', 'northwest', 'FontSize', tickFontSize - 4, ...
        'FontName', pubFontName);
    lg.EdgeColor = 'k';

    aMin = min([a0_clean, a0_flap]) - 1;
    aMax = max([alphaStall, aStall_delta]) + 3;
    xlim([aMin aMax]);
    ylim([0 max([CLmaxClean, CLmax]) * 1.15]);

    set(ax3, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k', ...
        'Color', 'w');
    grid on;
    grid minor;

    % ---------------------------------------------------------------
    % Panel 4: Summary table
    % ---------------------------------------------------------------
    ax4 = subplot(2,2,4);
    axis off;

    TOstr = iff(TOok, 'PASS', 'FAIL');
    LDstr = iff(LDok, 'PASS', 'FAIL');

    summaryLines = { ...
        sprintf('\\delta_f = %d°,   \\delta_s = %d°', df, ds), ...
        '', ...
        sprintf('C_{L,max} = %.3f   (clean = %.3f)', CLmax, CLmaxClean), ...
        sprintf('\\alpha_{stall,\\delta} = %.1f°   (clean = %.1f°)', aStall_delta, alphaStall), ...
        sprintf('C_{L\\alpha,flapped} = %.2f /rad', CLa_flap_rad), ...
        '', ...
        sprintf('V_S = %.1f kts', VS*0.592484), ...
        sprintf('V_{LOF} = %.1f kts   (limit %d kts)  —  %s', ...
            VLOF*0.592484, ac.spdcnst.VLOFcnst, TOstr), ...
        sprintf('V_{APP} = %.1f kts   (limit %d kts)  —  %s', ...
            VAPP*0.592484, ac.spdcnst.VAPPcnst, LDstr), ...
        '', ...
        sprintf('\\alpha_{L=W,TO} = %.1f°,   margin = %+.1f°', a_TO, stallMargin_TO), ...
        sprintf('\\alpha_{L=W,LD} = %.1f°,   margin = %+.1f°', a_LD, stallMargin_LD), ...
    };

    yPos = 0.92;
    for k = 1:length(summaryLines)
        text(0.05, yPos, summaryLines{k}, ...
            'FontSize', tickFontSize, 'FontName', pubFontName, ...
            'Color', 'k', 'Units', 'normalized', ...
            'VerticalAlignment', 'top');
        yPos = yPos - 0.075;
    end

    title('Configuration Summary', ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');

    % ---------------------------------------------------------------
    % Super title
    % ---------------------------------------------------------------
    sgtitle(sprintf('Config Detail:  \\delta_f = %d°,  \\delta_s = %d°  |  %s / %s', ...
        df, ds, TOstr, LDstr), ...
        'FontSize', titleFontSize + 2, 'FontWeight', 'bold', ...
        'FontName', pubFontName, 'Color', 'k');

% =====================================================================
function plotSpanwise(eta, clBase, clMod, alphaTrim, CL, df, ds, phase, ...
    results, pubFontName, labelFontSize, titleFontSize, tickFontSize, axisLineW)

    yMin = 0;
    yMax = max(clMod) * 1.1;

    set(gca, 'Color', 'w');
    patch([results.etaBeginSlat results.etaEndSlat ...
           results.etaEndSlat   results.etaBeginSlat], ...
          [yMin yMin yMax yMax], [0.3 0.6 0.9], ...
          'FaceAlpha', 0.12, 'EdgeColor', 'none');
    hold on;

    patch([results.etaBeginFlap results.etaEndFlap ...
           results.etaEndFlap   results.etaBeginFlap], ...
          [yMin yMin yMax yMax], [0.9 0.5 0.2], ...
          'FaceAlpha', 0.18, 'EdgeColor', 'none');

    plot(eta, clBase, '--', 'Color', [0.2 0.2 0.8], 'LineWidth', 2.5);
    plot(eta, clMod,  '-',  'Color', [0.85 0.12 0.12], 'LineWidth', 2.5);

    xlabel('\eta = 2y/b', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('c_l \cdot c/c_{ref}', 'FontSize', labelFontSize, 'Color', 'k');
    title(sprintf('%s  |  \\alpha_{L=W} = %.1f°,  C_L = %.3f', ...
        phase, alphaTrim, CL), ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');

    lg = legend({'Slat region', 'Flap + Slat region', ...
        sprintf('Clean @ \\alpha = %.1f°', alphaTrim), ...
        'With devices'}, ...
        'Location', 'northeast', 'FontSize', tickFontSize - 4, ...
        'FontName', pubFontName);
    lg.EdgeColor = 'k';

    ylim([yMin yMax]);
    xlim([0 1]);

    set(gca, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k', ...
        'Color', 'w');
    grid on;
    grid minor;

% =====================================================================
function s = iff(cond, sTrue, sFalse)
    if cond, s = sTrue; else, s = sFalse; end