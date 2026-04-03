function [fileData] = ReadFileAero(filelocation, aoaTO, aoaLD)

    T = readtable(filelocation);

    fileData = struct(...
        'clDistroSpanTO', 0, ...
        'avgSpanLocTO', 0, ...
        'AvgXLocTO', 0, ...
        'clDistroSpanLD', 0, ...
        'avgSpanLocLD', 0, ...
        'AvgXLocLD', 0, ...
        'cDistro', 0, ...
        'cRef', 0, ...
        'b', 0, ...
        'sRef', 0 ...
    );

    fileData.clDistroSpanTO = BasicReferenceValues(T, aoaTO, 'cl*c/cref');
    fileData.avgSpanLocTO   = BasicReferenceValues(T, aoaTO, 'Yavg');
    fileData.avgXLocTO      = BasicReferenceValues(T, aoaTO, 'Xavg');
    fileData.clDistroSpanLD = BasicReferenceValues(T, aoaLD, 'cl*c/cref');
    fileData.avgSpanLocLD   = BasicReferenceValues(T, aoaLD, 'Yavg');
    fileData.avgXLocLD      = BasicReferenceValues(T, aoaLD, 'Xavg');
    fileData.cDistro        = BasicReferenceValues(T, aoaTO, 'Chord');
    fileData.cRef           = BasicReferenceValues(T, aoaTO, 'FC_Cref_');
    fileData.b              = BasicReferenceValues(T, aoaTO, 'FC_Bref_');
    fileData.sRef           = BasicReferenceValues(T, aoaTO, 'FC_Sref_');

    return;

end

function [values] = BasicReferenceValues(table, aoaValue, varName)

    collectionName = "Results_Name";
    collectionRow  = "VSPAERO_Load";
    
    sectionStarts = find( ...
        strcmp(table.Results_Name, collectionName) & ...
        strcmp(table.Var2, collectionRow) ...
    );
    
    if isempty(sectionStarts)
        error('No "%s" section found in "%s".', ...
            collectionRow, collectionName ...
        );
    end
    
    allHeaders = find(strcmp(table.Results_Name, collectionName));
    
    for i = 1:length(sectionStarts)
        
        sectionStartRow = sectionStarts(i);
        
        headersAfterCurrent = allHeaders(allHeaders > sectionStartRow);
        
        if isempty(headersAfterCurrent)
            sectionEndRow = height(table);
        else
            sectionEndRow = headersAfterCurrent(1) - 1;
        end
        
        sectionBlock = table(sectionStartRow+1:sectionEndRow, :);
        
        aoaRow = find(strcmp(sectionBlock.Results_Name, "FC_AoA_"));
        
        if ~isempty(aoaRow) && ...
                str2double(sectionBlock.Var2(aoaRow)) == aoaValue
            
            varRow = find(strcmp(sectionBlock.Results_Name, varName));
            
            if isempty(varRow)
                error('Variable "%s" not found in matching block.', ...
                    varName ...
                );
            end
            
            values = sectionBlock{varRow, 2:end};
            values = cellfun(@str2double, values);
            values = values(~isnan(values));

            if isempty(values) || all(values == 0)
                error('"%s" contains no numeric data.', varName);
            end
            
            return;
        end
    end
    
    error('No block found with FC_AoA_ == %g', aoaValue);

end