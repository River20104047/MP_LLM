function [Hpk_output, Sns_output, SNR_output, XYbc_output] = DSWk_Method_f01(XY, lbws, kmax, ck)
    % DSWk_Method Performs the DSW^k baseline correction method.
    % Make sure the following Matlab functions are in the same directory:
    % Function_DSW_f05 Function_PeakIdentify_f4

    % 2024/04/10 Breated by Zijiang Yang

    % Inputs:
    %   XY - n x 2 matrix with first column as wavenumber and second as intensity
    %   lbws - Window size for DSW method
    %   kmax - Number of iterations of DSW to perform
    %   ck - Check parameter to visualize the first and the k-th corrected spectra
    %
    % Outputs:
    %   Hpk_output - Estimated peak height
    %   Sns_output - Estimated standard deviation of noise
    %   SNR_output - Estimated signal-to-noise ratio
    %   XYbc_output - Corrected baseline after the first iteration

    % Initial data to start with
    XY_current = XY;  

    % Iteration for k-times
    for k = 1:1:kmax
        if k == 1 && ck == 1
            ck1 = 1;
        elseif k == kmax && ck == 1
            ck1 = 1;
        else
            ck1 = 0;
        end

        [snr_hat,XYbc,~,~] = Function_DSW_f05(XY_current, lbws, 5, ck1); % wsf = 5 as default

        snr_hats(k,:) = snr_hat';
        XY_current = XYbc;

        if k == 1
            XYbc_1 = XYbc;
        end
    end

    % Organize results
    Hpk_output = snr_hats(1,1);               % Estimated peak height
    Sns_output = snr_hats(kmax,2);            % Estimated std of noise
    SNR_output = Hpk_output / Sns_output;     % Estimated SNR
    XYbc_output = XYbc_1;                     % Corrected baseline
end
