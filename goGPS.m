%--------------------------*--. --- --. .--. ...*---------------------------------------------
%
%                    %%%%%  %%%%%   %%%%%  %%%%% %%%%%
%                    %      %   %   %      %   % %
%                    %  %%% %   %   %  %%% %%%%% %%%%%
%                    %   %  %   %   %   %  %         %
%                    %%%%%  %%%%%   %%%%%  %     %%%%%
%
%
%----------------------------------------------------------------------------------------------
%                           goGPS v0.1 beta
%
% Copyright (C) 2009-2010 Mirko Reguzzoni*, Eugenio Realini**
%
% *  Laboratorio di Geomatica, Polo Regionale di Como, Politecnico di Milano, Italy
% ** Graduate School for Creative Cities, Osaka City University, Japan
%----------------------------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%---------------------------------------------------------------------------------------------

% clear all the variables in the workspace
clear all

% close all windows
close all

% clear the command prompt
%clc

% close all the opened files
fclose('all');

% disable warnings
warning off;

% start evaluating computation time
tic

%----------------------------------------------------------------------------------------------
% INTERFACE TYPE DEFINITION
%----------------------------------------------------------------------------------------------

mode_user = 1;  % user interface type
                % mode_user=0 --> use text interface
                % mode_user=1 --> use GUI

%----------------------------------------------------------------------------------------------
% INTERFACE STARTUP
%----------------------------------------------------------------------------------------------

%initialization of global variables/constants
global_init;

global o1 o2 o3 h_antenna

if (mode_user == 1)

    [mode, mode_vinc, mode_data, mode_ref, flag_ms_pos, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_amb, ...
        flag_skyplot, filerootIN, filerootOUT, filename_R_obs, filename_R_nav, filename_M_obs, filename_M_nav, ...
        filename_ref, pos_M_man] = goGPS_gui;

    if (isempty(mode))
        return
    end
else

    %-------------------------------------------------------------------------------------------
    % DEFINITION OF THE FUNCTIONING MODE (TEXTUAL INTERFACE)
    %-------------------------------------------------------------------------------------------

    mode =   1;       % functioning mode
                      % POST-PROCESSING
                      % mode=1  --> KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITH/WITHOUT A CONSTRAINT
                      % mode=2  --> KALMAN FILTER ON PHASE AND CODE, WITHOUT INTERNET CONNECTION AND WITHOUT A CONSTRAINT (to be implemented)
                      % mode=3  --> LEAST SQUARES ADJ. ON CODE DOUBLE DIFFERENCES, NO CONSTRAINT
                      % mode=4  --> LEAST SQUARES ADJ. ON CODE, NO CONSTRAINT
                      % mode=5  --> KALMAN FILTER ON CODE DOUBLE DIFFERENCES, NO CONSTRAINT
                      % mode=6  --> KALMAN FILTER ON CODE, NO CONSTRAINT
                      % mode=7  --> ....
                      % mode=8  --> ....
                      % mode=9  --> ....
                      % REAL-TIME
                      % mode=11 --> KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITH/WITHOUT A CONSTRAINT
                      % mode=12 --> U-BLOX MONITORING
                      % mode=13 --> MASTER MONITORING
                      % mode=14 --> ROVER AND MASTER MONITORING

    mode_vinc = 0;    % navigation mode
                      % mode_vinc=0 --> without linear constraint
                      % mode_vinc=1 --> with linear constraint

    mode_data = 1;    % data loading mode
                      % mode_data=0 --> RINEX data
                      % mode_data=1 --> goGPS binary data

    mode_ref = 0;     % reference path mode
                      % mode_ref=0 --> do not use a reference path
                      % mode_ref=1 --> use a reference path (plot it and use it for statistics)

    flag_ms_pos = 1; % read master station position from RTCM or RINEX header

    flag_ms = 0;      % plot master station position --> no=0, yes=1

    flag_ge = 0;      % use google earth --> no=0, yes=1

    flag_cov = 0;     % plot error ellipse --> no=0, yes=1

    flag_NTRIP = 1;   % use NTRIP --> no=0, yes=1

    flag_amb = 0;     % plot ambiguities (only in post-processing)

    flag_skyplot = 1; % draw skyplot and SNR graph (save CPU) --> no=0, yes=1

    %----------------------------------------------------------------------------------------------
    % USER-DEFINED SETTINGS
    %----------------------------------------------------------------------------------------------

    %User-defined global settings
    global_settings;

    %Check availability of Instrument Control Toolbox
    if (mode > 10)
        try
            instrhwinfo;
        catch
            error('Instrument Control Toolbox is needed to run goGPS in real-time mode.');
        end
    end

end

%-------------------------------------------------------------------------------------------
% REFERENCE PATH LOAD
%-------------------------------------------------------------------------------------------

if (mode_ref == 1)

    d = dir(filename_ref);

    if ~isempty(d)
        load(filename_ref, 'ref_path', 'mat_path');

        %adjust the reference path according to antenna height
        [ref_phi, ref_lam, ref_h] = cart2geod(ref_path(:,1),ref_path(:,2),ref_path(:,3));
        ref_h = ref_h + h_antenna;
        [ref_X, ref_Y, ref_Z] = geod2cart(ref_phi, ref_lam, ref_h, a, f);
        ref_path = [ref_X , ref_Y , ref_Z];

    else
        ref_path = [];
        mat_path = [];
    end

else
    ref_path = [];
    mat_path = [];
end

%----------------------------------------------------------------------------------------------
% FILE READING
%----------------------------------------------------------------------------------------------

if (mode < 10) %post-processing
    
    if (mode_data == 0)

        %read data from RINEX files
        [pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M, ...
            Eph_R, Eph_M, iono_R, iono_M, snr_R, snr_M, ...
            pr1_RR, pr1_MR, ph1_RR, ph1_MR, pr2_RR, pr2_MR, ph2_RR, ph2_MR, ...
            Eph_RR, Eph_MR, snr_RR, snr_MR, ...
            time_GPS, date, pos_M] = ...
            load_RINEX(filename_R_obs, filename_R_nav, filename_M_obs, filename_M_nav);

        %select ephemerides source
        %Eph = Eph_R;
        Eph = Eph_M;
        %Eph_GLO = Eph_MR;
        
        %select ionosphere parameters source
        iono = iono_R;

        %needed to write obs and eph files
        %time_R = time_GPS;
        %time_M = time_GPS;

        %remove satellites without ephemerides (GPS)
        delsat = setdiff(1:32,unique(Eph(1,:)));
        pr1_R(delsat,:) = 0;
        pr1_M(delsat,:) = 0;
        pr2_R(delsat,:) = 0;
        pr2_M(delsat,:) = 0;
        ph1_R(delsat,:) = 0;
        ph1_M(delsat,:) = 0;
        ph2_R(delsat,:) = 0;
        ph2_M(delsat,:) = 0;
        snr_R(delsat,:) = 0;
        snr_M(delsat,:) = 0;

        %%remove satellites without ephemerides (GLONASS)
        %delsat = setdiff(1:32,unique(Eph_GLO(1,:)));
        %pr1_RR(delsat,:) = 0;
        %pr1_MR(delsat,:) = 0;
        %pr2_RR(delsat,:) = 0;
        %pr2_MR(delsat,:) = 0;
        %ph1_RR(delsat,:) = 0;
        %ph1_MR(delsat,:) = 0;
        %ph2_RR(delsat,:) = 0;
        %ph2_MR(delsat,:) = 0;
        %snr_RR(delsat,:) = 0;
        %snr_MR(delsat,:) = 0;

        %%reverse the path (GPS)
        %pr1_R = pr1_R(:,end:-1:1);
        %pr1_M = pr1_M(:,end:-1:1);
        %ph1_R = ph1_R(:,end:-1:1);
        %ph1_M = ph1_M(:,end:-1:1);
        %pr2_R = pr2_R(:,end:-1:1);
        %pr2_M = pr2_M(:,end:-1:1);
        %ph2_R = ph2_R(:,end:-1:1);
        %ph2_M = ph2_M(:,end:-1:1);
        %snr_R = snr_R(:,end:-1:1);
        %snr_M = snr_M(:,end:-1:1);

        %%reverse the path (GLONASS)
        %pr1_RR = pr1_RR(:,end:-1:1);
        %pr1_MR = pr1_MR(:,end:-1:1);
        %ph1_RR = ph1_RR(:,end:-1:1);
        %ph1_MR = ph1_MR(:,end:-1:1);
        %pr2_RR = pr2_RR(:,end:-1:1);
        %pr2_MR = pr2_MR(:,end:-1:1);
        %ph2_RR = ph2_RR(:,end:-1:1);
        %ph2_MR = ph2_MR(:,end:-1:1);
        %snr_RR = snr_RR(:,end:-1:1);
        %snr_MR = snr_MR(:,end:-1:1);

        %time_GPS = time_GPS(end:-1:1);
        %date = date(end:-1:1,:);

    else %mode_data == 1

        %read data from goGPS saved files
        [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, snr_R, snr_M, ...
         pos_M, Eph, iono, delay, loss_R, loss_M] = load_goGPSinput(filerootIN);
        
        %remove epochs without ephemerides
        while (sum(Eph(:,:,1)) == 0)
            time_R(1)    = [];                         %GPS time
            time_M(1)    = [];                         %GPS time
            week_R(1)    = [];                         %GPS week
            pr1_R(:,1)   = [];                         %code observations
            pr1_M(:,1)   = [];                         %code observations
            ph1_R(:,1)   = [];                         %phase observations
            ph1_M(:,1)   = [];                         %phase observations
            snr_R(:,1)   = [];                         %signal-to-noise ratio
            snr_M(:,1)   = [];                         %signal-to-noise ratio
            pos_M(:,1)   = [];                         %master position
            Eph(:,:,1)   = [];                         %ephemerides
            iono(:,1)    = [];                         %ionosphere parameters
            delay(1)     = [];                         %delays
            loss_R(1)    = [];                         %rover losses
            loss_M(1)    = [];                         %master losses
        end

        %reference GPS time
        time_GPS = time_GPS(1) + (0 : 1 : length(time_M)-1)';

        %date
        date = datevec(time_R/(3600*24) + 7*week_R + datenum([1980,1,6,0,0,0]));

        %other variables
        pr2_M = zeros(size(pr1_M));
        pr2_R = zeros(size(pr1_R));
        ph2_M = zeros(size(ph1_M));
        ph2_R = zeros(size(ph1_R));

        %complete/partial path
        tMin = 1;
        tMax = 1e30;
        tMin = max(tMin,1);
        tMax = min(tMax,length(time_GPS));
        time_GPS = time_GPS(tMin:tMax);
        time_R = time_R(tMin:tMax);
        time_M = time_M(tMin:tMax);
        week_R = week_R(tMin:tMax);
        pr1_R = pr1_R(:,tMin:tMax);
        pr1_M = pr1_M(:,tMin:tMax);
        ph1_R = ph1_R(:,tMin:tMax);
        ph1_M = ph1_M(:,tMin:tMax);
        pr2_R = pr2_R(:,tMin:tMax);
        pr2_M = pr2_M(:,tMin:tMax);
        ph2_R = ph2_R(:,tMin:tMax);
        ph2_M = ph2_M(:,tMin:tMax);
        snr_R = snr_R(:,tMin:tMax);
        snr_M = snr_M(:,tMin:tMax);
        pos_M = pos_M(:,tMin:tMax);
        Eph = Eph(:,:,tMin:tMax);
        iono = iono(:,tMin:tMax);
        delay = delay(tMin:tMax);
        loss_R = loss_R(tMin:tMax);
        loss_M = loss_M(tMin:tMax);
        date = date(tMin:tMax,:);
    end
    
    %MASTER station position management
    if (flag_ms_pos) & (sum(abs(pos_M)) ~= 0)
        if (size(pos_M,2) == 1)
            pos_M(1,1:length(time_GPS)) = pos_M(1);
            pos_M(2,1:length(time_GPS)) = pos_M(2);
            pos_M(3,1:length(time_GPS)) = pos_M(3);
        end
    else
        pos_M(1,1:length(time_GPS)) = pos_M_man(1);
        pos_M(2,1:length(time_GPS)) = pos_M_man(2);
        pos_M(3,1:length(time_GPS)) = pos_M_man(3);
        fprintf('Warning: master position fixed to user-defined values:\n');
        fprintf(' X=%.4f m, Y=%.4f m, Z=%.4f m\n', pos_M_man(1,1), pos_M_man(2,1), pos_M_man(3,1));
    end

else %real-time

    %initialize master position variable
    if (flag_ms_pos)
        pos_M = [];
    else
        pos_M = pos_M_man;
    end
    
    %for the Kalman filter execution in real-time
    pr2_M = zeros(32,1);
    pr2_R = zeros(32,1);
    ph2_M = zeros(32,1);
    ph2_R = zeros(32,1);

end

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITHOUT A CONSTRAINT
%----------------------------------------------------------------------------------------------

if (mode == 1) & (mode_vinc == 0)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    kalman_goGPS_init (pos_M(:,1), time_GPS(1), Eph_t, iono, pr1_R(:,1), pr1_M(:,1), ph1_R(:,1), ph1_M(:,1), pr2_R(:,1), pr2_M(:,1), ph2_R(:,1), ph2_M(:,1), snr_R(:,1), snr_M(:,1), 1);

    fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
    end
    if (flag_amb == 1)
        rtplot_amb (1, window, Xhat_t_t(o3+1:o3+32), sqrt(diag(Cee(o3+1:o3+32,o3+1:o3+32))), conf_cs)
    else
        if (flag_skyplot == 1)
            rtplot_skyplot (1, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,1));
        else
            rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
        end
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = kalman_goGPS_loop (pos_M(:,t), time_GPS(t), Eph_t, iono, pr1_R(:,t), pr1_M(:,t), ph1_R(:,t), ph1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph2_R(:,t), ph2_M(:,t), snr_R(:,t), snr_M(:,t), 1);

        fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
        end
        if (flag_amb == 1)
            rtplot_amb (t, window, Xhat_t_t(o3+1:o3+32), sqrt(diag(Cee(o3+1:o3+32,o3+1:o3+32))), conf_cs);
            pause(0.1);
        else
            if (flag_skyplot == 1)
                rtplot_skyplot (t, azR, elR, conf_sat, pivot);
                rtplot_snr (snr_R(:,t));
            else
                rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
            end
            pause(0.01);
        end

    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITH A CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 1) & (mode_vinc == 1)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    %repeat more than once the reference loop
    %(this constrained mode works only for circuits)
    ref_loop = [ref_path; ref_path];

    kalman_goGPS_vinc_init (pos_M(:,1), time_GPS(1), Eph_t, iono, pr1_R(:,1), pr1_M(:,1), ph1_R(:,1), ph1_M(:,1), pr2_R(:,1), pr2_M(:,1), ph2_R(:,1), ph2_M(:,1), snr_R(:,1), snr_M(:,1), 1, ref_loop);

    fwrite(fid_kal, [Xhat_t_t; Yhat_t_t; Cee(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_ge == 1), rtplot_googleearth (1, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,1), date(1,:)), end;
    rtplot_matlab (1, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
    if (flag_amb == 1)
        rtplot_amb (1, window, Xhat_t_t(o1+1:o1+32), sqrt(diag(Cee(o1+1:o1+32,o1+1:o1+32))), conf_cs);
    else
        if (flag_skyplot == 1)
            rtplot_skyplot (1, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,1));
        else
            rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
        end
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = kalman_goGPS_vinc_loop (pos_M(:,t), time_GPS(t), Eph_t, iono, pr1_R(:,t), pr1_M(:,t), ph1_R(:,t), ph1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph2_R(:,t), ph2_M(:,t), snr_R(:,t), snr_M(:,t), 1, ref_loop);

        fwrite(fid_kal, [Xhat_t_t; Yhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_ge == 1), rtplot_googleearth (t, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,t), date(t,:)), end;
        rtplot_matlab (t, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
        if (flag_amb == 1)
            rtplot_amb (t, window, Xhat_t_t(o1+1:o1+32), sqrt(diag(Cee(o1+1:o1+32,o1+1:o1+32))), conf_cs);
            pause(0.1);
        else
            if (flag_skyplot == 1)
                rtplot_skyplot (t, azR, elR, conf_sat, pivot);
                rtplot_snr (snr_R(:,t));
            else
                rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
            end
            pause(0.01);
        end

    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: KALMAN FILTER ON PHASE AND CODE, STAND-ALONE AND WITHOUT A CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 2)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    kalman_goGPS_SA_init (time_GPS(1), Eph_t, iono, pr1_R(:,1), ph1_R(:,1), pr2_R(:,1), ph2_R(:,1), snr_R(:,1), 1);

    fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
    end
    if (flag_amb == 1)
        rtplot_amb (1, window, Xhat_t_t(o3+1:o3+32), sqrt(diag(Cee(o3+1:o3+32,o3+1:o3+32))), conf_cs)
    else
        if (flag_skyplot == 1)
            rtplot_skyplot (1, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,1));
        else
            rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
        end
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = kalman_goGPS_SA_loop (time_GPS(t), Eph_t, iono, pr1_R(:,t-1:t), ph1_R(:,t-1:t), pr2_R(:,t-1:t), ph2_R(:,t-1:t), snr_R(:,t), 1);
        
        fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
        end
        if (flag_amb == 1)
            rtplot_amb (t, window, Xhat_t_t(o3+1:o3+32), sqrt(diag(Cee(o3+1:o3+32,o3+1:o3+32))), conf_cs);
            pause(0.1);
        else
            if (flag_skyplot == 1)
                rtplot_skyplot (t, azR, elR, conf_sat, pivot);
                rtplot_snr (snr_R(:,t));
            else
                rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
            end
            pause(0.01);
        end

    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: LEAST SQUARES ADJ. ON CODE DOUBLE DIFFERENCES, NO CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 3)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = 32;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    MQ_goGPS_loop (time_GPS(1), Eph_t, pos_M(:,1), pr1_R(:,1), pr1_M(:,1), pr2_R(:,1), pr2_M(:,1), snr_R(:,1), snr_M(:,1), 1);

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    end
    if (flag_skyplot == 1)
        rtplot_skyplot (1, azR, elR, conf_sat, pivot);
        rtplot_snr (snr_R(:,1));
    else
        rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        MQ_goGPS_loop (time_GPS(t), Eph_t, pos_M(:,t), pr1_R(:,t), pr1_M(:,t), pr2_R(:,t), pr2_M(:,t), snr_R(:,t), snr_M(:,t), 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (t, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,t));
        else
            rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
        end

        pause(0.01);
    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: LEAST SQUARES ADJ. ON CODE, NO CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 4)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = 32;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    MQ_goGPS_SA_loop(time_GPS(1), Eph_t, pr1_R(:,1), pr2_R(:,1), snr_R(:,1), 1);

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, [zeros(32,1); azR; zeros(32,1); elR; zeros(32,1); distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    end
    if (flag_skyplot == 1)
        rtplot_skyplot (1, azR, elR, conf_sat, pivot);
        rtplot_snr (snr_R(:,1));
    else
        rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        MQ_goGPS_SA_loop(time_GPS(t), Eph_t, pr1_R(:,t), pr2_R(:,t), snr_R(:,t), 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [zeros(32,1); azR; zeros(32,1); elR; zeros(32,1); distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (t, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,t));
        else
            rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
        end

        pause(0.01);
    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: KALMAN FILTER ON CODE DOUBLE DIFFERENCES, NO CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 5)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = 32;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    kalman_goGPS_cod_init(pos_M(:,1), time_GPS(1), Eph_t, iono, pr1_R(:,1), pr1_M(:,1), pr2_R(:,1), pr2_M(:,1), snr_R(:,1), snr_M(:,1), 1);

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    end
    if (flag_skyplot == 1)
        rtplot_skyplot (1, azR, elR, conf_sat, pivot);
        rtplot_snr (snr_R(:,1));
    else
        rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = kalman_goGPS_cod_loop (pos_M(:,t), time_GPS(t), Eph_t, iono, pr1_R(:,t), pr1_M(:,t), pr2_R(:,t), pr2_M(:,t), snr_R(:,t), snr_M(:,t), 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (t, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,t));
        else
            rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
        end

        pause(0.01);
    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING: KALMAN FILTER ON CODE, NO CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 6)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = 32;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;

    if (mode_data == 0)
        Eph_t = rt_find_eph (Eph, time_GPS(1));
    else
        Eph_t = Eph(:,:,1);
    end

    kalman_goGPS_SA_cod_init(time_GPS(1), Eph_t, iono, pr1_R(:,1), pr2_R(:,1), snr_R(:,1), 1);

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

    if (flag_cov == 0)
        if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(1,:)), end;
        rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    else
        if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
        rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
    end
    if (flag_skyplot == 1)
        rtplot_skyplot (1, azR, elR, conf_sat, pivot);
        rtplot_snr (snr_R(:,1));
    else
        rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot);
    end

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t));
        else
            Eph_t = Eph(:,:,t);
        end

        kalman_goGPS_SA_cod_loop(time_GPS(t), Eph_t, iono, pr1_R(:,t), pr2_R(:,t), snr_R(:,t), 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
            rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
            rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (t, azR, elR, conf_sat, pivot);
            rtplot_snr (snr_R(:,t));
        else
            rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot);
        end
        pause(0.01);
    end

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% REAL-TIME: KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITH/WITHOUT A CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == 11)

    goGPS_realtime(filerootOUT, mode_vinc, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_ms_pos, flag_skyplot, ref_path, mat_path, pos_M, pr2_M, pr2_R, ph2_M, ph2_R);

%----------------------------------------------------------------------------------------------
% REAL-TIME: ROVER MONITORING
%----------------------------------------------------------------------------------------------

elseif (mode == 12)

    goGPS_ublox_monitor(filerootOUT);

%----------------------------------------------------------------------------------------------
% REAL-TIME: MASTER MONITORING
%----------------------------------------------------------------------------------------------

elseif (mode == 13)

    goGPS_master_monitor(filerootOUT, flag_NTRIP);

%----------------------------------------------------------------------------------------------
% REAL-TIME: ROVER AND MASTER MONITORING
%----------------------------------------------------------------------------------------------
    
elseif (mode == 14)
    
    goGPS_realtime_monitor(filerootOUT, flag_NTRIP, flag_ms_pos, pos_M);

end

%----------------------------------------------------------------------------------------------
% INPUT/OUTPUT DATA FILE READING
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %stream reading
    % [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, snr_R, snr_M, ...
    %  pos_M, Eph, iono, loss_R, loss_M, stream_R, stream_M] = load_stream(filerootIN);

    %---------------------------------

    %observation file (OBS) and ephemerides file (EPH) reading
	if (mode == 11)
        [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, snr_R, snr_M, ...
        pos_M, Eph, iono, delay, loss_R, loss_M] = load_goGPSinput(filerootOUT);
	end

    %---------------------------------

    %reading of the files with Kalman filter results
    [Xhat_t_t, Yhat_t_t, Cee, azM, azR, elM, elR, distM, distR, ...
        conf_sat, conf_cs, pivot, PDOP, HDOP, VDOP, KPDOP, ...
        KHDOP, KVDOP] = load_goGPSoutput(filerootOUT, mode, mode_vinc);

    %variable saving for final graphical representations
    nObs = size(Xhat_t_t,2);
    pos_KAL = zeros(3,nObs);
    estim_amb = zeros(32,nObs);
    sigma_amb = zeros(32,nObs);
    for i = 1 : nObs
        if (mode == 1 & mode_vinc == 1)
            pos_KAL(:,i) = [Yhat_t_t(1,i); Yhat_t_t(2,i); Yhat_t_t(3,i)];
            estim_amb(:,i) = Xhat_t_t(o1+1:o1+32,i);
            sigma_amb(:,i) = sqrt(diag(Cee(o1+1:o1+32,o1+1:o1+32,i)));
        else
            pos_KAL(:,i) = [Xhat_t_t(1,i); Xhat_t_t(o1+1,i); Xhat_t_t(o2+1,i)];
            estim_amb(:,i) = Xhat_t_t(o3+1:o3+32,i);
            sigma_amb(:,i) = sqrt(diag(Cee(o3+1:o3+32,o3+1:o3+32,i)));
        end
    end
end

%----------------------------------------------------------------------------------------------

%computation and visualization time reading
% [dt_acqR, dt_decR, dt_acqM, dt_decM, dt_saveI, dt_kal, dt_saveO, ...
%     dt_plot, dt_ge, dt_sky, dt_snr] = load_goGPStime (filerootOUT);

%----------------------------------------------------------------------------------------------
% ECEF COORDINATES SAVING (TEXT FILE)
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %display information
    fprintf('Writing ECEF coordinates file...\n');
    %cartesian coordinates (X,Y,Z)
    X_KAL = pos_KAL(1,:)';
    Y_KAL = pos_KAL(2,:)';
    Z_KAL = pos_KAL(3,:)';

    %file saving
    fid_xyz = fopen([filerootOUT '_ECEF.txt'], 'wt');
    for i = 1 : length(X_KAL)
        fprintf(fid_xyz, '%d\t%.8f\t%.8f\t%.3f\n', check_t(time_GPS(i)), X_KAL(i), Y_KAL(i), Z_KAL(i));
    end
    fclose(fid_xyz);
end

%----------------------------------------------------------------------------------------------
% GEODETIC COORDINATES SAVING (TEXT FILE)
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %display information
    fprintf('Writing geodetic coordinates file...\n');
    %cartesian coordinates (X,Y,Z)
    X_KAL = pos_KAL(1,:)';
    Y_KAL = pos_KAL(2,:)';
    Z_KAL = pos_KAL(3,:)';

    %coordinate transformation
    [phi_KAL, lam_KAL, h_KAL] = cart2geod(X_KAL, Y_KAL, Z_KAL);
    phi_KAL = phi_KAL * 180/pi;
    lam_KAL = lam_KAL * 180/pi;

    %file saving
    fid_geod = fopen([filerootOUT '_geod.txt'], 'wt');
    for i = 1 : length(phi_KAL)
        fprintf(fid_geod, '%.8f\t%.8f\t%.3f\n', phi_KAL(i), lam_KAL(i), h_KAL(i));
    end
    fclose(fid_geod);
end

%----------------------------------------------------------------------------------------------
% UTM COORDINATES SAVING (TEXT FILE)
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %display information
    fprintf('Writing UTM coordinates file...\n');
    %cartesian coordinates (X,Y,Z)
    X_KAL = pos_KAL(1,:)';
    Y_KAL = pos_KAL(2,:)';
    Z_KAL = pos_KAL(3,:)';

    %coordinate transformation
    [EST_KAL, NORD_KAL, h_KAL] = cart2plan(X_KAL, Y_KAL, Z_KAL);

    %trajectory plotting
    figure
    plot(EST_KAL, NORD_KAL, '.r');
    xlabel('EST [m]'); ylabel('NORD [m]'); grid on;

    %data saving
    fid_plan = fopen([filerootOUT '_plan.txt'], 'wt');
    for i = 1 : length(EST_KAL)
        fprintf(fid_plan, '%.3f\t%.3f\t%.3f\n', EST_KAL(i), NORD_KAL(i), h_KAL(i));
    end
    fclose(fid_plan);
end

%----------------------------------------------------------------------------------------------
% NMEA FILE SAVING
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %display information
    fprintf('Writing NMEA file...\n');
    %file saving
    fid_nmea = fopen([filerootOUT '_NMEA.txt'], 'wt');
    %date formatting (if not using RINEX)
    if (mode_data ~= 0) | (mode == 11)
        date = datevec(check_t(time_GPS)/(3600*24) + 7*week_R + datenum([1980,1,6,0,0,0]));
        date(:,1) = date(:,1) - 2000;
    end
    
    for i = 1 : length(pos_KAL(1,:))
        
        %active satellites
        sat = find(abs(conf_sat(:,i)));
        %number of active satellites
        nsat = length(sat);
        %visible satellites
        vsat = find(elR(:,i) > 0);

        %NMEA string generation
        GGAstring = NMEA_GGA_gen(pos_KAL(:,i), nsat, time_GPS(i), HDOP(i));
        if (pivot(i) ~= 0)
            RMCstring = NMEA_RMC_gen(pos_KAL(:,i), date(i,:));
            GSVstring = NMEA_GSV_gen(vsat, elR(vsat,i), azR(vsat,i), snr_R(vsat,i));
            GSAstring = NMEA_GSA_gen(sat, PDOP(i), HDOP(i), VDOP(i), 'M', '3');
            if (mode_vinc == 0) & (mode ~= 3) & (mode ~= 4)
                PGGPKstring = NMEA_PGGPK_gen(sat, KPDOP(i), KHDOP(i), KVDOP(i), 'S');
            end
        else
            GSAstring = NMEA_GSA_gen(sat, PDOP(i), HDOP(i), VDOP(i), 'M', '1');
            if (mode_vinc == 0) & (mode ~= 3) & (mode ~= 4)
                PGGPKstring = NMEA_PGGPK_gen(sat, KPDOP(i), KHDOP(i), KVDOP(i), 'D');
            end
        end

        %NMEA file write
        fprintf(fid_nmea, [GGAstring '\n']);
        if (pivot(i) ~= 0)
            fprintf(fid_nmea, [RMCstring '\n']);
            fprintf(fid_nmea, [GSVstring '\n']);
        end
        fprintf(fid_nmea, [GSAstring '\n']);
        if (mode_vinc == 0) & (mode ~= 3) & (mode ~= 4)
            fprintf(fid_nmea, [PGGPKstring '\n']);
        end
    end
    fclose(fid_nmea);
end

%----------------------------------------------------------------------------------------------
% GOOGLE EARTH FILE SAVING (KML FILE)
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %display information
    fprintf('Writing KML file...\n');
    %"clampedToGround" plots the points attached to the ground
    %"absolute" uses the height defined in the tag <coordinates>;
    %N.B. Google Earth uses orthometric heights
    z_pos = 'clampedToGround';
    %z_pos = 'absolute';
    %URL to load the icon for the points
    iconR = 'http://maps.google.com/mapfiles/kml/pal2/icon26.png';
    iconM = 'http://maps.google.com/mapfiles/kml/shapes/square.png';
    good_point_colorR = 'FFF5005A';
    bad_point_colorR = 'FF0000FF';
    dyn_point_colorR = 'FF00FFFF';
    point_colorM = 'FF00FFFF';
    %point size
    scaleR = 0.2;
    scaleM = 0.8;
    line_colorR = 'FFF5005A';
    %label color
    label_colorM = point_colorM;
    %label size
    label_scaleM = 0.7;
    
    %initialization
    epochs = length(pos_M(1,:));
    phiM = zeros(1, epochs);
    lamM = zeros(1, epochs);
    hM = zeros(1, epochs);

    %master station coordinates
    for i = 1 : epochs
        if (sum(abs(pos_M(:,i))) ~= 0)
            XM = pos_M(1,i);
            YM = pos_M(2,i);
            ZM = pos_M(3,i);
            
            %conversion from cartesian to geodetic coordinates
            [phiM(i), lamM(i), hM(i)] = cart2geod(XM, YM, ZM);
            
            %conversion from radians to degrees
            lamM(i) = lamM(i)*180/pi;
            phiM(i) = phiM(i)*180/pi;
        else
            lamM(i) = 0;
            phiM(i) = 0;
            hM(i) = 0;
        end
    end

    %file saving (Google Earth KML)
    fid_kml = fopen([filerootOUT '.kml'], 'wt');
    fprintf(fid_kml, '<?xml version="1.0" standalone="yes"?>\n');
    fprintf(fid_kml, '<kml creator="goGPS" xmlns="http://earth.google.com/kml/2.2">\n');
    fprintf(fid_kml, '  <Document>\n');
    fprintf(fid_kml, '    <name><![CDATA[%s]]></name>\n', [filerootOUT '.kml']);
    fprintf(fid_kml, '    <Snippet><![CDATA[created by goGPS]]></Snippet>\n');
    fprintf(fid_kml, '      <Style id="go1">\n');
    fprintf(fid_kml, '        <IconStyle>\n');
    fprintf(fid_kml, '          <color>%s</color>\n',good_point_colorR);
    fprintf(fid_kml, '          <scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '          <Icon>\n');
    fprintf(fid_kml, '            <href>%s</href>\n',iconR);
    fprintf(fid_kml, '          </Icon>\n');
    fprintf(fid_kml, '        </IconStyle>\n');
    fprintf(fid_kml, '      </Style>\n');
    fprintf(fid_kml, '      <Style id="go2">\n');
    fprintf(fid_kml, '        <IconStyle>\n');
    fprintf(fid_kml, '          <color>%s</color>\n',bad_point_colorR);
    fprintf(fid_kml, '          <scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '          <Icon>\n');
    fprintf(fid_kml, '            <href>%s</href>\n',iconR);
    fprintf(fid_kml, '          </Icon>\n');
    fprintf(fid_kml, '        </IconStyle>\n');
    fprintf(fid_kml, '      </Style>\n');
    fprintf(fid_kml, '      <Style id="go3">\n');
    fprintf(fid_kml, '        <IconStyle>\n');
    fprintf(fid_kml, '          <color>%s</color>\n',dyn_point_colorR);
    fprintf(fid_kml, '          <scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '          <Icon>\n');
    fprintf(fid_kml, '            <href>%s</href>\n',iconR);
    fprintf(fid_kml, '          </Icon>\n');
    fprintf(fid_kml, '        </IconStyle>\n');
    fprintf(fid_kml, '      </Style>\n');
    fprintf(fid_kml, '      <Style id="master">\n');
    fprintf(fid_kml, '        <IconStyle>\n');
    fprintf(fid_kml, '          <Icon>\n');
    fprintf(fid_kml, '            <href>%s</href>\n',iconM);
    fprintf(fid_kml, '          </Icon>\n');
    fprintf(fid_kml, '          <color>%s</color>\n',point_colorM);
    fprintf(fid_kml, '          <colorMode>normal</colorMode>\n');
    fprintf(fid_kml, '          <scale>%.2f</scale>\n',scaleM);
    fprintf(fid_kml, '        </IconStyle>\n');
    fprintf(fid_kml, '        <LabelStyle>\n');
    fprintf(fid_kml, '          <color>%s</color>\n',label_colorM);
    fprintf(fid_kml, '          <scale>%s</scale>\n',label_scaleM);
    fprintf(fid_kml, '        </LabelStyle>\n');
    fprintf(fid_kml, '      </Style>\n');
    for i = 1 : length(phiM)
        if (lamM(i) ~= 0 | phiM(i) ~= 0 | hM(i) ~= 0)
           if (i == 1) | (lamM(i)~=lamM(i-1) & phiM(i)~=phiM(i-1) & hM(i)~=hM(i-1))
               fprintf(fid_kml, '      <Placemark>\n');
               fprintf(fid_kml, '        <styleUrl>#master</styleUrl>\n');
               fprintf(fid_kml, '        <name>Master station</name>\n');
               fprintf(fid_kml, '        <Point>\n');
               fprintf(fid_kml, '          <altitudeMode>%s</altitudeMode>\n',z_pos);
               fprintf(fid_kml, '          <coordinates>%.8f,%.8f,%.3f</coordinates>\n',lamM(i),phiM(i),hM(i));
               fprintf(fid_kml, '        </Point>\n');
               fprintf(fid_kml, '        <Snippet></Snippet>\n');
               fprintf(fid_kml, '        <description><![CDATA[ <i>Latitude:</i> %.8f &#176;<br/> <i>Longitude:</i> %.8f &#176;<br/> <i>Elevation (ellips.):</i> %.1f m<br/>]]></description>\n',phiM(i),lamM(i),hM(i));
               fprintf(fid_kml, '      </Placemark>\n');
           end
        end
    end
    fprintf(fid_kml, '      <Placemark>\n');
    fprintf(fid_kml, '      <name>Rover track</name>\n');
    fprintf(fid_kml, '        <Style>\n');
    fprintf(fid_kml, '          <LineStyle>\n');
    fprintf(fid_kml, '            <color>%s</color>\n',line_colorR);
    fprintf(fid_kml, '          </LineStyle>\n');
    fprintf(fid_kml, '        </Style>\n');
    fprintf(fid_kml, '        <LineString>\n');
    fprintf(fid_kml, '          <coordinates>\n');
    for i = 1 : length(phi_KAL)
        fprintf(fid_kml, '            %.6f,%.6f,0.000\n',lam_KAL(i),phi_KAL(i));
    end
    fprintf(fid_kml, '          </coordinates>\n');
    fprintf(fid_kml, '        </LineString>\n');
    fprintf(fid_kml, '      </Placemark>\n');
    fprintf(fid_kml, '      <Folder>\n');
    fprintf(fid_kml, '      <name>Rover positioning</name>\n');
    for i = 1 : length(phi_KAL)
        fprintf(fid_kml, '      <Placemark>\n');
        if (pivot(i) == 0)
            fprintf(fid_kml, '        <styleUrl>#go3</styleUrl>\n');
        elseif (KHDOP(i)>2)
            fprintf(fid_kml, '        <styleUrl>#go2</styleUrl>\n');
        else
            fprintf(fid_kml, '        <styleUrl>#go1</styleUrl>\n');
        end
        fprintf(fid_kml, '        <Point>\n');
        fprintf(fid_kml, '          <altitudeMode>%s</altitudeMode>\n',z_pos);
        fprintf(fid_kml, '          <coordinates>%.6f,%.6f,%.6f</coordinates>\n',lam_KAL(i),phi_KAL(i),h_KAL(i));
        fprintf(fid_kml, '        </Point>\n');
        fprintf(fid_kml, '        <Snippet></Snippet>\n');
        fprintf(fid_kml, '      </Placemark>\n');
    end
    fprintf(fid_kml, '      </Folder>\n');
    fprintf(fid_kml, '  </Document>\n</kml>');
    fclose(fid_kml);
end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE ESTIMATED ERROR COVARIANCE (AND TEXT FILE SAVING)
%----------------------------------------------------------------------------------------------

if (mode < 12) & (flag_cov == 1) & (mode_vinc == 0)

    %display information
    fprintf('Writing estimated error covariance file...\n');
    %covariance propagation
    Cee_ENU = global2localCov(Cee([1 o1+1 o2+1],[1 o1+1 o2+1],:), Xhat_t_t([1 o1+1 o2+1],:));
    %trajectory plotting
    figure
    plot(EST_KAL, NORD_KAL, '.r'); axis equal
    xlabel('EST [m]'); ylabel('NORD [m]'); grid on;

    hold on
    for i = 1 : size(Cee_ENU,3)         % ellipse definition
        T = chol(Cee_ENU(1:2,1:2,i));   % Cholesky decomposition
        n = size(x_circle,1);
        x_ellipse = zeros(n,2);         % pre-allocation
        for j = 1 : n                   % ellipse definition
            x_ellipse(j,:) = x_circle(j,:) * T + [EST_KAL(i), NORD_KAL(i)];
        end
        plot(x_ellipse(:,1),x_ellipse(:,2));
    end
    hold off

    %file saving
    fid_cov = fopen([filerootOUT '_cov.txt'], 'wt');
    for i = 1 : length(phi_KAL)
        fprintf(fid_cov, '%.8f\t%.8f\t%.8f\t%.8f\t%.8f\t%.8f\n', Cee_ENU(1,1,i), Cee_ENU(1,2,i), ...
            Cee_ENU(1,3,i), Cee_ENU(2,2,i), Cee_ENU(2,3,i), Cee_ENU(3,3,i));
    end
    fclose(fid_cov);

end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE REFERENCE TRAJECTORY
%----------------------------------------------------------------------------------------------

% if (mode < 12 & mode_ref == 1)
%     [EST_ref, NORD_ref, h_ref] = cart2plan(ref_path(:,1), ref_path(:,2),ref_path(:,3));
%
%     %reference data plot
%     plot(EST_ref, NORD_ref, 'm', 'LineWidth', 2)
%
%     hold off
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE 3D TRAJECTORY
%----------------------------------------------------------------------------------------------

if (mode < 12)
    %3D plot
    figure
    plot3(EST_KAL, NORD_KAL, h_KAL, '.r');
    xlabel('EST [m]'); ylabel('NORD [m]'); zlabel('h [m]'); grid on
end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE VISIBLE SATELLITES CONFIGURATION
%----------------------------------------------------------------------------------------------

% if (mode == 1)
%
%    %figure
%    %imagesc(abs(conf_sat)), grid;
%    %colormap(1-gray);
%
%    figure
%    subplot('position',[0.1 0.35 0.8 0.55]);
%    hold on; grid on;
%    title('Satellite configuration')
%    for i = 1 : 32
%       index = find(abs(conf_sat(i,:)) == 1);
%       index_cs = intersect(index, find(conf_cs(i,:) == 1));
%       index_pivot = intersect(index, find(pivot == i));
%       if ~isempty(index)
%          plot(index,i*ones(size(index)),'b.-');
%          plot(index_pivot,i*ones(size(index_pivot)),'r.');
%          plot(index_cs,i*ones(size(index_cs)),'g.');
%       end
%    end
%    axis([1 size(conf_sat,2) 0.5 32.5])
%    hold off;
%    clear i index index_cs index_pivot
%
%    subplot('position',[0.1 0.1 0.8 0.2]);
%    hold on; grid on;
%    s1 = sum(abs(conf_sat));
%    plot(s1,'b.-');
%    s2 = [0; pivot(2:end) - pivot(1:end-1)];
%    plot(find(s2>0),s1(find(s2>0)),'r.')
%    s3 = sum(conf_cs);
%    plot(find(s3>0),s3(find(s3>0)),'g.');
%    axis([1 size(conf_sat,2) 0 max(s1)])
%    hold off;
%    clear s1 s2 s3
%
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF AZIMUTH, ELEVATION AND DISTANCE FOR VISIBILE SATELLITES
%----------------------------------------------------------------------------------------------

% if (mode == 1)
%
%    coltab = jet;
%
%    f1 = figure; hold on; grid on; title('Azimuth')
%    f2 = figure; hold on; grid on; title('Elevation')
%    f3 = figure; hold on; grid on; title('Distance')
%    k = 1;
%    for i = 1 : 32
%       index = find(abs(conf_sat(i,:)) == 1)';
%       if ~isempty(index)
%          %azimuth
%          figure(f1)
%          h = plot(index,azR(i,index),'b.-'); grid on;
%          set(h,'Color',coltab(2*i-1,:));
%          %elevation
%          figure(f2)
%          h = plot(index,elR(i,index),'r.-');
%          set(h,'Color',coltab(2*i-1,:));
%          %distance
%          figure(f3)
%          h = plot(index,distR(i,index)*1e-6,'g.-');
%          set(h,'Color',coltab(2*i-1,:));
%          %legend
%          list{k} = num2str(i);
%          k = k+1;
%       end
%    end
%    figure(f1); hold off; legend(list)
%    figure(f2); hold off; legend(list)
%    figure(f3); hold off; legend(list)
%    clear f1 f2 f3
%    clear i k h
%    clear coltab
%
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE S/N RATIO FOR MASTER AND ROVER
%----------------------------------------------------------------------------------------------

% if (mode == 1)
%
%    coltab = jet;
%    coltab = [1 1 1; coltab([1 16 32 48 56],:)];
%
%    figure
%    subplot(2,1,1);
%    imagesc(snr_R.*abs(conf_sat),[-0.5 60.5]);
%    title('Rover S/N ratio');
%    axis xy; colormap(coltab);
%    h = colorbar; set(h,'YTick',0:10:60);
%    subplot(2,1,2);
%    imagesc(snr_M.*abs(conf_sat),[-0.5 60.5]);
%    title('Master S/N ratio');
%    axis xy; colormap(coltab);
%    h = colorbar; set(h,'YTick',0:10:60);
%
%    clear h coltab
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE COMBINATIONS OF ESTIMATED AMBIGUITIES
%----------------------------------------------------------------------------------------------

% if (mode == 1) | (mode == 2)
% 
%    for i = 1 : 32
%       index = find(conf_sat(i,:) == 1)';
%       index_cs = find(conf_cs(i,:) == 1)';
%       if ~isempty(index)
%          j = [1; find(index(2:end) - index(1:end-1) > 1)+1];
%          figure
%          %combination of estimated ambiguities
%          plot(index,estim_amb(i,index),'b.-'); grid on;
%          hold on
%          %cycle-slip
%          plot(index_cs,estim_amb(i,index_cs),'mo');
%          %combination of estimated ambiguities for new satellites
%          plot(index(j),estim_amb(i,index(j)),'g.');
%          %acceptance interval
%          plot(index, estim_amb(i,index) + sigma_amb(i,index),'r:');
%          plot(index, estim_amb(i,index) - sigma_amb(i,index),'r:');
%          hold off
%          title(['Combination of estimated ambiguities between PIVOT and SATELLITE ',num2str(i)]);
%       end
%    end
% 
% end

%----------------------------------------------------------------------------------------------
% STATISTICS COMPUTATION AND VISUALIZATION
%----------------------------------------------------------------------------------------------

if (mode < 10) & (mode_vinc == 0) & (~isempty(ref_path))
    %coordinate transformation
    [EST_REF, NORD_REF, h_REF] = cart2plan(ref_path(:,1), ref_path(:,2), ref_path(:,3));

    ref = [EST_REF NORD_REF h_REF];

    [dist2D, proj] = ref_2d_projection(ref,EST_KAL,NORD_KAL); %#ok<NASGU>

    fprintf('\n');
    fprintf('-------- STATISTICS ------------');
    fprintf('\n');
    fprintf('Mean2D: %7.4f m\n',mean(dist2D));
    fprintf('Std2D:  %7.4f m\n',std(dist2D));
    fprintf('RMS2D:  %7.4f m\n\n',sqrt(std(dist2D)^2+mean(dist2D)^2));

    [dist3D,proj] = ref_3d_projection(ref,EST_KAL,NORD_KAL,h_KAL);

    fprintf('Mean3D: %7.4f m\n',mean(dist3D));
    fprintf('Std3D:  %7.4f m\n',std(dist3D));
    fprintf('RMS3D:  %7.4f m\n',sqrt(std(dist3D)^2+mean(dist3D)^2));
    fprintf('--------------------------------\n\n');
end

%----------------------------------------------------------------------------------------------

% close all the opened files
fclose('all');

%re-enable MATLAB warnings
warning on

%evaluate computation time
toc
