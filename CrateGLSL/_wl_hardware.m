classdef wl_hardware < handle
    % WL_HARDWARE is an interface that controls the multiple hardware
    % objects associated with the experiments, such as the robots,
    % liberty polhemus, eye-tracker, etc. 
    
    properties
        MHF_Func = [];
        MHF_Name;
        MHF; % Mex Hardware Function codes.
             
        RobotCount=0;
        Robot;
        
        MouseCount=0;
        Mouse;
        
        EyeLinkCount=0;
        EyeLink;
        
        EyeCount=0; % What's this?
        Eye;
        
        LibertyCount=0;
        Liberty;
        
        Hardware=0;
    end
    
    methods
        function this = wl_hardware(varargin)
            % First, do the robot (if used), because it's special.
            for k=1:length(varargin) 
                if( isempty(varargin{k}) )
                    continue;
                end
                
                if strcmp(varargin{k}.ActualType,'robot')
                    this.Robot = varargin{k};
                    this.RobotCount = this.Robot.RobotCount;
                    this.MHF_Func = this.Robot.MHF_Func;
                    this.MHF_Name = this.Robot.MHF_Name;
                    this.MHF = this.MHF_Func();
                end
            end
            
            if( isempty(this.MHF_Func) )
                this.MHF_Func = @mexHardwareFunc;
                this.MHF_Name = 'mexHardwareFunc';
                %this.MHF = this.MHF_Func(); % EAC needed to run without robot - looks like 1.8 has a fix
                % EAC: That's the only change in this wl file
            end
            
            % Now do other hardware devices.
            for k=1:length(varargin) 
                if( isempty(varargin{k}) )
                    continue;
                end
                
                if strcmp(varargin{k}.ActualType,'mouse')
                    this.Mouse = varargin{k};
                    this.MouseCount = 1;
                elseif strcmp(varargin{k}.ActualType,'eyelink')
                    this.EyeLink = varargin{k};
                    this.EyeLinkCount = 1;
                elseif strcmp(varargin{k}.ActualType,'eye')
                    this.Eye = varargin{k};
                    this.EyeCount = 1;
                elseif strcmp(varargin{k}.ActualType,'liberty')
                    this.Liberty = varargin{k};
                    this.LibertyCount = 1;
                    this.Liberty.MHF_Func  = this.MHF_Func;
                    this.Liberty.MHF_Name  = this.MHF_Name;
                    this.Liberty.MHF = this.MHF_Func();
                end
            end
            
            if (this.RobotCount > 0) || (this.EyeLinkCount > 0) || (this.LibertyCount > 0)
                this.Hardware = true;
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ok = Start(this)
            %START instantiates the robot, mouse, eyetracker and liberty
            %objects
            ok = true;
            
            if( ok && (this.RobotCount > 0) )
                ok = this.Robot.Start();
            end
            
            if( ok && (this.MouseCount > 0) )
                ok = this.Mouse.Start();
            end
            
            if( ok && (this.EyeLinkCount > 0) )
                ok = this.EyeLink.Start();
            end
            
            if( ok && (this.EyeCount > 0) )
                ok = this.Eye.Start();
            end
            
            if( ok && (this.LibertyCount > 0) )
                ok = this.Liberty.Start();
            end
            
            fprintf('Hardware Start=%d\n',ok);
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ok = Stop(this)
            %STOP stops the robot, mouse, eyetracker and liberty
            %objects
            ok = true;
            
            if( ok && (this.RobotCount > 0) )
                ok = this.Robot.Stop();
            end
            
            if( ok && (this.MouseCount > 0) )
                ok = this.Mouse.Stop();
            end
            
            if( ok && (this.EyeLinkCount > 0) )
                ok = this.EyeLink.Stop();
            end
            
            if( ok && (this.EyeCount > 0) )
                ok = this.Eye.Stop();
            end
            
            if( ok && (this.LibertyCount > 0) )
                ok = this.Liberty.Stop();
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ok = GetLatest(this, obj)
            %GETLATEST this method updates the data collection matrix of
            %every hardware device in the experiment by adding a row with
            %the latest data at the end of the matri/table.
            ok = true;
            
            if( ok && (this.RobotCount > 0) )
                ok = this.Robot.GetLatest();
            end
            
            if( ok && (this.MouseCount > 0) )
                ok = this.Mouse.GetLatest();
            end
            
            if( ok && (this.EyeLinkCount > 0) )
                ok = this.EyeLink.GetLatest();
            end
            
            if( ok && (this.EyeCount > 0) )
                ok = this.Eye.GetLatest();
            end
            
            if( ok && (this.LibertyCount > 0) )
                ok = this.Liberty.GetLatest();
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ok = DataStart(this)
            %DATASTART Initiates the mexhardware function data collection
            %loop with the robot and other hardware components in the
            %experiment. This loop updates the the data collection matrix
            %at a particular sample rate
            ok = false;
            
            if this.Hardware
                ok = this.MHF_Func(this.MHF.HARDWARE_DATA_START);
            end
            
            if this.MouseCount
                ok = this.Mouse.DataStart();
            end
            
            if this.EyeCount
                ok = this.Eye.DataStart();
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ok = DataStop(this)
            %DATASTOP instructs the mexhardware function to terminate the
            %data collection loop 
            ok = false;
            
            if this.Hardware
                ok = this.MHF_Func(this.MHF.HARDWARE_DATA_STOP);
            end
            
            if this.MouseCount > 0
                ok = this.Mouse.DataStop();
            end
            
            if this.EyeCount > 0
                ok = this.Eye.DataStop();
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [ ok,FrameData,names ] = DataGet(this)
            %DATAGET signals the mexHardWareFunc to collect the most recent
            %data frame from the datamatrix and return it in a cell array
            %structured format
            ok = false;
            FrameData = [ ];
            names = { };
            
            k = 0;
            
            if this.Hardware
                [ ok,Data,FieldNames,FieldSizes,FieldSensors ] = this.MHF_Func(this.MHF.HARDWARE_DATA_GET);
                
                % Process data only if some was returned.
                if( ok && ~isempty(Data) )
                    k = k + 1;
                    
                    names{k} = '';
                    FrameData{k}.Frames = size(Data,2)-1;
                    FieldCount = length(FieldNames);
                    
                    j = 1;
                    for i=1:FieldCount
                        n = FieldSizes(i);
                        j0 = j;
                        j = j + n;
                        j1 = j-1;
                        
                        if( FieldSensors(i) == 0 ) % Multiple sensors?
                            FrameData{k}.(FieldNames{i}) = Data(j0:j1,2:end);
                        else
                            if( n == 1 )
                                FrameData{k}.(FieldNames{i})(FieldSensors(i),:) = Data(j0:j1,2:end);
                            else
                                FrameData{k}.(FieldNames{i})(FieldSensors(i),:,:) = Data(j0:j1,2:end);
                            end
                        end
                    end
                end
            end
            
            if this.MouseCount
                k = k + 1;
                [ ok,FrameData{k} ] = this.Mouse.DataGet();
                names{k} = 'mouse_';
            end
            
            if this.EyeCount
                k = k + 1;
                [ ok,FrameData{k} ] = this.Eye.DataGet();
                names{k} = 'eye_';
            end
        end
        
        function ok = StateSet(this, State, StateTime)
            %STATESET sets a particular data state for the frames in the
            %data matrix
            if this.Hardware
                ok = this.MHF_Func(this.MHF.HARDWARE_DATA_STATE_SET, State, StateTime);
            else
                ok = true;
            end
        end
    end
end


