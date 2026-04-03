function [degenData] = ReadFileGeom(filepath, componentName)
    
    lines = readlines(filepath);
    
    compLine = 0;
    for i = 1:length(lines)
        if contains(lines(i), componentName) && contains(lines(i), ',0,')
            compLine = i;
            break;
        end
    end
    
    stickLine = 0;
    for i = compLine:length(lines)
        if startsWith(strtrim(lines(i)), 'STICK_NODE')
            parts = split(lines(i), ',');
            nStations = str2double(strtrim(parts(2)));
            stickLine = i;
            break;
        end
    end
    
    dataStart = stickLine + 2; % +2 for column header and first data row
    dataEnd = dataStart + nStations - 1;
    
    dataBlock = lines(dataStart:dataEnd);
    data = zeros(nStations, 66);
    for i = 1:nStations
        data(i,:) = sscanf(dataBlock(i), '%f,')';
    end
    
    degenData.lex = data(:,1);
    degenData.ley = data(:,2);
end