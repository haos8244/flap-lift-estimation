function PlotResults(results, VSP, ac, clean)
% PLOTRESULTS  Generate heat maps and spanwise loading plots.
%
%   PlotResults(results, VSP, ac, clean)

    deltaSweep = results.deltaSweep;

    %% Heat Maps: CL - CLreq
    figure;

    subplot(1,2,1);
    diffTO = results.CLTOgrid' - results.CLreqTOgrid';
    contourf(deltaSweep, deltaSweep, diffTO, 20);
    hold on;
    contour(deltaSweep, deltaSweep, diffTO, [0 0], 'r-', 'LineWidth', 2);
    colorbar;
    xlabel('Flap Deflection (deg)');
    ylabel('Slat Deflection (deg)');
    title('Takeoff: CL - CL_{req} (red = boundary, blue = fail)');
    grid on;

    subplot(1,2,2);
    diffLD = results.CLLDgrid' - results.CLreqLDgrid';
    contourf(deltaSweep, deltaSweep, diffLD, 20);
    hold on;
    contour(deltaSweep, deltaSweep, diffLD, [0 0], 'r-', 'LineWidth', 2);
    colorbar;
    xlabel('Flap Deflection (deg)');
    ylabel('Slat Deflection (deg)');
    title('Landing: CL - CL_{req} (red = boundary, blue = fail)');
    grid on;

    sgtitle(sprintf('High-Lift Trade Study: c_f/c_{flap}=%.2f, c_f/c_{slat}=%.2f', ...
        ac.flap.cfOverC, ac.slat.cfOverC));

    %% Spanwise Loading: Best Configuration
    bestTO = results.bestTO;
    bestLD = results.bestLD;

    if ~isempty(bestTO) && ~isempty(bestLD)
        figure;

        subplot(1,2,1);
        plot(clean.etaTO, VSP.clDistroSpanTO, 'b-', 'LineWidth', 1.5); hold on;
        plot(clean.etaTO, bestTO.modTO, 'r-', 'LineWidth', 1.5);
        xlabel('\eta = 2y/b');
        ylabel('c_l \cdot c/c_{ref}');
        title(sprintf('Takeoff: \\delta_f=%d°, \\delta_s=%d°', bestTO.df, bestTO.ds));
        legend('Clean at stall \alpha', 'With Flaps+Slats');
        grid on;

        subplot(1,2,2);
        plot(clean.etaTO, VSP.clDistroSpanLD, 'b-', 'LineWidth', 1.5); hold on;
        plot(clean.etaLD, bestLD.modLD, 'r-', 'LineWidth', 1.5);
        xlabel('\eta = 2y/b');
        ylabel('c_l \cdot c/c_{ref}');
        title(sprintf('Landing: \\delta_f=%d°, \\delta_s=%d°', bestLD.df, bestLD.ds));
        legend('Clean at stall \alpha', 'With Flaps+Slats');
        grid on;

        sgtitle('Spanwise Loading: Clean vs Modified');
    end

end
