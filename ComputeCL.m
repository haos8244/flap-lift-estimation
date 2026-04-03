function [CLwholeWing] = ComputeCL(b, sRef, clDistroSpan, etaDistro, cref)
    CLwholeWing = ((b * cref) / sRef) * trapz(etaDistro, clDistroSpan);
end