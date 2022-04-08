function wl_main_loop(WL,length_of_test,predict_display_timing)
%function wl_main_loop(WL,length_of_test,predict_display_timing)
% WL_MAIN_LOOP runs for the duration of the experiment processing the states
% and updating the screen, audio and other I/O. It calls various user-defined
% functions, including display_func(), state_process(), keyboard_func() and
% idle_func().
%
% It plots timing statistics for functions and events associated with the display loop.
%
% The parameter length_of_test can be set for test purposes, the main loop will
% terminate after the number of seconds specified.
%
% The parameter predict_display_timing determines whether timing prediction is
% applied to calling the display_func(). Default value is 1 which is full predictive 
% timing, 0 is predictive timing using default values (see below), -1 is no predictive
% timing, so the display_func() will be called immediately after each flip.

global GL

if( nargin < 2 )
    length_of_test = inf; % not testing run forever.
end

if( isempty(length_of_test) )
    length_of_test = inf;
end

if( nargin < 3 )
    predict_display_timing = 1; % Should we predict the display loop time?
end

if( isfield(WL.cfg,'predict_display_timing') )
    predict_display_timing = WL.cfg.predict_display_timing;
end

%%%%%%%%%% set up adaptive timing if required %%%%%

% Initial estimate of display_func execution time.
if( ~isfield(WL.cfg,'display_estimate_duration') )
    display_estimate_duration = 0.004; % sec
else
    display_estimate_duration = WL.cfg.display_estimate_duration;
end

% How tight do we want timing of flip request to be actual flip?
if( ~isfield(WL.cfg,'desired_flip_request_2_flip') )
    desired_flip_request_2_flip = 0.002; % sec
else
    desired_flip_request_2_flip = WL.cfg.desired_flip_request_2_flip;
end

% desired_flip_2_display_func
% This sets the time after the last flip where we want to draw and
% request a flip so as to be done in time to catch the next flip
% It is updated below based on new values for display_estimate_duration.
desired_flip_2_display_func = WL.Screen.ifi - (desired_flip_request_2_flip + display_estimate_duration);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%set up circular storage bufffers for stats
Nb = 20000; % buffer length
vbl_timestamp_buffer                 = wl_circbuffer(Nb);
flip_timestamp_buffer                = wl_circbuffer(Nb);
desired_flip_2_display_func_buffer   = wl_circbuffer(Nb);

desired_idle_func_freq = 1000;  %run at 1000Hz loop

%request a flip to start
VBLTimestamp = Screen('Flip',  WL.Screen.window);
WL.Screen.flipped = 0;

Priority(MaxPriority(WL.Screen.window));

% Set the mouse to the middle of the screen (if mac)
if ismac
    SetMouse(WL.Screen.cent(1), WL.Screen.cent(2), WL.Screen.window);
end

%number of trials to run
WL.GW.TrialCount  = rows(WL.TrialData);
WL.TrialNumber = 1;

if( WL.GW.TrialCount > 0 && isfield(WL,'TrialData') )
    wl_trial_setup(WL); % read in first trial from TrialData table
end

start_time = GetSecs();
Exit = 0;

if ~WL.cfg.Debug
    HideCursor;
end

if WL.cfg.OculusRift && ~WL.cfg.GLSL
    Xmin = -40;
    Xmax = 40;
    Ymin = -40;
    Ymax = 10;
    Zmin = -40;
    Zmax = 10;
    
    wl_oculus_grid(Xmin,Xmax,Ymin,Ymax,Zmin,Zmax);
end

%%%%%%%% Start experiment %%%%%%%%%%%%%
while ~Exit % && test_count < length(delays)
    pause(0.000001); % this little pause lets NI-DAQ collect data.
    
    WL.Timer.Graphics.main_loop.Loop();
    
    %%%%%%%%%%% Idle loop %%%%%%%%%%%
    if wl_everyhz(desired_idle_func_freq)
        WL.Timer.Graphics.idle_func_2_idle_func.Loop();

        WL.Timer.Graphics.get_latest.Tic();
        ok = WL.Hardware.GetLatest();
        WL.Timer.Graphics.get_latest.Toc();

        state_last = WL.State.Current;
        
        WL.Timer.Graphics.state_process.Tic();
        WL.state_process();
        WL.Timer.Graphics.state_process.Toc();
        
        if state_last ~= WL.State.Current
            WL.State.Last = state_last;
            WL.State.FirstFlag = true;
        else
            WL.State.FirstFlag = false;
        end
        
        WL.Timer.Graphics.idle_func.Tic();
        WL.idle_func();
        WL.Timer.Graphics.idle_func.Toc();
        
        % Check all keyboards and stop on first key pressed
        [ pressed,keyname ] = WL.keyboard_read();
        
        % Process keyboard input.
        if( pressed )
            if( ischar(keyname) || isstring(keyname) )
                if( contains(keyname,'ESC') || (keyname(1) == 'Q') )
                    % Key pressed to exit experiment.
                    Exit = 1;
                    continue;
                end
            end
            
            % Any other key is passed to the application.
            WL.keyboard_func(keyname);
        end
        
        % Conditions to exit the experiment.
        if( WL.GW.ExitFlag || ((GetSecs()-start_time) > length_of_test) )
            Exit = 1;
        end
        
        %can read the mousebutton but not used in this example
        [~, ~, MouseButton] = GetMouse(WL.Screen.window);
    end
    
    %%%%%%%%%% if ready, draw next flame and request a screen flip %%%%%%%%%%
    if (WL.Screen.flipped == 1) && (((GetSecs() - VBLTimestamp) >= desired_flip_2_display_func) || (predict_display_timing == -1))
        WL.Timer.Graphics.display_main.Tic(); % Time the entire display process
 
        WL.Timer.Graphics.flip_2_display_func.Toc();
        
        % Save the desired_flip_2_display_func value for this flip.
        desired_flip_2_display_func_buffer.set(desired_flip_2_display_func);
        
        for eyeindex = 0:1
            % Select the eye buffer
            if WL.cfg.OculusRift
                Screen('SelectStereoDrawbuffer',WL.Screen.window, eyeindex);
            elseif eyeindex==1
                break
            end
            
            Screen('BeginOpenGL',WL.Screen.window);
            if( ~wl_is_error(WL) )
                if( (WL.State.Current == WL.State.REST) && (WL.cfg.OculusRift) )
                    glClearColor(0.0,0.1,0.1,0); % Dark cyan screen for rest break on Oculus.
                else
                    glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
                end

                glClear();
            end
            
            if WL.cfg.OculusRift && ~WL.cfg.GLSL
                % Initialize the modelview matrix
                glMatrixMode(GL.MODELVIEW);
                glLoadIdentity();
                
                % Scale everything down from meters to centimeters
                WorkspaceScale = 0.01;
                glScaled(WorkspaceScale,WorkspaceScale,WorkspaceScale);
                
                % Observer's IOD (cm)
                IOD = 6.25;
                % Position of cyclopean eye in 3BOT coordinates (cm, rough estimate)
                cameraPosition = [0 -26 14];
                % Shift the camera laterally by IOD/2
                cameraPosition(1) = cameraPosition(1) + (eyeindex-0.5)*IOD;
                
                glRotated(-60,1,0,0); % Tilt forward to align OpenGL negative z (straight-ahead) with 3BOT negative z (down)
                glTranslated(-cameraPosition(1), -cameraPosition(2), -cameraPosition(3)); % Translate to 3BOT origin
                % Now we're ready to render in 3BOT coordinate system!
                
                % 3D wire grid for Oculus (grey)
                if( isfield(WL.cfg,'OculusGrid') && (WL.State.Current ~= WL.State.REST) )
                    if( WL.cfg.OculusGrid )
                        glPushMatrix();
                        glRotated(180,0,0,1); 
                        glColor3f(0.2,0.2,0.2); 
                        %glLineWidth(1.0);
                        wl_oculus_grid();
                        glPopMatrix();
                    end
                end
            elseif WL.cfg.GLSL
                WL.eyeIndex = eyeIndex; % because we need access to this in display_func
            end
            
            if wl_is_error(WL)
                glClearColor(0.75,0,0,0); % Red screen for errors.
                glClear();
                Screen('EndOpenGL', WL.Screen.window);
                if( ~WL.cfg.OculusRift || (eyeindex == 0) ) % HACK!
                    FontSize = 40;
                    if( WL.cfg.OculusRift )
                        FontSize = 30;
                    end
                    wl_draw_text(WL,WL.GW.error_msg,'center','center','fontsize',FontSize);
                end
            elseif WL.State.Current == WL.State.REST
                if( ~WL.cfg.OculusGrid )
                    wl_draw_teapot(WL);
                end
                Screen('EndOpenGL',WL.Screen.window);
            else
                Screen('EndOpenGL', WL.Screen.window);
                WL.Timer.Graphics.display_func.Tic();
                WL.display_func();
                WL.Timer.Graphics.display_func.Toc();
            end
        end % eye loop
        
        WL.Timer.Graphics.display_main.Toc(); % Time the entire draw frame process
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        WL.Timer.Graphics.flip_request.Tic();
        Screen('AsyncFlipBegin', WL.Screen.window);
        WL.Timer.Graphics.flip_request.Toc();
        
        WL.Timer.Graphics.flip_request_2_flip.Tic();
        WL.Screen.flipped = 0;
        
        % set all frame counters trigger to 1 if running so that after next flip the
        % counter will be 1
        for timer = wl_frame_counter.get_instances()
            timer.Trigger();
        end
        
        % Calculate desired_flip_2_display_func for next display cycle.
        if( (WL.Timer.Graphics.display_main.toc_count > 50) && (predict_display_timing == 1) )
            display_main_mean = WL.Timer.Graphics.display_main.GetSummary().toc.dtmean;
            display_main_std = WL.Timer.Graphics.display_main.GetSummary().toc.dtsd;
            %display_main_max = WL.Timer.Graphics.display_main.GetSummary().toc.dtmax;
            
            display_estimate_duration = display_main_mean + (3 * display_main_std);
            
            % Update because we have a new estimate for desired_flip_2_display_func
            desired_flip_2_display_func = WL.Screen.ifi - (desired_flip_request_2_flip + display_estimate_duration);
            desired_flip_2_display_func = max([ desired_flip_2_display_func 0 ]);
        end
    end
    
    %%%%%%%%%% %test whether screen has flipped %%%%%%%%%%
    if  WL.Screen.flipped == 0
        
        WL.Timer.Graphics.flip_check.Tic();
        [VBLTimestamp, ~, FlipTimestamp] = Screen('AsyncFlipCheckEnd', WL.Screen.window);
        WL.Timer.Graphics.flip_check.Toc();
        % VBLTimestamp is the estimated time when the vertical blanking
        % interval started.
        % FlipTimestamp is a timestamp taken at the end of
        % Flip's execution. Use the difference between FlipTimestamp and
        % VBLTimestamp to get an estimate of how long Flips execution takes.
        
        if VBLTimestamp > 0 % screen has flipped
            WL.Screen.flipped = 1;
            WL.Screen.vbl=VBLTimestamp;
            vbl_timestamp_buffer.set(VBLTimestamp);
            flip_timestamp_buffer.set(FlipTimestamp);
            WL.flip_func(); % User-defined function to call when flipped (can be empty).
            % Increments all frame counters if trigger is 1.
            for timer = wl_frame_counter.get_instances()
                timer.IncrementCount();
            end
            
            WL.Timer.Graphics.flip_request_2_flip.Toc();
            WL.Timer.Graphics.flip_2_display_func.Tic();
            WL.Timer.Graphics.flip_2_flip.Loop();
        end
    end
end

%%%%%%%%%% finished the experiment %%%%%%%%%%

WL.close(); % Does everything we need to do before exiting.

wl_timer_results(WL.Timer.Graphics);

% Time statistics in milliseconds (stored in GW)
WL.GW.main_loop.flip_timestamp_buffer = 1000 * flip_timestamp_buffer.getall;
WL.GW.main_loop.flip_timestamp_buffer_diff = 1000 * flip_timestamp_buffer.diffall;

WL.GW.main_loop.vbl_timestamp_buffer = 1000 * vbl_timestamp_buffer.getall;
WL.GW.main_loop.vbl_timestamp_buffer_diff = 1000 * vbl_timestamp_buffer.diffall;

WL.GW.main_loop.delta_flip =  1000 * (flip_timestamp_buffer.getall - vbl_timestamp_buffer.getall);
WL.GW.main_loop.flip_to_vbl = 1000 * (vbl_timestamp_buffer.getto-flip_timestamp_buffer.getfrom);
WL.GW.main_loop.vbl_to_flip = 1000 * (flip_timestamp_buffer.getto-vbl_timestamp_buffer.getfrom);

WL.GW.main_loop.disp = WL.Timer.Graphics.display_func.GetSummary();
WL.GW.main_loop.req2flip = WL.Timer.Graphics.flip_request_2_flip.GetSummary();
WL.GW.main_loop.fip2disp = WL.Timer.Graphics.flip_2_display_func.GetSummary();
WL.GW.main_loop.desired_flip_2_display_func = 1000 * desired_flip_2_display_func_buffer.getall();
WL.GW.main_loop.Nb = Nb;

if WL.cfg.plot_timing
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    figure(1)
    clf
    
    subplot(2,2,1)
    hold on
    S = WL.Timer.Graphics.flip_2_flip.GetSummary();
    y = 1000*S.loop.dt;
    x = 1:length(y);
    plot(x,y,'b.')
    y = WL.GW.main_loop.vbl_timestamp_buffer_diff;
    x = 1:length(y);
    plot(x,y,'r.')
    plot([x(1) x(end)],1*[WL.Screen.ifi WL.Screen.ifi]*1000,'k:')
    plot([x(1) x(end)],2*[WL.Screen.ifi WL.Screen.ifi]*1000,'k:')
    plot([x(1) x(end)],3*[WL.Screen.ifi WL.Screen.ifi]*1000,'k:')
    xy = axis;
    axis([ 0 max(x) xy(3) xy(4) ]);
    xlabel('Samples')
    ylabel('display period (ms)')
    hold on
    H = legend('flip_to_flip','VR time stamp');
    set(H,'Interpreter','none');
    
    subplot(2,2,2)
    hold on;
    S = WL.Timer.Graphics.flip_2_display_func.GetSummary();
    y = 1000*S.toc.dt;
    x = WL.Timer.Graphics.flip_2_display_func.burn_in_N + (1:length(y));
    plot(x,y,'b.')
    y = WL.GW.main_loop.desired_flip_2_display_func;
    x = 1:length(y);
    plot(x,y,'r.')
    %xy = axis;
    %axis([ 0 max(x) xy(3) xy(4) ]);
    axis([ 0 max(x) 0 (1000*WL.Screen.ifi) ]);
    xlabel('Samples')
    ylabel('flip_to_display_func (ms)','Interpreter','none')
    legend('actual','desired');
    
    subplot(2,2,3)
    S = WL.Timer.Graphics.flip_request_2_flip.GetSummary();
    y = 1000*S.toc.dt;
    x = 1:length(y);
    plot(x,y,'b.')
    %xy = axis;
    %axis([ 0 max(x) xy(3) xy(4) ]);
    axis([ 0 max(x) 0 (1000*WL.Screen.ifi) ]);
    xlabel('Samples')
    ylabel('flip_request_to_flip (ms)','Interpreter','none')
    
    subplot(2,2,4)
    hold on;
    S = WL.Timer.Graphics.display_main.GetSummary();
    y = 1000*S.toc.dt;
    x = 1:length(y);
    plot(x,y,'b.')
    S = WL.Timer.Graphics.display_func.GetSummary();
    y = 1000*S.toc.dt;
    x = 1:length(y);
    plot(x,y,'r.')
    xy = axis;
    axis([ 0 max(x) xy(3) xy(4) ]);
    xlabel('Samples')
    ylabel('display (ms)','Interpreter','none')
    H = legend('display_main','display_func');
    set(H,'Interpreter','none');
    shg   
end

end

% JNI notes from week of 16/Sep/2019 (re-visit for Oculus display latency).
% 1. Changed 'idle_loop' timer to 'main_loop' (it times interations of main_loop).
% 2. Changed initial setting of 'display_estimate_duration'.
% 3. Cosmetic tweaks to timing plots.
% 4. Update 'desired_flip_2_display_func' only when we have new data.
% 5. Added 'display_main' timer which is the correct 'display_func' timer.

% JNI notes from week of 07/Oct/2019 (ongoing changes for WL v1_8).
% 6. Move calls to Hardware.GetLatest() and state_process() from application to main_loop (with their own timers).
% 7. Changes to wl_initialise.m and wl_trial_close.m to copy data file to server.

