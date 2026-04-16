function [clean] = ComputeCleanWing(VSP, ac, sectionEta)
% COMPUTECLEANWING  Compute clean wing lift characteristics from OpenVSP data.
%
%   clean = ComputeCleanWing(VSP, ac, sectionEta)
%
%   Inputs:
%     VSP        — struct from ReadFileAero (contains cl distributions, geometry)
%     ac         — aircraft config struct from AircraftConfig
%     sectionEta — cumulative eta breakpoints for wing sections
%
%   Outputs:
%     clean.CL_TO       — Clean wing CL at takeoff alpha
%     clean.CL_LD       — Clean wing CL at landing alpha
%     clean.CLalpha_W   — Wing lift curve slope [per rad]
%     clean.CLmax_W     — Clean wing max CL (from spanwise tangency)
%     clean.alphaStall  — Stall angle [deg] (min of local stall angles)
%     clean.stallEta    — Eta location where stall first occurs
%     clean.etaTO       — Eta distribution at takeoff
%     clean.etaLD       — Eta distribution at landing

    aoaTO = ac.aoa.takeoff;
    aoaLD = ac.aoa.landing;

    %% Eta distributions
    clean.etaTO = ComputeEta(VSP.avgSpanLocTO, VSP.b);
    clean.etaLD = ComputeEta(VSP.avgSpanLocLD, VSP.b);

    %% Clean wing CL at TO and LD angles
    clean.CL_TO = ComputeCL(VSP.b, VSP.sRef, ...
        VSP.clDistroSpanTO(:), clean.etaTO(:), VSP.cRef);

    clean.CL_LD = ComputeCL(VSP.b, VSP.sRef, ...
        VSP.clDistroSpanLD(:), clean.etaLD(:), VSP.cRef);

    %% Wing lift curve slope
    clean.CLalpha_W = abs(clean.CL_TO - clean.CL_LD) ...
                    / (abs(aoaTO - aoaLD) * (pi/180));

    %% Spanwise cl_max mapping
    nStations = length(clean.etaTO);
    clMaxEta = zeros(nStations, 1);

    for k = 1:nStations
        idx = find(clean.etaTO(k) <= sectionEta, 1, 'first');
        if isempty(idx)
            idx = length(sectionEta);
        end
        clMaxEta(k) = ac.airfoils.clMax(idx);
    end

    %% Local stall angle at each station (Roskam Sec. 8.1.3.4)

    alphaStallLocal = aoaTO + ...
        (clMaxEta - VSP.clTO(:)) ./ (clean.CLalpha_W * (pi/180));

    wingletEta = sectionEta(end-1);
    wingMask   = clean.etaTO(:) <= wingletEta;
    alphaStallWing = alphaStallLocal(wingMask);

    clean.alphaStall = min(alphaStallWing);
    [~, stallIdx]    = min(alphaStallWing);
    etaWing          = clean.etaTO(wingMask);
    clean.stallEta   = etaWing(stallIdx);

    % Diagnostic: show the local stall analysis at a few stations
    fprintf('  [ComputeCleanWing] Local stall analysis (sampled stations)\n');
    fprintf('    Station   eta      cl_max_local  cl_TO    alpha_stall_local\n');
    fprintf('    -------   ------   -----------   ------   -----------------\n');
    sampleK = round(linspace(1, nStations, min(8, nStations)));
    
    for kk = sampleK
        tag = '';
        if clean.etaTO(kk) > wingletEta
            tag = ' (winglet — excluded)';
        end
        fprintf('    %3d       %.4f   %.4f        %.4f   %.2f deg%s\n', ...
            kk, clean.etaTO(kk), clMaxEta(kk), VSP.clTO(kk), ...
            alphaStallLocal(kk), tag);
    end
    
    fprintf(['    Winglet excluded: stations with eta > %.4f ' ...
        'are not stall-limiting\n'], wingletEta);
    fprintf('    Min local alpha_stall (lifting wing) = %.2f deg at eta=%.4f\n', ...
        clean.alphaStall, clean.stallEta);
    fprintf('    Using alpha_stall = %.2f deg (computed from geometry)\n', ...
        clean.alphaStall);

    %% CLmax via spanwise loading at stall angle
    clAtStall = VSP.clTO + ...
        clean.CLalpha_W * (clean.alphaStall - aoaTO) * (pi/180);

    clAtStall_ccref = clAtStall .* (VSP.cDistro ./ VSP.cRef);

    clean.CLmax_W = ComputeCL(VSP.b, VSP.sRef, ...
        clAtStall_ccref(:), clean.etaTO(:), VSP.cRef);

end
