function wl_start_screen(WL)
global GL
%WL_START_SCREEN draws psychtoolbox experiment screeen and sets up with
%initial text and graphics.
%   WL_START_SCREEN(OBJ) Draws screen in the third monitor at full screen
%   where OBJ is the pointer to the Experiment class
%
%   WL_START_SCREEN(OBJ, W) Draws screen at position and size specified by W
%   which takes the form [X, Y, XDELTA, YDELTA] this is used for debugging
%   mode when OBJ.cfg.MouseFlag is true.

% Perform standard setup for Psychtoolbox.
PsychDefaultSetup(2);

%Initialize the OpenGL for Matlab wrapper 'mogl'.
%InitializeMatlabOpenGL(2);
if ~WL.cfg.GLSL
    InitializeMatlabOpenGL();
else
    InitializeMatlabOpenGL(1,1,0,4);
end

if( WL.cfg.SmallScreen )
    WL.cfg.ScreenIndex = 0;
    WL.cfg.OculusRift = false;
end

if( WL.cfg.OculusRift && (WL.cfg.ScreenIndex == 0) )
    WL.cfg.ScreenIndex = max(Screen('Screens'));
end

% set screen resolution (before opening window)
% to check supported list of settings, type ResolutionTest in command line
if isfield(WL.cfg,'ScreenResolution') && isfield(WL.cfg,'ScreenFrameRate')
   SetResolution(WL.cfg.ScreenIndex,WL.cfg.ScreenResolution(1),WL.cfg.ScreenResolution(2),WL.cfg.ScreenFrameRate);
end
   
% Initialise OpenGL
if WL.cfg.SmallScreen
    %WL.cfg.ScreenSize = get(WL.cfg.ScreenIndex, 'ScreenSize') .* [0 0 0.5 0.5];  %half size fullscreen
    WL.Screen.Resolution = Screen('Resolution',WL.cfg.ScreenIndex);
    if length(WL.cfg.SmallScreenScale)==1
        WL.cfg.ScreenSize = [ 0 0 (WL.Screen.Resolution.width*WL.cfg.SmallScreenScale) (WL.Screen.Resolution.height*WL.cfg.SmallScreenScale) ]; % Scaled fullscreen.
    else
        WL.cfg.ScreenSize = [ 0 0 (WL.Screen.Resolution.width*WL.cfg.SmallScreenScale(1)) (WL.Screen.Resolution.height*WL.cfg.SmallScreenScale(2)) ]; % Scaled fullscreen.
    end
end

if isempty(WL.cfg.ScreenSize)
    Screen('Preference','SkipSyncTests',1); % if fullscreeen
else
    Screen('Preference','SkipSyncTests',2); % skip sync tests for this demo
end

if WL.cfg.OculusRift
    PsychImaging('PrepareConfiguration');
    %WL.Screen.hmd = PsychVRHMD('AutoSetupHMD', 'Stereoscopic', 'LowPersistence FastResponse',1);
    WL.Screen.hmd = PsychVRHMD('AutoSetupHMD', 'Stereoscopic', 'LowPersistence',1);
    if isempty(WL.Screen.hmd)
        WL.cfg.OculusRift=false;
        fprintf('No VR-HMD available - simulation mode\n');
        WL.Screen.projMatrix=eye(4);
        WL.Screen.projMatrix(3,4)=+20
    else
        fprintf('VR-HMD available - started\n');
        PsychVRHMD('SetHSWDisplayDismiss',WL.Screen.hmd,-1); %do not show health and safety warning
    end
    [window, windowRect] = PsychImaging('OpenWindow', WL.cfg.ScreenIndex);  %need full screen for HMD
    WL.Screen.projMatrix = PsychVRHMD('GetStaticRenderParameters', WL.Screen.hmd, 5 , 100); % EAC: set near and far clipping planes (cm)
elseif WL.cfg.GLSL
    WL.Screen.projMatrix=eye(4);
    WL.Screen.projMatrix(3,3) = -1;
    WL.Screen.projMatrix(3,4) = -.020;
    WL.Screen.projMatrix(4,3) = -1;
    WL.Screen.projMatrix(4,4) = 0;
    [window, windowRect] = PsychImaging('OpenWindow', WL.cfg.ScreenIndex, 0.5*[1 1 1], WL.cfg.ScreenSize, 32, 2, 5);
else
    [window, windowRect] = PsychImaging('OpenWindow', WL.cfg.ScreenIndex, 0.5*[1 1 1], WL.cfg.ScreenSize, 32, 2);
    WL.Screen.projMatrix=eye(4);
end

WL.Screen.window = window;
WL.Screen.windowRect = windowRect;
WL.Screen.cent(1,1) = windowRect(3) / 2;
WL.Screen.cent(2,1) = windowRect(4) / 2;
WL.Screen.cent(3,1) = 0;

WL.Screen.ifi = Screen('GetFlipInterval',WL.Screen.window);
WL.Screen.ar = windowRect(3) / windowRect(4);

if( ~isfield(WL.Screen,'xcm') || ~isfield(WL.Screen,'ycm') )
    if( ismac() || WL.cfg.MouseFlag )
        WL.cfg.graphics_config.Xmin_Xmax = [ -25 25 ];
        WL.cfg.graphics_config.Ymin_Ymax = WL.cfg.graphics_config.Xmin_Xmax / WL.Screen.ar;
    else
        WL.cfg.graphics_config = MexReadConfig('GRAPHICS');
    end
    
    WL.Screen.xcm = WL.cfg.graphics_config.Xmin_Xmax;
    WL.Screen.ycm = WL.cfg.graphics_config.Ymin_Ymax;
end

Screen('BeginOpenGL',WL.Screen.window);
%glViewport(0,0,RectWidth(windowRect),RectHeight(windowRect));
if ~WL.cfg.GLSL
    glViewport(0,0,RectWidth(windowRect),RectHeight(windowRect));
    
    glColorMaterial(GL.FRONT_AND_BACK,GL.AMBIENT_AND_DIFFUSE);
    glEnable(GL.COLOR_MATERIAL);
    
    % Enable lighting
    glEnable(GL.LIGHTING);
    % Define a local light source
    glEnable(GL.LIGHT0);
    % Our point lightsource is at position (x,y,z) == (1,2,3)
    glLightfv(GL.LIGHT0, GL.POSITION, [1 2 3 0]);
    %glLightfv(GL.LIGHT0, GL.POSITION, [0 1 1 0]);
    
    glEnable(GL.BLEND);
    glBlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
    
    glEnable(GL.LINE_SMOOTH);
    
    % Lets set up a projection matrix, the projection matrix defines how images
    % in our 3D simulated scene are projected to the images on our 2D monitor
    glMatrixMode(GL.PROJECTION);
    glLoadMatrixd(WL.Screen.projMatrix);
    
    if ~WL.cfg.OculusRift
        glOrtho(WL.Screen.xcm(1), WL.Screen.xcm(2), WL.Screen.ycm(1),WL.Screen.ycm(2), -10, 200);
    end
    
    % Setup modelview matrix: This defines the position, orientation and
    % looking direction of the virtual camera that will be look at our scene.
    glMatrixMode(GL.MODELVIEW);
    glLoadIdentity;
end

%Screen('BlendFunction', WL.Screen.window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Enable proper occlusion handling via depth tests
glEnable(GL.DEPTH_TEST);
glEnable(GL.CULL_FACE);

% set and clear out the backbuffer
glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
glClearDepth(1.0);
%glClear(bitor(GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT));

% End the OpenGL context now that we have finished setting things up
Screen('EndOpenGL', WL.Screen.window);

% Get a time stamp with a flip
%Screen('AsyncFlipBegin', WL.Screen.window);
% ^^^ EAC - small screen glsl breaks if we do this...
% % PTB-ERROR: Tried to draw into an onscreen window while it has an async-flip pending.
% % PTB-ERROR: This is only allowed if you enable the Psychtoolbox imaging pipeline (see 'help PsychImaging').
% % PTB-ERROR: The pipeline is currently not fully enabled by your script, so drawing won't work.
% % PTB-ERROR: Operation aborted, expect corrupted visual stimuli until you fix this.
% % 
% % Error in function BeginOpenGL: 	Usage error
% % Tried to draw into onscreen window with async flip pending and imaging pipeline off. Forbidden!


