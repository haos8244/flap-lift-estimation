function [CL] = CLtoWeight(weight, density, V, sRef, pitchAngle)
    CL = (2.0 * weight) ...
        / (density * ((V*1.687811)^2) * sRef * cos(pitchAngle*(pi/180)));
end