function [roskam] = LoadRoskamData()
% LOADROSKAMDATA  Load all digitized empirical data from Roskam Part VI Ch.8.
%
%   roskam = LoadRoskamData()
%
%   Returns a struct with fields for each figure/table:
%     roskam.fig817  — Fowler flap alpha_delta vs deflection (Eq 8.6)
%     roskam.fig826  — Slat cl_delta vs cf/c (Eq 8.15)
%     roskam.fig831  — Base airfoil delta_cl_max vs t/c (Eq 8.18)
%     roskam.fig832  — k1 correction for cf/c
%     roskam.fig833  — k2 correction for deflection
%     roskam.fig834  — k3 correction for deflection ratio
%     roskam.fig835  — LE slat cl_delta_max vs cf/c (Eq 8.19)
%     roskam.fig836  — eta_max vs LE radius/t*c
%     roskam.fig837  — eta_delta vs slat deflection
%     roskam.fig853  — 3D (alpha_delta)_CL/(alpha_delta)_cl vs AR (Eq 8.27)
%
%   All data is raw digitized points. Interpolation to design conditions
%   is done downstream.

    %% Figure 8.53 — 3D flap effectiveness ratio vs AR
    %  (alpha_delta)_CL / (alpha_delta)_cl, parameterized by (alpha_delta)_cl
    %  Used in Eq 8.27 for wing-level lift increment

    % alpha_delta_cl at which each curve was read
    fig853.alphaDeltaCl_curves = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];

    % Mapping from cf/c to alpha_delta_cl (x-axis of the lookup)
    fig853.cfOverC      = [0.00, 0.05, 0.10, 0.20, 0.25, 0.40, 0.45, 0.60, 0.80, 1.00];
    fig853.alphaDeltaCl = [0.00, 0.20, 0.40, 0.55, 0.60, 0.75, 0.80, 0.90, 0.95, 1.00];

    % Each row: {AR_points, ratio_points} for one alpha_delta_cl curve
    fig853.AR_raw = { ...
        [1.416, 1.645, 2.014, 2.400, 2.892, 3.628, 4.766, 6.516, 8.020, 9.996], ...     % 0.1
        [0.577, 0.701, 0.843, 1.107, 1.493, 2.002, 2.755, 3.998, 6.010, 8.022, 10.015], ... % 0.2
        [0.280, 0.316, 0.406, 0.530, 0.759, 1.110, 1.654, 2.565, 4.000, 6.029, 8.023, 10.016], ... % 0.3
        [0.054, 0.126, 0.215, 0.357, 0.603, 0.989, 1.603, 2.689, 4.018, 6.012, 8.006, 10.016], ... % 0.4
        [0.023, 0.129, 0.253, 0.500, 0.921, 1.815, 3.005, 4.019, 5.034, 6.030, 8.041, 9.999], ... % 0.5
        [0.009, 0.168, 0.467, 1.028, 2.026, 3.040, 5.016, 8.006, 10.017], ...             % 0.6
        [-0.007, 0.100, 0.521, 1.781, 4.020, 6.013, 8.007, 10.000], ...                   % 0.7
        [-0.004, 0.977, 2.027, 5.017, 8.007, 9.982], ...                                  % 0.8
        [-0.002, 1.013, 2.587, 6.014, 10.017] ...                                         % 0.9
    };

    fig853.ratio_raw = { ...
        [2.000, 1.903, 1.802, 1.700, 1.603, 1.501, 1.404, 1.305, 1.250, 1.203], ...
        [2.000, 1.903, 1.802, 1.702, 1.601, 1.501, 1.405, 1.302, 1.201, 1.158, 1.138], ...
        [2.000, 1.901, 1.797, 1.700, 1.600, 1.501, 1.402, 1.302, 1.203, 1.145, 1.111, 1.095], ...
        [1.903, 1.801, 1.700, 1.601, 1.499, 1.402, 1.302, 1.203, 1.147, 1.102, 1.078, 1.066], ...
        [1.700, 1.600, 1.503, 1.405, 1.305, 1.203, 1.133, 1.106, 1.083, 1.072, 1.056, 1.049], ...
        [1.499, 1.404, 1.302, 1.201, 1.135, 1.095, 1.060, 1.036, 1.032], ...
        [1.402, 1.305, 1.201, 1.101, 1.051, 1.034, 1.024, 1.022], ...
        [1.201, 1.099, 1.058, 1.022, 1.017, 1.010], ...
        [1.104, 1.048, 1.022, 1.010, 1.005] ...
    };

    % Build interpolation grid on common AR range
    fig853.AR_common = linspace(1, 20, 100);
    nCurves = length(fig853.alphaDeltaCl_curves);
    nAR     = length(fig853.AR_common);

    ratioTable = zeros(nCurves, nAR);
    for i = 1:nCurves
        ar = fig853.AR_raw{i};
        ar(ar < 0.01) = 0.01;
        ratioTable(i, :) = interp1(ar, fig853.ratio_raw{i}, ...
            fig853.AR_common, 'linear', 'extrap');
    end
    ratioTable(ratioTable < 1.0) = 1.0;

    [fig853.AR_grid, fig853.alphaDeltaCl_grid] = ...
        meshgrid(fig853.AR_common, fig853.alphaDeltaCl_curves);
    fig853.ratio_grid = ratioTable;

    roskam.fig853 = fig853;

    %% Figure 8.17 — Fowler flap alpha_delta vs deflection
    %  alpha_delta(cf/c, delta_f) for Eq 8.6: dcl = cl_alpha * alpha_delta * c'/c * delta_f

    fig817.delta_f = [0, 5, 10, 15, 20, 25, 30, 35, 40];  % deg
    fig817.cfOverC = [0.15, 0.20, 0.25, 0.30, 0.40];

    fig817.alphaDelta = [ ...  % rows = cf/c, cols = delta_f
        0.38, 0.38, 0.38, 0.37, 0.36, 0.35, 0.32, 0.30, 0.27;  % cf/c = 0.15
        0.45, 0.45, 0.44, 0.43, 0.42, 0.41, 0.39, 0.36, 0.33;  % cf/c = 0.20
        0.52, 0.52, 0.51, 0.50, 0.49, 0.48, 0.46, 0.43, 0.39;  % cf/c = 0.25
        0.55, 0.55, 0.54, 0.53, 0.52, 0.51, 0.50, 0.48, 0.44;  % cf/c = 0.30
        0.60, 0.60, 0.60, 0.59, 0.58, 0.57, 0.55, 0.52, 0.49;  % cf/c = 0.40
    ];

    roskam.fig817 = fig817;

    %% Figure 8.26 — Slat cl_delta vs cf/c
    %  cl_delta(cf/c) for Eq 8.15: dcl = cl_delta * delta_s * c'/c

    fig826.cfOverC  = [0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50];
    fig826.clDelta  = [0, 0.0005, 0.0015, 0.0028, 0.0045, 0.0065, 0.0088, ...
                       0.0112, 0.0138, 0.0160, 0.0185];  % per degree as digitized
    % Convert to per radian for use in equations
    fig826.clDelta_per_rad = fig826.clDelta * (180/pi);

    roskam.fig826 = fig826;

    %% Figures 8.31–8.34 — TE flap delta_cl_max (Eq 8.18)
    %  delta_cl_max = k1 * k2 * k3 * (delta_cl_max)_base

    % Figure 8.31 — Base airfoil delta_cl_max vs thickness ratio
    fig831.tc_pct    = [0.048, 1.057, 2.065, 3.016, 3.995, 5.032, 5.982, ...
                        6.960, 7.967, 8.974, 9.979, 10.956, 11.932, 12.966, ...
                        13.940, 14.945, 15.950, 16.927, 17.877, 18.856, 19.864];
    fig831.dclmax    = [1.008, 1.006, 1.009, 1.015, 1.029, 1.049, 1.070, ...
                        1.096, 1.136, 1.176, 1.236, 1.310, 1.373, 1.462, ...
                        1.565, 1.657, 1.731, 1.785, 1.808, 1.823, 1.829];
    roskam.fig831 = fig831;

    % Figure 8.32 — k1 correction for flap chord ratio
    fig832.cfOverC_pct = [0, 28];   % cf/c in percent
    fig832.k1          = [0, 1.2];
    roskam.fig832 = fig832;

    % Figure 8.33 — k2 correction for flap deflection
    fig833.delta_f = [0.29,  4.95,  10.11, 15.17, 20.13, 25.10, ...
                      29.98, 35.26, 39.87, 49.79, 59.51];
    fig833.k2      = [0.405, 0.511, 0.612, 0.706, 0.802, 0.877, ...
                      0.942, 0.985, 1.000, 1.000, 1.000];
    roskam.fig833 = fig833;

    % Figure 8.34 — k3 correction for deflection/reference ratio
    fig834.deltaRatio = [0.005, 0.107, 0.208, 0.310, 0.405, 0.507, ...
                         0.608, 0.715, 0.845, 1.000];
    fig834.k3         = [0.005, 0.138, 0.262, 0.384, 0.504, 0.607, ...
                         0.703, 0.799, 0.899, 0.995];
    fig834.deltaRef   = 40.0;  % reference deflection for k3
    roskam.fig834 = fig834;

    %% Figures 8.35–8.37 — LE slat delta_cl_max (Eq 8.19)
    %  delta_cl_max = cl_delta_max * eta_max * eta_delta * delta_s * c'/c

    % Figure 8.35 — Theoretical max lift effectiveness vs cf/c
    fig835.cfOverC     = [0.000, 0.005, 0.014, 0.029, 0.046, 0.072, 0.101, ...
                          0.145, 0.200, 0.252, 0.303, 0.353, 0.400, 0.428, 0.499];
    fig835.clDeltaMax  = [0.000, 0.208, 0.408, 0.612, 0.801, 1.001, 1.205, ...
                          1.406, 1.603, 1.740, 1.835, 1.904, 1.942, 1.965, 2.000];
    roskam.fig835 = fig835;

    % Figure 8.36 — Empirical correction eta_max vs LE radius parameter
    fig836.LER_tc  = [0.001, 0.020, 0.040, 0.060, 0.076, 0.077, 0.088, ...
                      0.100, 0.116, 0.136, 0.158, 0.179, 0.199];
    fig836.etaMax  = [0.565, 0.770, 0.994, 1.206, 1.393, 1.706, 1.750, ...
                      1.718, 1.603, 1.409, 1.208, 1.007, 0.802];
    roskam.fig836 = fig836;

    % Figure 8.37 — Empirical correction eta_delta vs slat deflection
    fig837.delta_s  = [0.097,  5.046,  9.995, 14.871, 17.496, 19.977, ...
                       23.264, 25.091, 29.257, 35.031, 38.906, 40.077];
    fig837.etaDelta = [1.002,  1.002,  1.003,  1.000,  0.966,  0.909, ...
                       0.808,  0.751,  0.608,  0.407,  0.255,  0.206];
    roskam.fig837 = fig837;

end
