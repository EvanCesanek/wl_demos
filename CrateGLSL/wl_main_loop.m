function wl_main_loop(WL, length_of_test, predict)
global GL
%WL_MAIN_LOOP runs for the duration of the experiment processing the states
% and updating the screen, audio and other IO based on the
% state. It does thus by calling the core functions required to display and advance the state
%   machine in the experiments (i.w. WL.display_func, WL.idle, ...).
%
% Returns timing statistics for the graphics rendering cycle.
%
%   Calling WL.main_loop automatically handles passing of the OBJ parameter
%   WL.main_loop == wl_main_loop(WL).
%
%   S=WL_MAIN_LOOP(OBJ, length_of_test) takes in an additional argument which
%   terminates the main loop after length_of_test seconds have passed.

if nargin < 2
    length_of_test = inf; % not testing run forever.
end

if nargin < 3
    predict = true; %should we adapt the time delays
end

%%%%%%%%%% set up adaptive timing if required %%%%%
if predict
    display_estimate_duration = 0.004 ; % Initial value prior to adapting
else
    display_estimate_duration = 0; % set disp_pred to 0 if prediction disabled
end

if ~isfield(WL.GW, 'desired_flip_request_2_flip')
    desired_flip_request_2_flip = 0.0015;
else
    desired_flip_request_2_flip = WL.GW.desired_flip_request_2_flip;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%set up circular storage bufffers for stats
Nb = 20000; % buffer length
vbl_timestamp_buffer                 = wl_circbuffer(Nb);
flip_timestamp_buffer                = wl_circbuffer(Nb);
desired_flip_2_display_func_buffer   = wl_circbuffer(Nb);

desired_idle_func_freq = 1000;  %run at 1000Hz loop

%request a flip to start
VBLTimestamp = Screen('Flip',  WL.Screen.window);
if WL.cfg.OculusMonitorView && ~WL.cfg.MouseFlag % EAC: for additional window
    Screen('Flip',  WL.Screen.window2);
end
WL.Screen.flipped = 0;

Priority(MaxPriority(WL.Screen.window));

% Set the mouse to the middle of the screen (if mac)
if ismac
    SetMouse(WL.Screen.cent(1), WL.Screen.cent(2), WL.Screen.window);
end

%number of trials to run
WL.GW.TrialCount  = rows(WL.TrialData);
WL.TrialNumber = 1;

wl_trial_setup(WL); %read in first trial from TrialData table

start_time = GetSecs();
Exit = 0;
if ~WL.cfg.Debug 
    HideCursor;
end
% if WL.cfg.OculusRift
%     Xmin = -0.4;
%     Xmax = 0.4;
%     Ymin = -0.4;
%     Ymax = 0.1;
%     Zmin = 2.3;
%     Zmax = 2.8;
%     midpointX = (Xmin + Xmax) / 2;
%     midpointY = (Ymin + Ymax) / 2;
%     midpointZ = (Zmin + Zmax) / 2;
%     wl_oculus_grid(Xmin,Xmax,Ymin,Ymax,Zmin,Zmax);
% end

%%%%%%%% Start experiment %%%%%%%%%%%%%
while ~Exit % && test_count < length(delays)
    %WL.Timer.Graphics.idle_loop.Loop; % 1.6
    WL.Timer.Graphics.main_loop.Loop; % 1.8
    
    %%%%%%%%%%% Idle loop %%%%%%%%%%%
    if wl_everyhz(desired_idle_func_freq)
        WL.Timer.Graphics.idle_func_2_idle_func.Loop;
        
        WL.Timer.Graphics.idle_func.Tic;
        WL.idle_func();
        WL.Timer.Graphics.idle_func.Toc;
        
        %why are these here????? delete
        %WL.State.From = 0;
        %WL.State.To = 0;
        
        % Check all keyboards and stop on first key pressed
        [ pressed,keyname ] = WL.keyboard_read();
     
        % Process keyboard input.
        if( pressed )
            % EAC: FIXED keyname=='Q' vector logical error
            if( contains(keyname,'ESC') || strcmp(keyname,'Q') )
                % Key pressed to exit experiment.
                Exit = 1; 
            else
                % Any other key is passed to the application.
                WL.keyboard_func(keyname);
            end
        end
        
        % Conditions to exit the experiment.
        if( WL.GW.ExitFlag || ((GetSecs()-start_time) > length_of_test) )
            Exit = 1;
        end
        
        %can read the mousebutton but not used in this example
        %[~, ~, MouseButton] = GetMouse(WL.Screen.window);
        
    end
    
    % EAC: for additional window
    if WL.cfg.OculusMonitorView && wl_everyhz(WL.cfg.OculusMonitorUpdateHz) && ~WL.cfg.MouseFlag
        cameraPosition = [0 -26 14];
        Screen('BeginOpenGL', WL.Screen.window2);
        glMatrixMode(GL.MODELVIEW);
        glLoadIdentity();
        glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
        glClear();
        WorkspaceScale = 0.01;
        glScaled(WorkspaceScale,WorkspaceScale,WorkspaceScale);
        glRotated(-60,1,0,0); % Tilt forward to align OpenGL negative z (straight-ahead) with 3BOT negative z (down)
        glTranslated(-cameraPosition(1), -cameraPosition(2), -cameraPosition(3)); % Translate to 3BOT origin
        Screen('EndOpenGL', WL.Screen.window2);
        
        WL.display_func(WL.Screen.window2);
        Screen('Flip',WL.Screen.window2);
    end
    
    % this sets the time after the last flip where we want to draw and
    % request a flip so as to be done in time to catch the next flip
    % disp_pred estimates how long the display takes so as to adapt to this
    %EAC: THESE AREN'T CURRENTLY USED
    %desired_flip_2_display_func = WL.Screen.ifi - desired_flip_request_2_flip - display_estimate_duration;
    %desired_flip_2_display_func_buffer.set(desired_flip_2_display_func);
    
    %%%%%%%%%% if ready, draw next frame and request a screen flip %%%%%%%%%%
    %EAC: THE SECOND PART OF THIS IS ALWAYS TRUE
    if WL.Screen.flipped == 1 %&& (GetSecs() - VBLTimestamp > 0*desired_flip_2_display_func)
        WL.Timer.Graphics.flip_2_display_func.Toc;
        
        if wl_is_error(WL)
            
            for renderpass = 0:1  %loops over the eye
                Screen('SelectStereoDrawbuffer',WL.Screen.window, 1-renderpass);
                Screen('BeginOpenGL', WL.Screen.window);
                glClearColor(.75,0,0,0); % Red screen.
                glClear;
                Screen('EndOpenGL', WL.Screen.window);
                if ~renderpass % EAC: right eye only because it's hard to change vergence
                    % EAC: Also remove fliph and flipv flags so it reads normally on oculus 
                    wl_draw_text(WL, WL.GW.error_msg, 'center', 'center', 'fliph',0, 'flipv',0, 'fontsize', 40);
                    
                end
            end
            
            % EAC: Needed to put the teapot in display_func so it appears in proper 3BOT/Oculus coordinates 
%         elseif WL.State.Current == WL.State.REST
%             for renderpass = 0:1  %loops over the eye
%                 Screen('SelectStereoDrawbuffer',WL.Screen.window, 1-renderpass);
%                 Screen('BeginOpenGL', WL.Screen.window);
%                 glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
%                 glClear();
%                 Screen('EndOpenGL', WL.Screen.window);
%                 wl_draw_teapot(WL);
%             end
        else
            WL.Timer.Graphics.display_func.Tic();
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~WL.cfg.OculusRift
                Screen('BeginOpenGL', WL.Screen.window);
                glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
                glClear();
                Screen('EndOpenGL', WL.Screen.window);
                
                WL.display_func();
            else
                for eyeIndex = 0:1 % left eye (0) then right eye (1)
                    
                    WL.eyeIndex = eyeIndex;

                    if WL.cfg.MouseFlag && eyeIndex==1
                        continue
                    end

                    % Select the eye buffer
                    Screen('SelectStereoDrawbuffer', WL.Screen.window, eyeIndex);
                    
                    WL.display_func(WL.Screen.window);

                end
                
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            WL.Timer.Graphics.display_func.Toc();
            
            % EAC: 'predict' functionality is not working
%             if (WL.Timer.Graphics.display_func.toc_count> 50) && predict
%                 display_func_durations = WL.Timer.Graphics.display_func.GetSummary().toc.dt;
%                 display_estimate_duration =WL.Timer.Graphics.display_func.GetSummary().toc.dtmax;
%             end
        end
        
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
            % Increments all frame counters if trigger is 1
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
PsychPortAudio('Close');
if WL.cfg.OculusRift && ~WL.cfg.MouseFlag
    PsychVRHMD('Stop',WL.Screen.hmd);
end
sca

wl_timer_results(WL.Timer.Graphics);

%stop all keyboard queues
for k=1:length(WL.Keyboard.key_id)
    KbQueueStop(WL.Keyboard.key_id(k));
end
%ListenChar(0)

WL.trial_close(); % saves code and trialdata to mat file


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
WL.GW.main_loop.desired_flip_2_display_func = 1000 * desired_flip_2_display_func_buffer.getall;
WL.GW.main_loop.Nb = Nb;

if WL.cfg.plot_timing
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    figure(1)
    clf
    plot(WL.GW.main_loop.vbl_timestamp_buffer_diff)
    aa=axis;
    hold on
    plot(aa(1:2),[WL.Screen.ifi WL.Screen.ifi]*1000,'g')
    plot(aa(1:2),2*[WL.Screen.ifi WL.Screen.ifi]*1000,'r')
    plot(aa(1:2),3*[WL.Screen.ifi WL.Screen.ifi]*1000,'r')
    shg
    
    figure(2)
    clf
    subplot(2,2,1)
    S=WL.Timer.Graphics.flip_2_flip.GetSummary;
    
    plot(1000*S.loop.dt,'o')
    xlabel('Samples')
    ylabel('Flip-to-flip times (ms)')
    hold on
    %plot([S.loop.t(1) S.loop.t(end)],[WL.Screen.ifi WL.Screen.ifi]*1000,'r')
    
    subplot(2,2,2)
    S = WL.Timer.Graphics.flip_2_display_func.GetSummary();
    plot((1000*S.toc.dt),'o')
    xlabel('Samples')
    ylabel('Flip-to-display-func (ms)')
    
    subplot(2,2,3)
    S=   WL.Timer.Graphics.flip_request_2_flip.GetSummary;
    plot((1000*S.toc.dt),'o')
    xlabel('Samples')
    ylabel('flip-request-to-flip (ms)')
    
    subplot(2,2,4)
    S=   WL.Timer.Graphics.display_func.GetSummary;
    plot((1000*S.toc.dt),'o')
    xlabel('Samples')
    ylabel('displ-func (ms)')
    shg
    
end

