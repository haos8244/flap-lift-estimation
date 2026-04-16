function PlotConfig(results, VSP, ac, clean, df, ds)
    deltaSweep = results.deltaSweep;
    iFlap = find(deltaSweep == df, 1);
    iSlat = find(deltaSweep == ds, 1);

    if isempty(iFlap) || isempty(iSlat)
        fprintf('Invalid deflection. df and ds must be in 0:1:40.\n');
        return;
    end

    modTO = results.modTOall(:, iFlap, iSlat);
    modLD = results.modLDall(:, iFlap, iSlat);

    CLTO = results.CLTOgrid(iFlap, iSlat);
    CLLD = results.CLLDgrid(iFlap, iSlat);
    CLreqTO = results.CLreqTOgrid(iFlap, iSlat);
    CLreqLD = results.CLreqLDgrid(iFlap, iSlat);

    figure;

    subplot(1,2,1);
    plot(clean.etaTO, VSP.clDistroSpanTO, 'b-', 'LineWidth', 1.5); hold on;
    plot(clean.etaTO, modTO, 'r-', 'LineWidth', 1.5);
    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('Takeoff: \\delta_f=%d°, \\delta_s=%d°', df, ds));
    legend('Clean', 'With Flaps+Slats', 'Location', 'best');
    grid on;

    subplot(1,2,2);
    plot(clean.etaLD, VSP.clDistroSpanLD, 'b-', 'LineWidth', 1.5); hold on;
    plot(clean.etaLD, modLD, 'r-', 'LineWidth', 1.5);
    xlabel('\eta = 2y/b');
    ylabel('c_l \cdot c/c_{ref}');
    title(sprintf('Landing: \\delta_f=%d°, \\delta_s=%d°', df, ds));
    legend('Clean', 'With Flaps+Slats', 'Location', 'best');
    grid on;

    sgtitle(sprintf('df=%d°, ds=%d° | CL_{TO}=%.4f (req %.4f) | CL_{LD}=%.4f (req %.4f)', ...
        df, ds, CLTO, CLreqTO, CLLD, CLreqLD));
end