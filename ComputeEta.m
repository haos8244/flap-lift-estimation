function [ndEtaScaling] = ComputeEta(avgSpanLoc, b)
    ndEtaScaling = (2.0 .* avgSpanLoc) ./ b;
end