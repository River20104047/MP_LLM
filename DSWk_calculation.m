%% Load and pre-processing data

Tdat     = readtable(filename);

dat      = Tdat{:,:};
X        = dat(:,1);
Y        = dat(:,2:end);

% Initialize waitbar
h        = waitbar(0, 'マナを集めています...'); % "Preparing magic..."
imax     = width(Y);


% Apply DSW^k method
Hpk      = NaN(imax,1);         % peak height
Sns      = NaN(imax,1);         % std of noise
SNR      = NaN(imax,1);         % signal-to-noise ratio
Ybc      = NaN(height(Y),imax); % baseline corrected Y

for i = 1:1:imax
    
    % prepare for spectrum
    Yi   = Y(:,i);
    XYi  = [X Yi];
    
    % apply DSW^k method
    [Hpk_output, Sns_output, SNR_output, XYbc_output] = DSWk_Method_f01(XYi, lws, kmax, ck);

    % organize results
    Hpk(i)      = Hpk_output;
    Sns(i)      = Sns_output;
    SNR(i)      = SNR_output;
    Ybc(:,i)    = XYbc_output(:,2);

    % Message
    currentTime = datetime('now', 'Format', 'HH:mm:ss'); % Get current time with specified format
    progressPercentage = (i / imax) * 100; % Calculate progress as a percentage

    % Construct message string with a magical theme and include progress percentage
    message = sprintf('詠唱進度: %.2f%% | 現在時刻: %s', progressPercentage, currentTime); % "Chanting progress: [percentage]% | Current time: %s"
    disp(message); % Display the message

    % Update waitbar with current progress and a magical theme, including progress percentage
    waitbar(i/imax, h, sprintf('呪文を唱えています: %.2f%% (%d / %d)', progressPercentage, i, imax)); % "Casting spell: [percentage]% (%d of %d)"


end

XYbc = [X Ybc];

% Organize results

% Baseline corrected spectra
T_XYbc = array2table(XYbc);
T_XYbc.Properties.VariableNames = Tdat.Properties.VariableNames;

% Spectral properties
T_HSS = array2table([Hpk'; Sns'; SNR']);
T_HSS.Properties.VariableNames = Tdat.Properties.VariableNames(2:end);

% Define the measurement descriptors
Measurements = {'peak height', 'std of noise', 'SNR'}';

% Ensure the table has enough rows for the descriptors
if size(T_HSS, 1) >= numel(Measurements)
    % Add the descriptors as a new column at the beginning of the table
    T_HSS = addvars(T_HSS, Measurements, 'Before', 1, 'NewVariableNames', 'Description');
else
    error('The table does not have enough rows for the specified descriptors.');
end

% % Export results
% 
% % Define the current time and filename for exporting
% currentTime = datetime('now', 'Format', 'MMddHHmmss');
% fileName = sprintf('DSWk_results_%s.xlsx', currentTime);
% 
% % Export T_XYbc to the 'XYbc' sheet
% writetable(T_XYbc, fileName, 'Sheet', 'XYbc');
% 
% % Export T_HSS to the 'SpecProperties' sheet, now with descriptions
% writetable(T_HSS, fileName, 'Sheet', 'SpecProperties');
% 
% % Notify the user of successful export
% fprintf('Tables exported to %s\n', fileName);

%
% Close the waitbar
close(h);
