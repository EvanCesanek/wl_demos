function cfg_ObjectLiftFromAbove(WL,cfg_name)

WL.overide_cfg_defaults();

%WL.cfg.RobotName = 'ROBOT_3BOT-02'; % PANSY rig
WL.cfg.RobotName = 'ROBOT_3BOT-11'; % LAVENDER rig
%WL.cfg.RobotName = 'ROBOT_3BOT-10'; % GERANIUM rig

% User-defined force-field functions used in demos are found here:
% if ismac
%     assignin('base','MHF_FieldFuncPath','/Volumes/wolpert-locker/users/jni2104/RobotFields/');
%     assignin('base','MHF_DevicePath','/Volumes/wolpert-locker/users/jni2104/MHF_Device/');
% else
assignin('base','MHF_FieldFuncPath','J:\RobotFields\');
% end

WL.cfg.GLSL = true;
WL.cfg.OculusRift = false;
WL.cfg.OculusGrid = false;
%WL.cfg.ScreenIndex = 1;
WL.cfg.predict_display_timing = -1; % Don't predict when to call display_func() to avoid white flashes.

WL.cfg.RobotForceMax = 40; % IMPORTANT! When testing, limit force to 10N

WL.cfg.OculusMonitorView = false; %true;
WL.cfg.OculusMonitorUpdateHz = 10;
%WL.cfg.RotateScreen = true; % true on VIOLET & BEGONIA rigs
WL.cfg.MouseFlag = true;
WL.cfg.SmallScreen = true;
WL.cfg.SmallScreenScale = 0.45; % NB on retina, 0.5 = fullscreen
%WL.cfg.ScreenSize = 2*[100 100 640 640*16.8/29.8]; 
%WL.cfg.ClearColor = [ 0 0 0 ];
%WL.cfg.trial_save = true;
%WL.cfg.verbose = 0;
%WL.cfg.vol = 0.5;
%WL.cfg.Debug = true;

WL.cfg.plot_timing = 0;

WL.cfg.SpringConstant = -30.0;
WL.cfg.DampingConstant = -0.03;

WL.cfg.HomePosition = zeros(3,1) + [0 0 -15]'; % [0 -8 -5];
WL.cfg.StationarySpeed = 5; % cm/s
WL.cfg.StationaryTime = 0.1; % s

WL.cfg.AEfifth = WL.load_beeps([440 0 660],[0.05 0.05 0.10]);
WL.cfg.midA = WL.load_beeps([440],[0.05]);
WL.cfg.highA = WL.load_beeps([880],[0.05]);
WL.cfg.lowbeep = WL.load_beeps([250 150],[0.5 0.5]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a minimal TrialData table, this version of WL expects it.

Junk = num2cell([ 1 ]);
WL.cfg.Junk = Junk;

Demo.Trial.Index.Junk = [ 1 ];

A = WL.parse_trials(Demo);
T = parse_tree(2*A);

WL.TrialData = T;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
