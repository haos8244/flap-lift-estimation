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

    deltaSweep = results.deltaSweep;
    VLOFkts    = results.VLOFgrid' * 0.592484;
    VAPPkts    = results.VAPPgrid' * 0.592484;
    alphaTO    = results.alphaTrimTO_grid';
    alphaLD    = results.alphaTrimLD_grid';
    TOpass     = results.TOpassGrid';
    LDpass     = results.LDpassGrid';
    alphaStall = results.alphaStall;
    bestTO     = results.bestTO;
    bestLD     = results.bestLD;

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

    % --- Panel 4: alpha_trim (TO background, TO + LD stall contours) ---
    subplot(2,2,4);
    contourf(deltaSweep, deltaSweep, alphaTO, 20, 'LineStyle', 'none');
    hold on;
    % TO stall contour (solid red, thick)
    [~, hTO] = contour(deltaSweep, deltaSweep, alphaTO, ...
        [alphaStall alphaStall], 'r-', 'LineWidth', 2.5);
    % LD stall contour (dashed magenta, thick)
    [~, hLD] = contour(deltaSweep, deltaSweep, alphaLD, ...
        [alphaStall alphaStall], 'm--', 'LineWidth', 2.5);
    if ~isempty(bestTO)
        plot(bestTO.df, bestTO.ds, 'rp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'r', 'LineWidth', 1.5);
    end
    if ~isempty(bestLD)
        plot(bestLD.df, bestLD.ds, 'mp', 'MarkerSize', 16, ...
            'MarkerFaceColor', 'm', 'LineWidth', 1.5);
    end
    colorbar;
    xlabel('Flap Deflection \delta_f (deg)');
    ylabel('Slat Deflection \delta_s (deg)');
    title(sprintf(['\\alpha_{trim,TO} (deg)  |  ' ...
        'red: \\alpha_{trim,TO}=\\alpha_{stall}  |  ' ...
        'magenta: \\alpha_{trim,LD}=\\alpha_{stall} (\\alpha_{stall}=%.1f°)'], ...
        alphaStall));
    % Hint: contour handles into legend
    if isgraphics(hTO) && isgraphics(hLD)
        legend([hTO hLD], {'TO stall boundary','LD stall boundary'}, ...
            'Location', 'best', 'TextColor', 'w');
    end
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
