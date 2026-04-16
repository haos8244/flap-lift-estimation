function [modifiedClDistro] = ModifiedCLDistro( ...
    clDistroSpan, etaDistro, sectionEta, deviceCfg)
% MODIFIEDCLDISTRO  Add flap and slat Dcl increments to a spanwise loading.
%
%   modifiedClDistro = ModifiedCLDistro(clDistroSpan, etaDistro, sectionEta, cfg)
%
%   Applies Roskam Eq 8.6 (Fowler flap) and Eq 8.15 (slat) increments to
%   the OpenVSP cl*c/cref distribution at each spanwise station.
%
%   Inputs:
%     clDistroSpan  — baseline cl*c/cref distribution [nStations x 1]
%     etaDistro     — eta = 2y/b at each station [nStations x 1]
%     sectionEta    — cumulative eta breakpoints for wing sections
%     deviceCfg     — struct with fields:
%       .clAlphaDistro      — cl_alpha per section [nSections x 1]
%       .CLalpha_W          — wing lift curve slope [per rad]
%       .etaBeginFlap       — inboard flap eta
%       .etaEndFlap         — outboard flap eta
%       .etaBeginSlat       — inboard slat eta
%       .etaEndSlat         — outboard slat eta
%       .alphaDelta         — alpha_delta for this flap deflection (scalar)
%       .cPrimeOverC_flap   — c'/c for this flap deflection (scalar)
%       .delta_f            — flap deflection [deg]
%       .hingeLineSweep     — local hinge-line sweep [nStations x 1] [deg]
%       .cOverCref          — c/cref at each station [nStations x 1]
%       .clDelta_slat       — slat cl_delta [per rad]
%       .delta_s            — slat deflection [deg]
%       .cPrimeOverC_slat   — c'/c for this slat deflection (scalar)
%       .leadingEdgeSweep   — local LE sweep [nStations x 1] [deg]
%       .alphaDeltaRatio3D_flap — Fig 8.53 3D correction for flaps
%       .alphaDeltaRatio3D_slat — Fig 8.53 3D correction for slats

    modifiedClDistro = clDistroSpan;

    for k = 1:length(etaDistro)

        etaK = etaDistro(k);
        sectionIdx = find(etaK <= sectionEta, 1, 'first');
        if isempty(sectionIdx)
            sectionIdx = length(sectionEta);
        end

        clAlphaK = deviceCfg.clAlphaDistro(sectionIdx);

        % Ratio of wing CL_alpha to section cl_alpha (Eq 8.27 factor)
        clAlphaEffectRatio = deviceCfg.CLalpha_W / clAlphaK;

        % --- Trailing Edge Flap (Eq 8.6) ---
        if etaK >= deviceCfg.etaBeginFlap && etaK <= deviceCfg.etaEndFlap

            % dcl = cl_alpha * alpha_delta * c'/c * delta_f [rad]
            %       * (CL_alpha_W / cl_alpha) * (alpha_delta)_CL/(alpha_delta)_cl
            dclFlap = clAlphaK ...
                    * deviceCfg.alphaDelta ...
                    * deviceCfg.cPrimeOverC_flap ...
                    * (deviceCfg.delta_f * pi / 180) ...
                    * clAlphaEffectRatio ...
                    * deviceCfg.alphaDeltaRatio3D_flap;

            modifiedClDistro(k) = modifiedClDistro(k) ...
                + dclFlap * cosd(deviceCfg.hingeLineSweep(k)) ...
                          * deviceCfg.cOverCref(k);
        end

        % --- Leading Edge Slat (Eq 8.15) ---
        if etaK >= deviceCfg.etaBeginSlat && etaK <= deviceCfg.etaEndSlat

            % dcl = cl_delta * delta_s [rad] * c'/c
            %       * (CL_alpha_W / cl_alpha) * (alpha_delta)_CL/(alpha_delta)_cl
            dclSlat = deviceCfg.clDelta_slat ...
                    * (deviceCfg.delta_s * pi / 180) ...
                    * deviceCfg.cPrimeOverC_slat ...
                    * clAlphaEffectRatio ...
                    * deviceCfg.alphaDeltaRatio3D_slat;

            modifiedClDistro(k) = modifiedClDistro(k) ...
                + dclSlat * cosd(deviceCfg.leadingEdgeSweep(k)) ...
                          * deviceCfg.cOverCref(k);
        end
    end

end
