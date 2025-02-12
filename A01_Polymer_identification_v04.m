%% This is used to apply DSW^k method for apply DSW for csv data
% 2024/04/11 v01 Created by Zijiang Yang
% 2025/01/30 v02 Modified for auto-identification data analysis
% 2025/02/03 v03 Call API to use LLM
% 2025/02/04 v04 Formatted LLM response


%% Prepare workspace
clc, clear, close all

tic

%% Adjustable Input Parameters
params.lws  = 25;  % Window size
params.kmax = 1;   % Number of iterations (20 is good for sigma estimation)
params.ck   = 0;   % Checking
params.ys   = 0.1; % Threshold for cutting signal below a value (normalized signal)

%% Filenames for Standard and Sample Data
filename_std = "[std data]";
filename_smp = "[sample data]";

% Store filenames and labels in separate arrays
filenames = {filename_std, filename_smp};

%% Loop Over Each Dataset
for f = 1:length(filenames)
    filename = filenames{f}; % Get the current dataset filename
    fprintf('Processing: %s\n', filename);

    %% Baseline correction
    lws = params.lws;
    kmax = params.kmax;
    ck = params.ck;
    DSWk_calculation 

    %% Spectral Processing
    Ybc_n  = (Ybc - min(Ybc)) ./ (max(Ybc) - min(Ybc));
    XYbc_n = [X Ybc_n];

    % Find indices where X is within the specified ranges
    condition_X = (X >= 650 & X <= 700) | ...
                  (X >= 2250 & X <= 2450) | ...
                  (X < 500) | (X > 4000);

    % Apply conditions and thresholding
    for j = 2:size(XYbc_n, 2) 
        condition_Y = XYbc_n(:, j) < params.ys; 
        XYbc_n(condition_X, j) = 0;
        XYbc_n(condition_Y, j) = 0;
    end

    % Normalize
    yn = XYbc_n(:,2:end);
    yn = (yn - min(yn)) ./ (max(yn) - min(yn));

    %% Peak Finder
    xhwpk_all = cell(1, width(yn));

    for i = 1:width(yn)
        y = yn(:, i);
        [hpk, xpk] = findpeaks(y, X, 'MinPeakProminence', 0.05, 'Annotate', 'extents'); 
        wpk = zeros(size(xpk));

        % Compute peak width
        for j = 1:length(xpk)
            peak_idx = round(interp1(X, 1:length(X), xpk(j), 'nearest'));

            left_idx = peak_idx;
            while left_idx > 1 && y(left_idx) > 0
                left_idx = left_idx - 1;
            end

            right_idx = peak_idx;
            while right_idx < length(y) && y(right_idx) > 0
                right_idx = right_idx + 1;
            end

            wpk(j) = X(right_idx) - X(left_idx);
        end

        % Store peaks
        xpk = round(xpk, 1);
        hpk = round(hpk, 2);
        wpk = round(wpk, 1);
        xhwpk_all{i} = [xpk hpk wpk];
    end

    %% Export
    timestamp = datestr(now, 'yymmdd_HHMMSS'); 
    excelFileName = sprintf('%s_peaks_%s.xlsx', filename, timestamp);

    % Extract variable names
    if exist('Tdat', 'var') && istable(Tdat)
        varNames = Tdat.Properties.VariableNames(2:end);
    else
        error('Tdat does not exist or is not a table.');
    end

    T_export = table();

    % Loop through each dataset and append to T_export
    for i = 1:length(xhwpk_all)
        if isempty(xhwpk_all{i})
            continue;
        end

        xpk = xhwpk_all{i}(:, 1);
        hpk = xhwpk_all{i}(:, 2);
        wpk = xhwpk_all{i}(:, 3);
        Name = repmat(varNames(i), size(xpk, 1), 1);
        T_tmp = table(Name, xpk, hpk, wpk, 'VariableNames', {'Name', 'xpk', 'hpk', 'wpk'});
        T_export = [T_export; T_tmp];
    end

    % Write to Excel
    writetable(T_export, excelFileName, 'Sheet', 'All_Data');
    fprintf('Data exported to %s\n', excelFileName);

    %% Generate Information Table
    T_info = T_export(:, {'Name', 'xpk', 'hpk'});

    % Store results
    T_info_all{f} = T_info;

    % Display Table
    fprintf('T_info for %s:\n', filename);
end

%% Summarize information
% Assign outputs to named variables
T_info_std = T_info_all{1};
T_info_smp = T_info_all{2};


%% Generate Prompt Table for T_info_std
% Get unique material names
uniqueNames = unique(T_info_std.Name);

% Initialize cell array for storing formatted prompts
prompts = cell(length(uniqueNames), 1);

% Loop through each unique material name
for i = 1:length(uniqueNames)
    % Extract rows corresponding to the current material
    nameFilter = strcmp(T_info_std.Name, uniqueNames{i});
    dataSubset = T_info_std(nameFilter, :);
    
    % Format peak data as a text string
    peakInfo = sprintf('%.1f (%.2f)', [dataSubset.xpk, dataSubset.hpk]');
    peakInfo = strjoin(split(peakInfo), ', ');  % Format as comma-separated string

    % Construct the prompt
    prompts{i} = sprintf('For standard sample of %s, the IR spectrum peaks (cm^-1) and normalized intensities are: %s.', uniqueNames{i}, peakInfo);
end

% Store results in a table
T_info_std_ppt = table(uniqueNames, prompts, 'VariableNames', {'Material', 'Prompt'});


%% Generate Prompt Table for T_info_smp
% Get unique sample names
uniqueSamples = unique(T_info_smp.Name);

% Initialize cell array for storing formatted prompts
prompts = cell(length(uniqueSamples), 1);

% Loop through each unique sample name
for i = 1:length(uniqueSamples)
    % Extract rows corresponding to the current environmental sample
    nameFilter = strcmp(T_info_smp.Name, uniqueSamples{i});
    dataSubset = T_info_smp(nameFilter, :);
    
    % Format peak data as a text string
    peakInfo = sprintf('%.1f (%.2f)', [dataSubset.xpk, dataSubset.hpk]');
    peakInfo = strjoin(split(peakInfo), ', ');  % Format as comma-separated string

    % Construct the prompt with environmental emphasis
    prompts{i} = sprintf('In environmental sample %s, IR spectral peaks (cm^-1) with normalized intensities were detected at: %s.', uniqueSamples{i}, peakInfo);
end

% Store results in a table
T_info_smp_ppt = table(uniqueSamples, prompts, 'VariableNames', {'Sample', 'Prompt'});


%% Generate Input Prompts for LLM
% Initialize cell array to store prompts
prompt_inputs = cell(height(T_info_smp_ppt), 1);

% Extract the reference polymer information (T_info_std_ppt)
knowledge_section = sprintf('Known polymer types and their IR spectral characteristics:\n\n');
for i = 1:height(T_info_std_ppt)
    knowledge_section = sprintf('%s- %s\n  %s\n\n', knowledge_section, T_info_std_ppt.Material{i}, T_info_std_ppt.Prompt{i});
end

% Loop through each environmental sample (one-by-one processing)
for i = 1:height(T_info_smp_ppt)
    
    % Extract sample-specific information
    sample_section = sprintf('Environmental sample information:\n%s\n%s\n', T_info_smp_ppt.Sample{i}, T_info_smp_ppt.Prompt{i});

    % Define Background
    background_section = 'Background:\nI am conducting microplastic analysis and would like to determine the polymer type of my environmental samples.\n\n';

    % Define Question with Emphasis on Knowledge Section
    question_section = ['Question:\n', ...
                        'Based on the provided reference data, determine if the environmental sample best matches any of the known polymer types.', ...
                        '- Your answer must be formatted as a structured response.', ...
                        '- Only consider polymer types listed in the knowledge section.', ...
                        '- Assign a value of 1 to the best-matching polymer type.', ...
                        '- Assign 0 to all other polymer types (use "=").',...
                        '- If no clear match is found, assign "None = 1".'];

    % Combine all sections to create the full input prompt
    prompt_input = sprintf('%s%s%s%s', background_section, knowledge_section, sample_section, question_section);
    
    % Store the generated prompt
    prompt_inputs{i} = prompt_input;
end

% Store the results in a table
T_prompt_inputs = table(T_info_smp_ppt.Sample, prompt_inputs, 'VariableNames', {'Sample', 'Prompt_Input'});

%% Define API endpoint
api_url = 'http://127.0.0.1:1234/api/v0/completions';

% Initialize response storage
responses = cell(height(T_prompt_inputs), 1); % Store LLM responses

%% Loop through each prompt and send to LLM
for i = 1:height(T_prompt_inputs)
    % Extract the current prompt
    prompt_text = T_prompt_inputs.Prompt_Input{i};

    % Construct request payload
    request_data = struct( ...
        'model', 'deepseek-r1-distill-llama-8b', ... % Model name
        'prompt', prompt_text, ... % The input prompt
        'max_tokens', -1, ... % Controls length of response (-1 for full output)
        'temperature', 0, ... % Controls randomness (0 = deterministic)
        'stream', false ... % Get response as full text (no streaming)
    );

    % Convert request data to JSON
    json_data = jsonencode(request_data);

    % Set up HTTP request options
    options = weboptions( ...
        'MediaType', 'application/json', ...
        'RequestMethod', 'post', ...
        'Timeout', 9999 ...
    );

    try
        % Send HTTP POST request to LLM API
        response = webwrite(api_url, json_data, options);

        % Extract LLM response text
        responses{i} = response.choices(1).text;

        % Display progress with current time
        fprintf('Processed Sample %d/%d: %s, Time: %s\n', i, height(T_prompt_inputs), T_prompt_inputs.Sample{i}, datestr(now, 'HH:MM:SS'));
    catch ME
        % Handle request failure (store error message)
        fprintf('Error processing Sample %d: %s\n', i, ME.message);
        responses{i} = 'Error: API request failed.';
    end
end

% Store results in a new table
T_LLM_responses = table(T_prompt_inputs.Sample, T_prompt_inputs.Prompt_Input, responses, ...
    'VariableNames', {'Sample', 'Prompt', 'LLM_Response'});

%% Define Output HTML File
timestamp = datestr(now, 'yymmdd_HHMMSS');
htmlFileName = sprintf('LLM_Responses_%s.html', timestamp);
fileID = fopen(htmlFileName, 'w');

% Write HTML Header
fprintf(fileID, '<html><head><meta charset="UTF-8"><title>LLM Responses</title></head><body>');
fprintf(fileID, '<h1>LLM Analysis Report</h1>');
fprintf(fileID, '<p>Generated on: %s</p>', timestamp);

% Loop Through Each Sample and Format as HTML
for i = 1:height(T_LLM_responses)
    fprintf(fileID, '<hr>'); % Separator line
    
    % Sample Name as Heading
    fprintf(fileID, '<h2>Sample: %s</h2>', T_LLM_responses.Sample{i});
    
    % Prompt Section
    fprintf(fileID, '<h3>Prompt:</h3><p>%s</p>', strrep(T_LLM_responses.Prompt{i}, '\n', '<br>')); 
    
    % LLM Response Section
    fprintf(fileID, '<h3>LLM Response:</h3>');

    % Convert **bold** markdown to <b>HTML Bold</b>
    responseText = T_LLM_responses.LLM_Response{i};
    responseText = regexprep(responseText, '\*\*(.*?)\*\*', '<b>$1</b>'); % Convert **bold** to <b>HTML</b>
    responseText = strrep(responseText, '\n', '<br>'); % Convert newlines to <br>
    
    fprintf(fileID, '<p>%s</p>', responseText);
end

% Close HTML Tags and File
fprintf(fileID, '</body></html>');
fclose(fileID);

% Confirm Export
fprintf('LLM responses saved to: %s\n', htmlFileName);


%% LLM
% Define known polymer types from T_info_std_ppt
polymer_types = ["PE", "PA", "PET", "PP", "PS", "PVC", "None"];

% Initialize an empty cell array to store classification results
classification_results = cell(height(T_LLM_responses), length(polymer_types) + 1);

% Loop through each LLM response
for i = 1:height(T_LLM_responses)
    % Extract the response text
    response_text = T_LLM_responses.LLM_Response{i};

    % Initialize default values (all polymers = 0, None = 0)
    polymer_values = zeros(1, length(polymer_types));

    % --- Extract from "PE = 1" format ---
    for j = 1:length(polymer_types)
        match = regexp(response_text, sprintf('%s\\s*=\\s*(\\d+)', polymer_types(j)), 'tokens', 'once');
        if ~isempty(match)
            polymer_values(j) = str2double(match{1});
        end
    end

    % --- Extract from JSON format { "PE": 1, "PA": 0, ... } ---
    json_match = regexp(response_text, '\{[^\}]+\}', 'match'); % Find JSON block
    if ~isempty(json_match)
        try
            json_data = jsondecode(json_match{1}); % Decode JSON
            % Loop through JSON data and extract values
            for j = 1:length(polymer_types)
                if isfield(json_data, polymer_types(j))
                    polymer_values(j) = json_data.(polymer_types(j));
                end
            end
        catch
            warning('Error parsing JSON format in sample %s', T_LLM_responses.Sample{i});
        end
    end

    % Store the results in the cell array
    classification_results(i, :) = [{T_LLM_responses.Sample{i}}, num2cell(polymer_values)];
end

% Convert to a MATLAB table
T_Classification = cell2table(classification_results, ...
    'VariableNames', ['Sample', polymer_types]);

% Suppose your original table is T_Classification
T_Classification_new = T_Classification;  % Work on a copy

% Extract the numeric array for columns 2..7 (PE, PA, PET, PP, PS, PVC)
M = T_Classification_new{:, 2:7};

% Compute the sum of these 6 columns per row
rowSum = sum(M, 2);

% Loop over each row to apply your rules
for i = 1:size(M, 1)
    
    if rowSum(i) == 0
        % Rule 2: If all non-last columns are 0, then None = 1
        T_Classification_new.None(i) = 1;
        
    else
        % Otherwise, if any of these columns are 1, then None = 0
        T_Classification_new.None(i) = 0;
        
        % Rule 3: If the sum of the non-last columns is > 1,
        % redistribute equally among the columns that were 1
        if rowSum(i) > 1
            idxOnes = (M(i,:) == 1);        % which columns are 1
            k = sum(idxOnes);              % how many columns are 1
            M(i, idxOnes) = 1 / k;         % redistribute so sum = 1
        end
    end
end

% Write the updated values back into the table
T_Classification_new{:, 2:7} = M;


% Display the processed classification table
disp(T_Classification_new);

% Generate timestamp for filename (format: yymmddHHMMSS)
timestamp = datestr(now, 'yymmddHHMMSS');

% Define the Excel filename with timestamp
excel_filename = sprintf('LLM_results_%s.xlsx', timestamp);

% Save the table to an Excel file
writetable(T_Classification_new, excel_filename, 'FileType', 'spreadsheet');

% Display confirmation message
fprintf('LLM results saved to: %s\n', excel_filename);


%%
% Measure elapsed time
elapsedTime = toc; % Stops the timer and returns elapsed time in seconds

% % Display a message box with the casting end notification and elapsed time
msg = sprintf('魔法の詠唱が完了しました。詠唱時間: %.2f 秒', elapsedTime);
msgbox(msg, '詠唱完了'); % "Casting Complete"

toc
