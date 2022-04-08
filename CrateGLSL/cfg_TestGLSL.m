function cfg_TestGLSL(obj, cfg_name)

assignin('base','MHF_FieldFuncPath','J:\RobotFields\');

obj.overide_cfg_defaults();

%WL.cfg.RobotName = 'ROBOT_3BOT-02'; % PANSY rig
obj.cfg.RobotName = 'ROBOT_3BOT-11'; % LAVENDER rig
%obj.cfg.RobotName = 'ROBOT_3BOT-10'; % GERANIUM rig

obj.cfg.RobotForceMax = 40; % IMPORTANT! When testing, limit force to 10N
obj.cfg.DrawText = 1;

obj.cfg.OculusRift = true;
obj.cfg.OculusMonitorView = false;

obj.cfg.trial_save = false;

if ispc
    obj.cfg.ImagesRoot = 'U:/experiments/images/';
    obj.cfg.shaderpath = 'U:/experiments/shaders/';
    obj.cfg.trial_save = true;
elseif ismac
    obj.cfg.ImagesRoot = '/Volumes/wolpert-locker/users/eac2257/experiments/images/';
    obj.cfg.shaderpath = '/Volumes/wolpert-locker/users/eac2257/experiments/shaders/';
    obj.cfg.trial_save = false;
end

obj.cfg.LoadOBJs = false;

obj.cfg.MovementDuration = inf;
obj.cfg.InterTrialDelay = 0.4;
obj.cfg.RestBreakSeconds = 5;
obj.cfg.FinishDelay = 0.1;
obj.cfg.ErrorWait = 1.5;

obj.cfg.highbeep = obj.load_beeps(500,0.05);
obj.cfg.lowbeep = obj.load_beeps([250 150],[0.5 0.5]);

obj.cfg.ClearColor = [0, 0, 0]; % black

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
obj.cfg.ObjID = num2cell(1);
PreExposure.Trial.Index.ObjID = 1;
PreExposure.Permute = true; % whether to permute within block

switch upper(cfg_name) % Specify parameters unique to each experiment (VMR/FF)
    
    case 'A'
       
        A = obj.parse_trials(PreExposure);
        T = parse_tree(3*A);
        
    otherwise
        error('cfg name invalid')
end

obj.TrialData=T;
