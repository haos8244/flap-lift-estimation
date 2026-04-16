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

    %% ===== Figure 1: Design space =====
    figure('Position', [50 50 1300 900]);

    % --- Panel 1: V_LOF ---
    subplot(2,2,1);
    contourf(deltaSweep, deltaSweep, VLOFkts, 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, VLOFkts, ...
        [ac.spdcnst.VLOFcnst ac.spdcnst.VLOFcnst], ...
        'w-', 'LineWidth', 2.5);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'rp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title(sprintf('V_{LOF} (kts)  — white contour: V_{LOF} = %d kts limit', ...
        ac.spdcnst.VLOFcnst));
    grid on;

    % --- Panel 2: V_APP ---
    subplot(2,2,2);
    contourf(deltaSweep, deltaSweep, VAPPkts, 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, VAPPkts, ...
        [ac.spdcnst.VAPPcnst ac.spdcnst.VAPPcnst], ...
        'w-', 'LineWidth', 2.5);
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'rp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title(sprintf('V_{APP} (kts)  — white contour: V_{APP} = %d kts limit', ...
        ac.spdcnst.VAPPcnst));
    grid on;

    % --- Panel 3: Combined feasibility ---
    subplot(2,2,3);
    % 0 = fails both, 1 = passes TO only, 2 = passes LD only, 3 = passes both
    status = zeros(size(TOpass));
    status(TOpass & ~LDpass) = 1;
    status(~TOpass & LDpass) = 2;
    status(TOpass & LDpass)  = 3;
    imagesc(deltaSweep, deltaSweep, status);
    set(gca, 'YDir', 'normal');
    % Custom colormap: dark red, yellow, orange, green
    feasibilityCmap = [ ...
        0.55 0.10 0.10;   % fails both (dark red)
        0.95 0.85 0.25;   % TO only (yellow)
        0.90 0.50 0.15;   % LD only (orange)
        0.15 0.65 0.25];  % both (green)
    colormap(gca, feasibilityCmap);
    caxis([-0.5 3.5]);
    cb = colorbar('Ticks', [0 1 2 3], ...
        'TickLabels', {'Fails both','TO only','LD only','Both pass'});
    hold on;
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'wp', 'MarkerSize', 14, ...
            'MarkerFaceColor', 'w', 'LineWidth', 1.5);
        text(bestTO.df+0.7, bestTO.ds, 'TO*', 'Color', 'w', ...
            'FontWeight', 'bold');
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'wp', 'MarkerSize', 14, ...
            'MarkerFaceColor', 'w', 'LineWidth', 1.5);
        text(bestLD.df+0.7, bestLD.ds, 'LD*', 'Color', 'w', ...
            'FontWeight', 'bold');
    end
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title('Feasibility (* = best by min deflection)');
    grid on;

    % --- Panel 4: Deployed stall angle of attack ---
    %  alpha_stall,delta per cell from Roskam Fig 8.58 Step 4. Shows where
    %  the stall point lives in absolute terms, not just as a margin.
    subplot(2,2,4);
    alphaStallGrid = results.alphaStallGrid';
    contourf(deltaSweep, deltaSweep, alphaStallGrid, 20, 'LineStyle', 'none');
    hold on;
    [C, h] = contour(deltaSweep, deltaSweep, alphaStallGrid, ...
        13:0.5:18, 'k-', 'LineWidth', 0.6);
    clabel(C, h, 'Color', 'w', 'FontSize', 7);
    % Reference: clean-wing stall angle
    contour(deltaSweep, deltaSweep, alphaStallGrid, ...
        [results.alphaStall results.alphaStall], 'w-', 'LineWidth', 2);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'rp', 'MarkerSize', 14, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'mp', 'MarkerSize', 14, ...
            'MarkerFaceColor', 'm', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title(sprintf('\\alpha_{stall,\\delta} (deg)  |  white: clean-wing \\alpha_{stall} = %.2f°', ...
        results.alphaStall));
    grid on;

    sgtitle(sprintf(['High-Lift Trade Study: c_f/c_{flap}=%.2f, ' ...
        'c_f/c_{slat}=%.2f  |  %d x %d grid'], ...
        ac.flap.cfOverC, ac.slat.cfOverC, ...
        length(deltaSweep), length(deltaSweep)));

    %% ===== Figure 2: Best-config spanwise loadings =====
    if isempty(bestTO) || isempty(bestLD)
        return;
    end

    figure('Position', [100 100 1300 500]);

    % TO
    subplot(1,2,1);
    plotSpanwise(clean.etaTO, bestTO.baseTO, bestTO.modTO, ...
        bestTO.alphaTrim, bestTO.CLTO, bestTO.df, bestTO.ds, ...
        'Takeoff', results);

    % LD
    subplot(1,2,2);
    plotSpanwise(clean.etaLD, bestLD.baseLD, bestLD.modLD, ...
        bestLD.alphaTrim, bestLD.CLLD, bestLD.df, bestLD.ds, ...
        'Landing', results);

    sgtitle('Best-Config Spanwise Loading  (shaded = device regions)');

    %% ===== Figure 3: CLmax heat map =====
    CLmaxGrid = results.CLmaxGrid';

    figure('Position', [150 150 800 650]);
    contourf(deltaSweep, deltaSweep, CLmaxGrid, 25, 'LineStyle', 'none');
    hold on;
    % Overlay labeled contour lines for reference
    [C, h] = contour(deltaSweep, deltaSweep, CLmaxGrid, ...
        1.4:0.1:2.3, 'k-', 'LineWidth', 0.8);
    clabel(C, h, 'Color', 'w', 'FontSize', 8);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'rp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
        text(bestTO.df+0.7, bestTO.ds, ...
            sprintf('TO* (CL_{max}=%.3f)', bestTO.CLmax), ...
            'Color', 'w', 'FontWeight', 'bold');
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'mp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'm', 'LineWidth', 1.5);
        text(bestLD.df+0.7, bestLD.ds, ...
            sprintf('LD* (CL_{max}=%.3f)', bestLD.CLmax), ...
            'Color', 'w', 'FontWeight', 'bold');
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title(sprintf(['CL_{max} with devices  ' ...
        '(clean CL_{max} = %.3f)'], results.CLmax_clean));
    grid on;

    %% ===== Figure 4: Stall margins (TO and LD side-by-side) =====
    figure('Position', [200 200 1300 500]);
    
    subplot(1,2,1);
    contourf(deltaSweep, deltaSweep, results.stallMarginTO_grid', 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, results.stallMarginTO_grid', [0 0], 'w-', 'LineWidth', 2.5);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'rp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title('TO Stall Margin \alpha_{stall,\delta} - \alpha_{op,TO} (deg)');
    grid on;
    
    subplot(1,2,2);
    contourf(deltaSweep, deltaSweep, results.stallMarginLD_grid', 20, 'LineStyle', 'none');
    hold on;
    contour(deltaSweep, deltaSweep, results.stallMarginLD_grid', [0 0], 'w-', 'LineWidth', 2.5);
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'mp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'm', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title('LD Stall Margin \alpha_{stall,\delta} - \alpha_{op,LD} (deg)');
    grid on;
    
    sgtitle('Stall Margins by Phase');

    %% ===== Figure 5: Linearized CL-alpha lift curves =====
    PlotLiftCurves(results, clean);

end

function PlotLiftCurves(results, clean)
% PLOTLIFTCURVES  Linearized CL-alpha diagram for clean, best-TO, best-LD.
%
%   Shows the straight-line lift curves up to their respective stall peaks,
%   with operating points marked. Illustrates the Fig. 8.58 construction:
%   how devices shift the curve up (ΔCL_w) and move the peak left/right.

    bestTO = results.bestTO;
    bestLD = results.bestLD;
    if isempty(bestTO) || isempty(bestLD)
        warning('Need both best-TO and best-LD to plot lift curves.');
        return;
    end

    % --- Clean wing ---
    CLa_clean    = clean.CLalpha_W;           % /rad
    CLa_clean_dg = CLa_clean * pi/180;        % /deg
    aStall_clean = clean.alphaStall;           % deg
    CLmax_clean  = clean.CLmax_W;

    % Zero-lift alpha (back-extrapolate)
    a0_clean = aStall_clean - CLmax_clean / CLa_clean_dg;

    % --- Best TO ---
    iTO = find(results.deltaSweep == bestTO.df);
    CLa_TO_rad   = results.CLalphaFlappedGrid(iTO, ...
                       find(results.deltaSweep == bestTO.ds));
    CLa_TO_dg    = CLa_TO_rad * pi/180;
    aStall_TO    = bestTO.alphaStall;
    CLmax_TO     = bestTO.CLmax;
    dCLw_TO      = results.deltaCLw_grid(iTO, ...
                       find(results.deltaSweep == bestTO.ds));
    a0_TO        = aStall_TO - CLmax_TO / CLa_TO_dg;

    % --- Best LD ---
    iLD = find(results.deltaSweep == bestLD.df);
    CLa_LD_rad   = results.CLalphaFlappedGrid(iLD, ...
                       find(results.deltaSweep == bestLD.ds));
    CLa_LD_dg    = CLa_LD_rad * pi/180;
    aStall_LD    = bestLD.alphaStall;
    CLmax_LD     = bestLD.CLmax;
    dCLw_LD      = results.deltaCLw_grid(iLD, ...
                       find(results.deltaSweep == bestLD.ds));
    a0_LD        = aStall_LD - CLmax_LD / CLa_LD_dg;

    % --- Build alpha ranges for each curve ---
    aMin = min([a0_clean, a0_TO, a0_LD]) - 1;

    a_clean = linspace(a0_clean, aStall_clean, 100);
    CL_clean = CLa_clean_dg .* (a_clean - a0_clean);

    a_TO = linspace(a0_TO, aStall_TO, 100);
    CL_TO = CLa_TO_dg .* (a_TO - a0_TO);

    a_LD = linspace(a0_LD, aStall_LD, 100);
    CL_LD = CLa_LD_dg .* (a_LD - a0_LD);

    % --- Plot ---
    figure('Position', [150 150 900 650]);
    hold on;

    % Curves
    hClean = plot(a_clean, CL_clean, 'b-', 'LineWidth', 2);
    hTO    = plot(a_TO, CL_TO, 'r-', 'LineWidth', 2);
    hLD    = plot(a_LD, CL_LD, 'm-', 'LineWidth', 2);

    % Stall peaks (filled circles)
    plot(aStall_clean, CLmax_clean, 'bo', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'b');
    plot(aStall_TO, CLmax_TO, 'ro', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'r');
    plot(aStall_LD, CLmax_LD, 'mo', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'm');

    % Operating points — projected onto linearized curves
    CL_op_TO_on_line = CLa_TO_dg * (bestTO.alphaTrim - a0_TO);
    CL_op_LD_on_line = CLa_LD_dg * (bestLD.alphaTrim - a0_LD);

    plot(bestTO.alphaTrim, CL_op_TO_on_line, 'rp', 'MarkerSize', 16, ...
        'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    plot(bestLD.alphaTrim, CL_op_LD_on_line, 'mp', 'MarkerSize', 16, ...
        'MarkerFaceColor', 'm', 'LineWidth', 1.5);

    % Dashed lines from operating point up to stall (margin visualization)
    plot([bestTO.alphaTrim bestTO.alphaTrim], ...
         [0 CLa_TO_dg*(bestTO.alphaTrim - a0_TO)], ...
         'r:', 'LineWidth', 1);
    plot([aStall_TO aStall_TO], [0 CLmax_TO], 'r:', 'LineWidth', 1);

    plot([bestLD.alphaTrim bestLD.alphaTrim], ...
         [0 CLa_LD_dg*(bestLD.alphaTrim - a0_LD)], ...
         'm:', 'LineWidth', 1);
    plot([aStall_LD aStall_LD], [0 CLmax_LD], 'm:', 'LineWidth', 1);

    % Stall margin arrows
    yArrow_TO = CLmax_TO * 0.95;
    annotation_arrow(bestTO.alphaTrim, aStall_TO, yArrow_TO, 'r');

    yArrow_LD = CLmax_LD * 0.6;
    annotation_arrow(bestLD.alphaTrim, aStall_LD, yArrow_LD, 'm');

    % Delta CL_w annotation — at the TO operating alpha
    aRef = bestTO.alphaTrim;
    CL_clean_at_ref = CLa_clean_dg * (aRef - a0_clean);
    CL_TO_at_ref    = CLa_TO_dg * (aRef - a0_TO);
    if aRef > a0_clean && aRef < aStall_clean
        plot([aRef aRef], [CL_clean_at_ref CL_TO_at_ref], ...
            'k-', 'LineWidth', 1.5);
        text(aRef + 0.3, (CL_clean_at_ref + CL_TO_at_ref)/2, ...
            sprintf('\\DeltaC_{L,w} = %.3f', dCLw_TO), ...
            'FontSize', 9, 'Color', 'k');
    end

    % Labels at stall peaks
    text(aStall_clean + 0.3, CLmax_clean, ...
        sprintf('Clean (%.2f°, %.3f)', aStall_clean, CLmax_clean), ...
        'Color', 'b', 'FontSize', 9, 'FontWeight', 'bold');
    text(aStall_TO + 0.3, CLmax_TO, ...
        sprintf('TO (%.2f°, %.3f)', aStall_TO, CLmax_TO), ...
        'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold');
    text(aStall_LD + 0.3, CLmax_LD, ...
        sprintf('LD (%.2f°, %.3f)', aStall_LD, CLmax_LD), ...
        'Color', [0.6 0 0.6], 'FontSize', 9, 'FontWeight', 'bold');

    % Operating point labels
    text(bestTO.alphaTrim - 2, CL_op_TO_on_line + 0.05, ...
        sprintf('\\alpha_{op}=%.1f°\nC_{L,op}=%.3f', ...
            bestTO.alphaTrim, bestTO.CL_op), ...
        'Color', 'r', 'FontSize', 8);
    text(bestLD.alphaTrim + 0.5, CL_op_LD_on_line + 0.05, ...
        sprintf('\\alpha_{op}=%.1f°\nC_{L,op}=%.3f', ...
            bestLD.alphaTrim, bestLD.CL_op), ...
        'Color', 'm', 'FontSize', 8);

    % Formatting
    xlabel('\alpha (deg)', 'FontSize', 12);
    ylabel('C_L', 'FontSize', 12);
    title(sprintf(['Linearized C_L–\\alpha  |  Clean vs Best TO ' ...
        '(\\delta_f=%d°/\\delta_s=%d°) vs Best LD ' ...
        '(\\delta_f=%d°/\\delta_s=%d°)'], ...
        bestTO.df, bestTO.ds, bestLD.df, bestLD.ds));

    legend([hClean hTO hLD], ...
        {sprintf('Clean (C_{L\\alpha}=%.2f/rad)', CLa_clean), ...
         sprintf('TO flapped (C_{L\\alpha}=%.2f/rad)', CLa_TO_rad), ...
         sprintf('LD flapped (C_{L\\alpha}=%.2f/rad)', CLa_LD_rad)}, ...
        'Location', 'northwest', 'FontSize', 9);

    xlim([aMin-1  max([aStall_clean, aStall_TO, aStall_LD])+3]);
    ylim([0  max([CLmax_clean, CLmax_TO, CLmax_LD])*1.1]);
    grid on;
    hold off;
end

% --- Helper: draw horizontal double-arrow for stall margin ---
function annotation_arrow(x1, x2, y, col)
    plot([x1 x2], [y y], '-', 'Color', col, 'LineWidth', 1.5);
    plot(x1, y, '<', 'Color', col, 'MarkerSize', 6, 'MarkerFaceColor', col);
    plot(x2, y, '>', 'Color', col, 'MarkerSize', 6, 'MarkerFaceColor', col);
    text((x1+x2)/2, y + 0.03, sprintf('%.1f°', x2-x1), ...
        'HorizontalAlignment', 'center', 'Color', col, ...
        'FontSize', 9, 'FontWeight', 'bold');
end

% =====================================================================
function plotSpanwise(eta, clBase, clMod, alphaTrim, CL, df, ds, phase, results)
% Plot baseline and flapped loading with shaded flap/slat regions.

    yMin = 0;
    yMax = max(clMod) * 1.1;

    % Shade slat region (lighter, behind flap)
    patchEta = [results.etaBeginSlat results.etaEndSlat ...
                results.etaEndSlat   results.etaBeginSlat];
    patchY   = [yMin yMin yMax yMax];
    patch(patchEta, patchY, [0.3 0.6 0.9], ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none');
    hold on;

    % Shade flap region (darker, on top)
    patchEta = [results.etaBeginFlap results.etaEndFlap ...
                results.etaEndFlap   results.etaBeginFlap];
    patch(patchEta, patchY, [0.9 0.5 0.2], ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none');

    % Plot loadings
    plot(eta, clBase, 'b--', 'LineWidth', 1.5);
    plot(eta, clMod,  'r-',  'LineWidth', 2);

    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('%s Best: \\delta_f=%d°, \\delta_s=%d°, \\alpha_{trim}=%.2f°, CL=%.3f', ...
        phase, df, ds, alphaTrim, CL));
    legend({'Slat region', 'Flap region', ...
        sprintf('Baseline (clean @ \\alpha_{trim}=%.1f°)', alphaTrim), ...
        'With devices'}, ...
        'Location', 'best');
    ylim([yMin yMax]);
    xlim([0 1]);
    grid on;
end
