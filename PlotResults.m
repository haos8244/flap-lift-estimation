function PlotResults(results, VSP, ac, clean)
% PLOTRESULTS  Design-space overview plots.
%
%   Figure 1 (design space, 4 panels):
%     (1) V_LOF heat map with constraint contour and best-TO marker
%     (2) V_APP heat map with constraint contour and best-LD marker
%     (3) Combined feasibility: fails-both / only-TO-passes / both-pass
%     (4) alpha_trim_TO heat map with alpha_stall contour
%
%   Figure 2 (best-config spanwise loadings):
%     (1) TO: baseline (clean @ alpha_trim) and flapped (with devices)
%     (2) LD: same
%     Flap and slat spanwise regions are shaded.

    deltaSweep     = results.deltaSweep;
    VLOFkts        = results.VLOFgrid' * 0.592484;
    VAPPkts        = results.VAPPgrid' * 0.592484;
    alphaTO        = results.alphaTrimTO_grid';
    alphaLD        = results.alphaTrimLD_grid';
    TOpass         = results.TOpassGrid';
    LDpass         = results.LDpassGrid';
    alphaStallGrid = results.alphaStallGrid';
    bestTO         = results.bestTO;
    bestLD         = results.bestLD;

    % --- Global style settings ---
    pubFontSize    = 30;
    pubFontName    = 'Times New Roman';
    labelFontSize  = 30;
    titleFontSize  = 32;
    tickFontSize   = 24;
    markerSize     = 22;
    contourLineW   = 4;
    axisLineW      = 1.5;
    figColor       = 'white';
    set(groot, 'DefaultAxesTickLabelInterpreter', 'tex');
    set(groot, 'DefaultColorbarTickLabelInterpreter', 'tex');
    set(groot, 'DefaultTextInterpreter', 'tex');

    %% ===== Figure 1: Design Space (Publication Quality) =====
    fig1 = figure('Position', [50 50 1800 1400], 'Color', figColor);
    set(fig1, 'DefaultAxesFontName', pubFontName, ...
              'DefaultAxesFontSize', tickFontSize, ...
              'DefaultTextFontName', pubFontName, ...
              'DefaultTextColor', 'k');
 
    % Colormaps
    cmapSpeed = parula(256);
    cmapStall = parula(256);
 
    % ---------------------------------------------------------------
    % Panel 1: V_LOF
    % ---------------------------------------------------------------
    ax1 = subplot(2,2,1);
    contourf(deltaSweep, deltaSweep, VLOFkts, 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, VLOFkts, ...
        [ac.spdcnst.VLOFcnst ac.spdcnst.VLOFcnst], ...
        'w-', 'LineWidth', contourLineW);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb1 = colorbar;
    cb1.Color = 'k';
    %cb1.Label.String = 'V_{LOF} (kts)';
    cb1.Label.FontSize = labelFontSize;
    cb1.Label.FontName = pubFontName;
    cb1.Label.Color = 'k';
    cb1.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    
    if ~isempty(bestTO)
        title(sprintf('V_{LOF} - limit = %d kts  |  \\alpha_{L=W} = %.1f°', ...
            ac.spdcnst.VLOFcnst, bestTO.alphaTrim), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title(sprintf('V_{LOF} - limit = %d kts', ac.spdcnst.VLOFcnst), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end

    set(ax1, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax1, cmapSpeed);
    grid on;
    grid minor;
 
    % ---------------------------------------------------------------
    % Panel 2: V_APP
    % ---------------------------------------------------------------
    ax2 = subplot(2,2,2);
    contourf(deltaSweep, deltaSweep, VAPPkts, 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, VAPPkts, ...
        [ac.spdcnst.VAPPcnst ac.spdcnst.VAPPcnst], ...
        'w-', 'LineWidth', contourLineW);
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb2 = colorbar;
    cb2.Color = 'k';
    %cb2.Label.String = 'V_{APP} (kts)';
    cb2.Label.FontSize = labelFontSize;
    cb2.Label.FontName = pubFontName;
    cb2.Label.Color = 'k';
    cb2.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    
    if ~isempty(bestLD)
        title(sprintf('V_{APP} - limit = %d kts  |  \\alpha_{L=W} = %.1f°', ...
            ac.spdcnst.VAPPcnst, bestLD.alphaTrim), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title(sprintf('V_{APP} - limit = %d kts', ac.spdcnst.VAPPcnst), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end

    set(ax2, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax2, cmapSpeed);
    grid on;
    grid minor;
 
    % ---------------------------------------------------------------
    % Panel 3: TO Angle of Attack
    % ---------------------------------------------------------------
    ax3 = subplot(2,2,3);
    alphaTrimTOGrid = results.alphaTrimTO_grid';
    contourf(deltaSweep, deltaSweep, alphaTrimTOGrid, 20, 'LineStyle', 'none');
    hold on;
    [C, h] = contour(deltaSweep, deltaSweep, alphaTrimTOGrid, ...
        2:1:16, 'k-', 'LineWidth', 0.8);
    clabel(C, h, 'Color', 'k', 'FontSize', tickFontSize - 8, ...
        'FontName', pubFontName);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb4 = colorbar;
    cb4.Color = 'k';
    cb4.Label.FontSize = labelFontSize;
    cb4.Label.FontName = pubFontName;
    cb4.Label.Color = 'k';
    cb4.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    if ~isempty(bestTO)
        title(sprintf('\\alpha_{L=W,TO} - LOF = %.1f°', bestTO.alphaTrim), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title('\alpha_{L=W,TO}', ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end
    set(ax3, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax3, cmapStall);
    grid on;
 
    % ---------------------------------------------------------------
    % Panel 4: LD Angle of Attack
    % ---------------------------------------------------------------
    ax4 = subplot(2,2,4);
    alphaTrimLDGrid = results.alphaTrimLD_grid';
    contourf(deltaSweep, deltaSweep, alphaTrimLDGrid, 20, 'LineStyle', 'none');
    hold on;
    [C, h] = contour(deltaSweep, deltaSweep, alphaTrimLDGrid, ...
        0:1:12, 'k-', 'LineWidth', 0.8);
    clabel(C, h, 'Color', 'k', 'FontSize', tickFontSize - 8, ...
        'FontName', pubFontName);
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb5 = colorbar;
    cb5.Color = 'k';
    cb5.Label.FontSize = labelFontSize;
    cb5.Label.FontName = pubFontName;
    cb5.Label.Color = 'k';
    cb5.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    if ~isempty(bestLD)
        title(sprintf('\\alpha_{L=W,LD} - APP = %.1f°', bestLD.alphaTrim), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title('\alpha_{L=W,LD}', ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end
    set(ax4, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax4, cmapStall);
    grid on;
 
    % ---------------------------------------------------------------
    % Super title
    % ---------------------------------------------------------------
    sgtitle(sprintf('High-Lift Trade Study:  c_f/c_{flap} = %.2f,  c_f/c_{slat} = %.2f,  %d \\times %d grid', ...
        ac.flap.cfOverC, ac.slat.cfOverC, ...
        length(deltaSweep), length(deltaSweep)), ...
        'FontSize', titleFontSize + 2, 'FontWeight', 'bold', ...
        'FontName', pubFontName, 'Color', 'k');

    %% ===== Figure 2: Best-config spanwise loadings =====
    if isempty(bestTO) || isempty(bestLD)
        return;
    end

    fig2 = figure('Position', [100 100 1800 700], 'Color', 'white');
    set(fig2, 'DefaultAxesFontName', pubFontName, ...
              'DefaultAxesFontSize', tickFontSize, ...
              'DefaultTextFontName', pubFontName, ...
              'DefaultTextColor', 'k');

    % TO
    subplot(1,2,1);
    plotSpanwise(clean.etaTO, bestTO.baseTO, bestTO.modTO, ...
        bestTO.alphaTrim, bestTO.CLTO, bestTO.df, bestTO.ds, ...
        'Takeoff', results, pubFontName, labelFontSize, titleFontSize, ...
        tickFontSize, axisLineW);

    % LD
    subplot(1,2,2);
    plotSpanwise(clean.etaLD, bestLD.baseLD, bestLD.modLD, ...
        bestLD.alphaTrim, bestLD.CLLD, bestLD.df, bestLD.ds, ...
        'Landing', results, pubFontName, labelFontSize, titleFontSize, ...
        tickFontSize, axisLineW);

    sgtitle('Spanwise Loading - LOF/APP Configurations', ...
        'FontSize', titleFontSize + 2, 'FontWeight', 'bold', ...
        'FontName', pubFontName, 'Color', 'k');

    %% ===== Figure 3: Stall Margins & Deployed Stall AOA =====
    fig3 = figure('Position', [100 100 1800 1400], 'Color', 'white');
    set(fig3, 'DefaultAxesFontName', pubFontName, ...
              'DefaultAxesFontSize', tickFontSize, ...
              'DefaultTextFontName', pubFontName, ...
              'DefaultTextColor', 'k');

    % ---------------------------------------------------------------
    % Panel 1: TO Stall Margin
    % ---------------------------------------------------------------
    ax1 = subplot(2,2,1);
    contourf(deltaSweep, deltaSweep, results.stallMarginTO_grid', 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, results.stallMarginTO_grid', [0 0], ...
        'w-', 'LineWidth', contourLineW);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb1 = colorbar;
    cb1.Color = 'k';
    cb1.Label.FontSize = labelFontSize;
    cb1.Label.FontName = pubFontName;
    cb1.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    if ~isempty(bestTO)
        title(sprintf('TO Stall Margin - LOF = %+.1f°', bestTO.stallMargin), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title('TO Stall Margin', ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end
    set(ax1, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax1, cmapSpeed);
    grid on;
    grid minor;

    % ---------------------------------------------------------------
    % Panel 2: LD Stall Margin
    % ---------------------------------------------------------------
    ax2 = subplot(2,2,2);
    contourf(deltaSweep, deltaSweep, results.stallMarginLD_grid', 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, results.stallMarginLD_grid', [0 0], ...
        'w-', 'LineWidth', contourLineW);
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb2 = colorbar;
    cb2.Color = 'k';
    cb2.Label.FontSize = labelFontSize;
    cb2.Label.FontName = pubFontName;
    cb2.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    if ~isempty(bestLD)
        title(sprintf('LD Stall Margin - APP = %+.1f°', bestLD.stallMargin), ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    else
        title('LD Stall Margin', ...
            'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    end
    set(ax2, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax2, cmapSpeed);
    grid on;
    grid minor;

    % ---------------------------------------------------------------
    % Panel 3: Feasibility Region
    % ---------------------------------------------------------------
    ax3 = subplot(2,2,3);
    status = zeros(size(TOpass));
    status(TOpass | LDpass)  = 1;
    status(TOpass & LDpass)  = 2;
    imagesc(deltaSweep, deltaSweep, status);
    set(ax3, 'YDir', 'normal');
    feasibilityCmap = [ ...
        0.75 0.15 0.15;   % fail
        0.95 0.80 0.20;   % partial
        0.15 0.60 0.30];  % both
    colormap(ax3, feasibilityCmap);
    caxis([-0.5 2.5]);
    cb3 = colorbar('Ticks', [0 1 2], ...
        'TickLabels', {'Fail','TO or LD','Both'});
    cb3.Color = 'k';
    cb3.Label.FontSize = labelFontSize;
    cb3.Label.FontName = pubFontName;
    cb3.FontSize = tickFontSize - 4;
    cb3.TickDirection = 'out';
    hold on;
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    title('Feasibility Region', ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    set(ax3, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    grid off;

    % ---------------------------------------------------------------
    % Panel 4: Deployed Stall Angle of Attack
    % ---------------------------------------------------------------
    ax4 = subplot(2,2,4);
    alphaStallGrid = results.alphaStallGrid';
    contourf(deltaSweep, deltaSweep, alphaStallGrid, 20, 'LineStyle', 'none');
    hold on;
    [C, h] = contour(deltaSweep, deltaSweep, alphaStallGrid, ...
        13:0.5:18, 'k-', 'LineWidth', 0.8);
    clabel(C, h, 'Color', 'k', 'FontSize', tickFontSize - 8, ...
        'FontName', pubFontName);
    contour(deltaSweep, deltaSweep, alphaStallGrid, ...
        [results.alphaStall results.alphaStall], ...
        'w-', 'LineWidth', contourLineW);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb4 = colorbar;
    cb4.Color = 'k';
    cb4.Label.FontSize = labelFontSize;
    cb4.Label.FontName = pubFontName;
    cb4.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    title(sprintf('\\alpha_{stall,\\delta} - clean = %.1f°', ...
        results.alphaStall), ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    set(ax4, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax4, cmapStall);
    grid on;

    % ---------------------------------------------------------------
    % Super title
    % ---------------------------------------------------------------
    sgtitle('Stall Margins,  Feasibility,  and Deployed Stall AOA', ...
        'FontSize', titleFontSize + 2, 'FontWeight', 'bold', ...
        'FontName', pubFontName, 'Color', 'k');

    %% ===== Figure 4: CLmax Heat Map & Linearized CL-alpha =====
    fig4 = figure('Position', [100 100 1800 700], 'Color', 'white');
    set(fig4, 'DefaultAxesFontName', pubFontName, ...
              'DefaultAxesFontSize', tickFontSize, ...
              'DefaultTextFontName', pubFontName, ...
              'DefaultTextColor', 'k');

    % ---------------------------------------------------------------
    % Panel 1: CLmax heat map
    % ---------------------------------------------------------------
    ax1 = subplot(1,2,1);
    CLmaxGrid = results.CLmaxGrid';
    contourf(deltaSweep, deltaSweep, CLmaxGrid, 25, 'LineStyle', 'none');
    hold on;
    [C, h] = contour(deltaSweep, deltaSweep, CLmaxGrid, ...
        1.4:0.1:2.3, 'k-', 'LineWidth', 0.8);
    clabel(C, h, 'Color', 'k', 'FontSize', tickFontSize - 8, ...
        'FontName', pubFontName);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestTO.df + 1.2, bestTO.ds, 'TO', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'p', 'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        text(bestLD.df + 1.2, bestLD.ds, 'LD', 'Color', 'w', ...
            'FontWeight', 'bold', 'FontSize', tickFontSize, ...
            'FontName', pubFontName);
    end
    cb1 = colorbar;
    cb1.Color = 'k';
    cb1.Label.FontSize = labelFontSize;
    cb1.Label.FontName = pubFontName;
    cb1.TickDirection = 'out';
    xlabel('\delta_f (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('\delta_s (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    title(sprintf('C_{L,max} - clean = %.3f', results.CLmax_clean), ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');
    set(ax1, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k');
    colormap(ax1, cmapSpeed);
    grid off;

    % ---------------------------------------------------------------
    % Panel 2: Linearized CL-alpha lift curves
    % ---------------------------------------------------------------
    ax2 = subplot(1,2,2);
    hold on;

    % --- Extract data ---
    CLa_clean    = clean.CLalpha_W;
    CLa_clean_dg = CLa_clean * pi/180;
    aStall_clean = clean.alphaStall;
    CLmax_clean  = clean.CLmax_W;
    a0_clean     = aStall_clean - CLmax_clean / CLa_clean_dg;

    iTO = find(results.deltaSweep == bestTO.df);
    jTO = find(results.deltaSweep == bestTO.ds);
    CLa_TO_rad = results.CLalphaFlappedGrid(iTO, jTO);
    CLa_TO_dg  = CLa_TO_rad * pi/180;
    aStall_TO  = bestTO.alphaStall;
    CLmax_TO   = bestTO.CLmax;
    a0_TO      = aStall_TO - CLmax_TO / CLa_TO_dg;

    iLD = find(results.deltaSweep == bestLD.df);
    jLD = find(results.deltaSweep == bestLD.ds);
    CLa_LD_rad = results.CLalphaFlappedGrid(iLD, jLD);
    CLa_LD_dg  = CLa_LD_rad * pi/180;
    aStall_LD  = bestLD.alphaStall;
    CLmax_LD   = bestLD.CLmax;
    a0_LD      = aStall_LD - CLmax_LD / CLa_LD_dg;

    % --- Curves ---
    colClean = [0.2 0.2 0.8];
    colTO    = [0.85 0.12 0.12];
    colLD    = [0.0 0.55 0.35];

    a_clean = linspace(a0_clean, aStall_clean, 100);
    a_TO    = linspace(a0_TO, aStall_TO, 100);
    a_LD    = linspace(a0_LD, aStall_LD, 100);

    hClean = plot(a_clean, CLa_clean_dg*(a_clean - a0_clean), ...
        '-', 'Color', colClean, 'LineWidth', 2.5);
    hTO    = plot(a_TO, CLa_TO_dg*(a_TO - a0_TO), ...
        '-', 'Color', colTO, 'LineWidth', 2.5);
    hLD    = plot(a_LD, CLa_LD_dg*(a_LD - a0_LD), ...
        '-', 'Color', colLD, 'LineWidth', 2.5);

    % --- Stall peaks ---
    plot(aStall_clean, CLmax_clean, 'o', 'MarkerSize', 12, ...
        'Color', colClean, 'MarkerFaceColor', colClean);
    plot(aStall_TO, CLmax_TO, 'o', 'MarkerSize', 12, ...
        'Color', colTO, 'MarkerFaceColor', colTO);
    plot(aStall_LD, CLmax_LD, 'o', 'MarkerSize', 12, ...
        'Color', colLD, 'MarkerFaceColor', colLD);

    % --- CLmax labels above peaks ---
    text(aStall_clean, CLmax_clean + 0.1, sprintf('%.2f', CLmax_clean), ...
        'HorizontalAlignment', 'center', 'Color', colClean, ...
        'FontSize', tickFontSize - 4, 'FontWeight', 'bold', ...
        'FontName', pubFontName);
    text(aStall_TO, CLmax_TO + 0.1, sprintf('%.2f', CLmax_TO), ...
        'HorizontalAlignment', 'center', 'Color', colTO, ...
        'FontSize', tickFontSize - 4, 'FontWeight', 'bold', ...
        'FontName', pubFontName);
    text(aStall_LD, CLmax_LD + 0.1, sprintf('%.2f', CLmax_LD), ...
        'HorizontalAlignment', 'center', 'Color', colLD, ...
        'FontSize', tickFontSize - 4, 'FontWeight', 'bold', ...
        'FontName', pubFontName);

    % --- Operating points ---
    CL_op_TO_line = CLa_TO_dg * (bestTO.alphaTrim - a0_TO);
    CL_op_LD_line = CLa_LD_dg * (bestLD.alphaTrim - a0_LD);

    plot(bestTO.alphaTrim, CL_op_TO_line, 'p', 'MarkerSize', 24, ...
        'Color', colTO, 'MarkerFaceColor', colTO);
    plot(bestLD.alphaTrim, CL_op_LD_line, 'p', 'MarkerSize', 24, ...
        'Color', colLD, 'MarkerFaceColor', colLD);

    % --- Formatting ---
    xlabel('\alpha (deg)', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('C_L', 'FontSize', labelFontSize, 'Color', 'k', ...
        'Rotation', 0, 'HorizontalAlignment', 'right');

    title('Linearized C_L - \alpha', ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');

    lg = legend([hClean hTO hLD], ...
        {sprintf('Clean  (%.2f/rad)', CLa_clean), ...
         sprintf('TO  \\delta_f=%d°/\\delta_s=%d°  (%.2f/rad)', bestTO.df, bestTO.ds, CLa_TO_rad), ...
         sprintf('LD  \\delta_f=%d°/\\delta_s=%d°  (%.2f/rad)', bestLD.df, bestLD.ds, CLa_LD_rad)}, ...
        'Location', 'northwest', 'FontSize', tickFontSize - 4, ...
        'FontName', pubFontName);
    lg.EdgeColor = 'k';

    aMax = max([aStall_clean, aStall_TO, aStall_LD]) + 3;
    aMin = min([a0_clean, a0_TO, a0_LD]) - 1;
    xlim([aMin aMax]);
    ylim([0 max([CLmax_clean, CLmax_TO, CLmax_LD]) * 1.15]);

    set(ax2, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k', ...
        'Color', 'w');
    grid on;
    grid minor;

    % ---------------------------------------------------------------
    % Super title
    % ---------------------------------------------------------------
    sgtitle(sprintf('C_{L,max} Design Space  &  Lift Curves  |  TO: \\delta_f=%d°/\\delta_s=%d°,  LD: \\delta_f=%d°/\\delta_s=%d°', ...
        bestTO.df, bestTO.ds, bestLD.df, bestLD.ds), ...
        'FontSize', titleFontSize + 2, 'FontWeight', 'bold', ...
        'FontName', pubFontName, 'Color', 'k');
end

% =====================================================================
function plotSpanwise(eta, clBase, clMod, alphaTrim, CL, df, ds, phase, ...
    results, pubFontName, labelFontSize, titleFontSize, tickFontSize, axisLineW)
% Plot baseline and flapped loading with shaded flap/slat regions.

    yMin = 0;
    yMax = max(clMod) * 1.1;

    % Shade slat region
    patchEta = [results.etaBeginSlat results.etaEndSlat ...
                results.etaEndSlat   results.etaBeginSlat];
    patchY   = [yMin yMin yMax yMax];
    patch(patchEta, patchY, [0.3 0.6 0.9], ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none');
    hold on;

    % Shade flap region
    patchEta = [results.etaBeginFlap results.etaEndFlap ...
                results.etaEndFlap   results.etaBeginFlap];
    patch(patchEta, patchY, [0.9 0.5 0.2], ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none');

    % Plot loadings
    plot(eta, clBase, '--', 'Color', [0.2 0.2 0.8], 'LineWidth', 4);
    plot(eta, clMod,  '-',  'Color', [0.85 0.12 0.12], 'LineWidth', 4);

    xlabel('\eta = 2y/b', 'FontSize', labelFontSize, 'Color', 'k');
    ylabel('c_l \cdot c/c_{ref}', 'FontSize', labelFontSize, 'Color', 'k');
    title(sprintf('%s:  \\delta_f = %d°,  \\delta_s = %d°  |  \\alpha_{L=W} = %.1f°,  C_L = %.3f', ...
        phase, df, ds, alphaTrim, CL), ...
        'FontSize', titleFontSize, 'Color', 'k', 'FontWeight', 'bold');

    lg = legend({'Slat region', 'Flap + Slat region', ...
        sprintf('Clean @ \\alpha = %.1f°', alphaTrim), ...
        'With devices'}, ...
        'Location', 'northeast', 'FontSize', tickFontSize - 4, ...
        'FontName', pubFontName, ...
        'BackgroundAlpha', 1);

    ylim([yMin yMax]);
    xlim([0 1]);

    set(gca, 'FontSize', tickFontSize, 'LineWidth', axisLineW, ...
        'TickDir', 'out', 'Box', 'on', 'XColor', 'k', 'YColor', 'k', ...
        'Color', 'w');
    grid on;
    grid minor;
end