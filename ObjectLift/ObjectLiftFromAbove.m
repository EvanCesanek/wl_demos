classdef ObjectLiftFromAbove < wl_experiment_v1_8
    properties
        ButtonPressed = false;
        
        FieldState = logical(false);
        
        ActiveObject = 0;
        ActiveObjectDistance = 0;
        TopOfObject = 0;
        SelectedObject = 0;
        
        ObjectHandOffset = zeros(3,1);
        
        % THESE MUST MATCH THE FORCES FUNCTION: RobotFieldMassLiftFromAbove.m
        NumObjects = 3;
        RequiredLiftDistance = 2;
        SurfaceZ = -15;
        ObjectHomePosns = [ -10 0 10;   % initial x posns
                              -3 0  3];  % initial y posns
        ObjectHeight = [ 8.3 13.9   17.3 ];
        ObjectRadius = [ 3.4  4.0    4.5 ];
        %%%%
       
        IOD = 0;
        ShaderProgram = 0;
        textures = [];
        defaultTexture = [];
        depthTexture = [];
        Camera = [];
        Light = [];
        
        % Declare meshes & associated VAOs
        Cube = [];
        
        isMac = ismac; % seems unnecessary...
        
        eyeIndex = 0; % not the best solution - see wl_main_loop.m

        glslVersion = [];
    end
    
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Must implement ALL abstract methods or matlab will complain.
        
        function run(WL, varargin)
            try
                WL.GUI = wl_gui('ObjectLiftFromAbove','test','cfg_ObjectLiftFromAbove','TEST',varargin{:});
                % These are custom parameters specific for this experiment.
                %WL.GUI.addParam('array', 'trials_to_run', []);
                %WL.GUI.addParam('numeric', 'reload_table', 0);
                
                ok = WL.initialise();
                if ~ok
                    WL.printf('Initialisation aborted\n')
                    return;
                end
                %WL.my_initialise();
                
                if ~WL.cfg.MouseFlag
                    WL.Robot = WL.robot(WL.cfg.RobotName);
                else
                    WL.Robot = WL.mouse(WL.cfg.RobotName);
                end
                
                WL.Hardware = wl_hardware(WL.Robot);
                
                ok = WL.Hardware.Start();
                if( ok ) % This will eventually happen inside wl_robot
                    ok = WL.Robot.ForceMaxSet(WL.cfg.RobotForceMax);
                end
                
                if ok
                    %WL.test_timings(0.5);
                    WL.main_loop();
                end
                WL.Hardware.Stop();
                clear mex
                
            catch msg
                sca
                ListenChar(0);
                
                if ~isempty(WL.Hardware)
                    WL.Hardware.Stop();
                end
                
                clear mex
                % [~,M]= inmem  % to see which mex are loaded
                
                error_msg = getReport(msg);
                error(error_msg)
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function my_initialise(WL, varargin)
            global GL
            
            WL.state_init('START','RUNNING','REST');

            Screen('BeginOpenGL', WL.Screen.window);
            AssertGLSL;
            %moglcore('DEBUGLEVEL', 2); % raised debug level
            % The NVIDIA graphics cards on the 3BOT lab computers support the latest GLSL 4.60
            % Other systems including new MBPs may only have 1.20 (PTB doesn't play well with Apple)
            % Lab computers will probably be backwards compatible with 1.20
            WL.glslVersion = glGetString(GL.SHADING_LANGUAGE_VERSION);
            Screen('EndOpenGL', WL.Screen.window);

            fprintf('\nGLSL version = %s\n\n',WL.glslVersion);
            if strcmp(WL.glslVersion,'1.20')
                vspath = '../shaders/Standard120.vert';
                fspath = '../shaders/Standard120.frag';
                vspath2 = '../shaders/StandardShadow120.vert';
                fspath2 = '../shaders/StandardShadow120.frag';
            else
               vspath = '../shaders/Standard.vert';
               fspath = '../shaders/Standard.frag';
               vspath2 = '../shaders/StandardShadow.vert';
               fspath2 = '../shaders/StandardShadow.frag';
            end

            % Shaders
            WL.ShaderProgram = WL.init_shader_program(vspath,fspath);
            WL.Light.Shadows.ShaderProgram = WL.init_shader_program(vspath2,fspath2);
            
            % Camera
            WL.init_camera();
            
            % Lights (% w = 0 for directional light, w = 1 for point light)
            WL.Light.Position =  [-10 -10 100 0]; % Remember to change NR_LIGHTS in frag shader if you add lights
            % TODO: Fix light position matrix so each *column* is the position vector for one light (not each row)
            WL.Light.Shadows.TextureUnit = 8; % Remember not to use this texture unit later
            WL.Light.Shadows.TextureSize = 4096;
            if ~WL.cfg.Shadows
                WL.Light = rmfield(WL.Light, 'Shadows');
            end
            WL.init_lighting();
            
            % Default Texture
            % This is a single white pixel to allow solid RGB with no texture maps
%             glActiveTexture(GL.TEXTURE0);
%             WL.defaultTexture = glGenTextures(1);
%             glBindTexture(GL.TEXTURE_2D, WL.defaultTexture);
%             glTexImage2D(GL.TEXTURE_2D, 0, GL.RGBA, 1, 1, 0, GL.RGBA, GL.UNSIGNED_BYTE, [255 255 255 255]);
            
            % Additional Textures
            WL.init_textures({'../images/white.png', '../images/container2.png', '../images/container2_specular.png'}, [0 1 2]);
            
            % Game Objects
            WL.Cube = WL.gen_cube_mesh();
            WL.Cube = WL.init_vao(WL.Cube);
            for oi = 1:3
                WL.Cube = WL.instantiate(WL.Cube);
                WL.Cube = WL.set_model_param(WL.Cube, 'scale', oi, [WL.ObjectRadius(oi)*2 WL.ObjectRadius(oi)*2 WL.ObjectHeight(oi)]);
                WL.Cube = WL.set_model_param(WL.Cube, 'position', oi, [WL.ObjectHomePosns(:,oi); WL.SurfaceZ+WL.ObjectHeight(oi)/2]);
                WL.Cube.diffuseMap(oi) = 1;
                WL.Cube.specularMap(oi) = 2;
            end
            
            WL.Cube = WL.instantiate(WL.Cube);

            % start the cursor far from the workspace to ensure nothing funny happens in state_process  
            WL.Cube = WL.set_model_param(WL.Cube, 'position', 4, [0 -100 100]);
            WL.Cube = WL.set_model_param(WL.Cube, 'scale', 4, [1 1 0.5]);
            WL.Cube.diffuseColor{4} = [0 1 0];
            %WL.Cube.diffuseMap(4) = 0;
            
            WL.Cube = WL.instantiate(WL.Cube);
            WL.Cube = WL.set_model_param(WL.Cube, 'scale', 5, [100 100 0.05]);
            WL.Cube = WL.set_model_param(WL.Cube, 'position', 5, [0 0 WL.SurfaceZ-0.025]);
            WL.Cube.diffuseColor{5} = [.5 .5 .5];
            %WL.Cube.diffuseMap(5) = 0;
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function idle_func(WL)
            if WL.Robot.Active
                %WL.Cube.position(:,4) = WL.Robot.Position;
                %WL.Cube.modelMatrixUpdated(4) = true;
                WL.Cube = WL.set_model_param(WL.Cube, 'position', 4, WL.Robot.Position+[0 0 0.25]');
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function keyboard_func(WL,keyname)
            WL.printf('Key pressed: %s\n',keyname);
%             WL.FieldState = ~WL.FieldState;
%             ok = WL.Robot.FieldUserStateSet(double(WL.FieldState));
%             WL.printf('FieldState=%d, ok=%d\n',WL.FieldState,ok);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function display_func(WL)
            global GL
            

            if isfield(WL.Light,'Shadows') && WL.eyeIndex==0
                Screen('BeginOpenGL', WL.Screen.window);
                glUseProgram(WL.Light.Shadows.ShaderProgram);
                glBindFramebuffer(GL.FRAMEBUFFER, WL.Light.Shadows.ShadowMapFBO);
                glViewport(0, 0, WL.Light.Shadows.TextureSize, WL.Light.Shadows.TextureSize);
                glClear(bitor(GL.COLOR_BUFFER_BIT, GL.DEPTH_BUFFER_BIT));
                if( WL.State.Current == WL.State.RUNNING )
                    % gen_cube_mesh has CW winding... TODO: make winding order an object parameter so it can be set flexibly here
                    glFrontFace(GL.CW);
                    WL.Cube = WL.draw_object_shadow(WL.Cube);
                    %WL.draw_object_shadow(WL.Cube);
                end
                glBindFramebuffer(GL.FRAMEBUFFER, 0);
    
                glUseProgram(0);
                Screen('EndOpenGL', WL.Screen.window);
            end
            
            % Select the eye buffer
            if WL.cfg.Stereo
                Screen('SelectStereoDrawbuffer',WL.Screen.window, WL.eyeIndex);
            end
            Screen('BeginOpenGL', WL.Screen.window);

            % Reset viewport and clear
            glViewport(0,0,RectWidth(WL.Screen.windowRect),RectHeight(WL.Screen.windowRect));
            glClear(bitor(GL.COLOR_BUFFER_BIT, GL.DEPTH_BUFFER_BIT));

            glUseProgram(WL.ShaderProgram);
            
            % To vertex shader (for lighting calculations)
            viewPosLoc = glGetUniformLocation(WL.ShaderProgram, 'viewPos');
            glUniform3fv(viewPosLoc, 1, WL.Camera.Position(:,WL.eyeIndex+1));

            % To fragment shader (view matrix)
            viewMatLoc = glGetUniformLocation(WL.ShaderProgram, 'view');
            glUniformMatrix4fv(viewMatLoc, 1, GL.FALSE, WL.Camera.View(:,:,WL.eyeIndex+1));
            
            if( WL.State.Current == WL.State.RUNNING )
                % gen_cube_mesh has CW winding... TODO: make winding order an object parameter so it can be set flexibly here
                glFrontFace(GL.CW);
                WL.Cube = WL.draw_object(WL.Cube);
                %WL.draw_object(WL.Cube);
            end
            
            glUseProgram(0);
            Screen('EndOpenGL', WL.Screen.window)

        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function flip_func(WL)
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function state_process(WL)
            if( any(~WL.Robot.Active) ) % If robot is not active, abort current trial.
                ok = WL.Robot.FieldNull();
                WL.state_next(WL.State.START);
            end
            
            switch WL.State.Current % State processing.
                case WL.State.START % Setup details of next trial, but only when robot stationary and active.
                    if( all(WL.Robot.Active) && (strcmp(WL.Robot.ActualType,'mouse') || (WL.Robot.Position(2) < (WL.ObjectHomePosns(2,1)-max(WL.ObjectRadius)))) )
                        
                        % re-initialize objects positions
                        for oi = 1:3
                            WL.Cube = WL.set_model_param(WL.Cube, 'position', oi, [WL.ObjectHomePosns(:,oi); WL.SurfaceZ+WL.ObjectHeight(oi)/2]);
                        end

                        PlaceholderWeightInput = 1;
                        ok = WL.Robot.FieldUser('RobotFieldMassLiftFromAbove',PlaceholderWeightInput,WL.cfg.SpringConstant,WL.cfg.DampingConstant,double(WL.FieldState));
                        if( ~ok )
                            WL.GW.ExitFlag = true;
                        end

                        ok = WL.Robot.RampUp();
                        WL.state_next(WL.State.RUNNING);
                    end
                    
                case WL.State.RUNNING % Simulation running.
                    % NB can't use isfield here, because UserFieldOutput is often empty so will return false
                    if ismember('UserFieldOutput',fieldnames(WL.Robot)) && ~isempty(WL.Robot.UserFieldOutput{1}) 
                        if( WL.Robot.UserFieldOutput{1}.SelectedObject ~= WL.SelectedObject )
                            if( WL.SelectedObject == 0 )
                                WL.find_nearest_object();
                                WL.ObjectHandOffset = WL.Cube.position(:,WL.ActiveObject) - WL.Robot.Position;
                                WL.play_sound(WL.cfg.highA);
                            else
                                WL.Cube = WL.set_model_param(WL.Cube, 'position', WL.ActiveObject, WL.SurfaceZ + WL.ObjectHeight(WL.ActiveObject)/2, 3);
                                WL.play_sound(WL.cfg.midA);
                            end
                            
                            WL.SelectedObject = WL.Robot.UserFieldOutput{1}.SelectedObject;
                        end
                        
                        if( WL.SelectedObject > 0 )
                            WL.Cube = WL.set_model_param(WL.Cube, 'position', WL.ActiveObject, WL.Robot.Position + WL.ObjectHandOffset);
                            tmp = (WL.cfg.HomePosition(3)+WL.ObjectHeight(WL.ActiveObject)/2);
                            if WL.Cube.position(3,WL.ActiveObject) < tmp
                                WL.Cube = WL.set_model_param(WL.Cube, 'position', WL.ActiveObject, tmp, 3);
                            end
                            if WL.Robot.Position(3) <= WL.TopOfObject
                                WL.Cube = WL.set_model_param(WL.Cube, 'position', WL.ActiveObject, WL.SurfaceZ + WL.ObjectHeight(WL.ActiveObject)/2, 3);
                            end
                        end                            
                    end
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function trial_start(WL)
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function miss_trial(WL,MissTrialType)
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function [] = find_nearest_object(WL)
            Distance = zeros(1,WL.NumObjects);
            % Figure out which object is nearest
            for obj = 1:WL.NumObjects
                d = WL.Robot.Position(1:2)-WL.Cube.position(1:2,obj);
                Distance(obj) = d'*d;
            end
            % Set that as the ActiveObject
            [WL.ActiveObjectDistance, WL.ActiveObject] = min(Distance);
            % Get the properties of the ActiveObject
            WL.TopOfObject = WL.SurfaceZ+WL.ObjectHeight(WL.ActiveObject);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function shaderprogram = init_shader_program(WL,vspath,fspath)
            global GL
            Screen('BeginOpenGL', WL.Screen.window);

            % Shader Initialization
            % We must compile a Shader Program that contains two Shaders: Vertex shader & Fragment shader
            % Create new program object and get handle to it
            shaderprogram = glCreateProgram;

            % I. VERTEX SHADER
            % 1. Indicate the shader type
            shadertype = GL.VERTEX_SHADER; %GEOMETRY_SHADER %FRAGMENT_SHADER; %TESS_CONTROL_SHADER; %TESS_EVALUATION_SHADER;
            % 2. Read shader source code from file
            fid = fopen(vspath, 'rt');
            shadersrc = fread(fid);
            fclose(fid);
            % 3. Create shader
            shader_handle = glCreateShader(shadertype);
            % 4. Assign the source code
            glShaderSource(shader_handle, shadersrc);
            % 5. Compile the shader:
            glCompileShader(shader_handle);
            % 6. Attach the shader to the program
            glAttachShader(shaderprogram, shader_handle);

            % II. FRAGMENT SHADER
            % 1. Indicate the shader type
            shadertype = GL.FRAGMENT_SHADER; %TESS_CONTROL_SHADER; %TESS_EVALUATION_SHADER;
            % 2. Read shader source code from file
            fid = fopen(fspath, 'rt');
            shadersrc = fread(fid);
            fclose(fid);
            % 3. Create shader
            shader_handle = glCreateShader(shadertype);
            % 4. Assign the source code
            glShaderSource(shader_handle, shadersrc);
            % 5. Compile the shader:
            glCompileShader(shader_handle);
            % 6. Attach the shader to the program
            glAttachShader(shaderprogram, shader_handle);

            % --> After both/all shaders have been attached, link the shader program
            glLinkProgram(shaderprogram);
            
            Screen('EndOpenGL', WL.Screen.window);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function Mesh = gen_cube_mesh(WL)
            vertices = ...
                       ... % positions          normals           texture coords
                            ... % REAR
                 moglsingle([-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0, ...
                              0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  0.0, ...
                              0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0, ...
                             -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  1.0, ...
                            ... % RIGHT
                              0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  0.0, ...
                              0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0, ...
                              0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  1.0, ...
                              0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0, ...
                            ... % FRONT
                              0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0, ...
                             -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  0.0, ...
                             -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0, ...
                              0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  1.0, ...
                            ... % LEFT
                             -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0,  0.0, ...
                             -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  1.0,  0.0, ...
                             -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0,  1.0, ...
                             -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  0.0,  1.0, ...
                            ... % TOP
                             -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  0.0, ...
                              0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0,  0.0, ...
                              0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  1.0, ...
                             -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0,  1.0, ...
                            ... % BOTTOM
                             -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  0.0, ...
                             -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0, ...
                              0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  1.0, ...
                              0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0]);

            %numVerts = 24;
            numFloatsPerVert = 8;
            verticesInfo = whos('vertices');
            Mesh.sizeOfVerticesInBytes = verticesInfo.bytes;
            Mesh.vertexStride = numFloatsPerVert * (Mesh.sizeOfVerticesInBytes/numel(vertices));
            Mesh.byteOffsetToNormal = 3 * (Mesh.sizeOfVerticesInBytes/numel(vertices)); % skip 3 position floats
            Mesh.byteOffsetToTexCoord = 6 * (Mesh.sizeOfVerticesInBytes/numel(vertices)); % skip 3 position & 3 normal floats
            Mesh.vertices = vertices;
            
            indices = uint32( ...
                [0 1 2, ...
                2 3 0, ...
                4 5 6, ...
                6 7 4, ...
                8 9 10, ...
                10 11 8, ...
                12 13 14, ...
                14 15 12, ...
                16 17 18, ...
                18 19 16, ...
                20 21 22, ...
                22 23 20]); % temporary variable 'indices' ~= WL.indices (bc WL.indices doesn't work with whos)
            indicesInfo = whos('indices');
            Mesh.sizeOfIndicesInBytes = indicesInfo.bytes;
            %numFaces = 12;
            %sizeOfIndexDatum = sizeOfIndicesInBytes/numFaces;
            Mesh.indices = indices; % Now set WL.indices (see note above)
            
            Mesh = WL.init_model_params(Mesh);
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function Mesh = init_model_params(WL, Mesh)
            Mesh.position = [];
            Mesh.orientation = [];
            Mesh.scale = [];
            Mesh.modelMatrix = [];
            Mesh.invModelMatrix = [];
            Mesh.modelMatrixUpdated = [];
            Mesh.count = 0;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function object = set_model_param(WL, object, param, oi, value, varargin)
            % option to provide a 'value' index (1,2,3) = (X,Y,Z)
            % in addition to the object index (1,...,numMeshInstances)
            
            if ~isempty(varargin) && length(value)==1
                object.(param)(varargin{1},oi) = value;
            elseif length(value) == 3
                object.(param)(:,oi) = value;
            end
            
            object.modelMatrixUpdated(oi) = true;
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function object = instantiate(WL, object)
            object.enabled = true;
            object.count = object.count + 1;
            object.position(:,object.count) = zeros(3,1);
            object.orientation(:,object.count) = zeros(3,1);
            object.scale(:,object.count) = zeros(3,1);
            object.modelMatrix(:,:,object.count) = eye(4);
            object.invModelMatrix(:,:,object.count) = eye(4);
            object.modelMatrixUpdated(object.count) = true;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function object = destroy(WL, object, oi)
            object.count = object.count - 1;
            object.position(:,oi) = [];
            object.orientation(:,oi) = [];
            object.scale(:,oi) = [];
            object.modelMatrix(:,:,oi) = [];
            object.invModelMatrix(:,:,oi) = [];
            object.modelMatrixUpdated(oi) = [];
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function Mesh = init_vao(WL, Mesh)
            global GL
            Screen('BeginOpenGL', WL.Screen.window);

            % 0. Generate Object Mesh.VAO, VBO, & EBO
            if WL.isMac
                Mesh.VAO = glGenVertexArraysAPPLE(1); % create 1 vertex array object, is already uint32
            else
                Mesh.VAO = glGenVertexArrays(1);
            end
            VBO = glGenBuffers(1); % create 1 vertex buffer object, is already uint32
            EBO = glGenBuffers(1); % create 1 element buffer object
            % 1. Bind Mesh.VAO
            if WL.isMac
                glBindVertexArrayAPPLE(Mesh.VAO);
            else
                glBindVertexArray(Mesh.VAO);
            end
            % 2. Copy our vertices array in the VBO for OpenGL to use
            glBindBuffer(GL.ARRAY_BUFFER, VBO);
            glBufferData(GL.ARRAY_BUFFER, Mesh.sizeOfVerticesInBytes, Mesh.vertices, GL.STATIC_DRAW);
            % 3. Copy our indices array in the EBO for OpenGL to use
            glBindBuffer(GL.ELEMENT_ARRAY_BUFFER, EBO);
            glBufferData(GL.ELEMENT_ARRAY_BUFFER, Mesh.sizeOfIndicesInBytes, Mesh.indices, GL.STATIC_DRAW);
            % IMPORTANT: The last element buffer object that gets bound while a Mesh.VAO is bound is stored
            %   as the Mesh.VAO's element buffer object. Binding the Mesh.VAO then also automatically binds that EBO.
            %   So, later when we draw, we don't need to bind EBO again.
            %   But make sure you don't unbind the EBO before the Mesh.VAO, or it will also unbind from the Mesh.VAO.
            % 4. Set our vertex-attribute pointers (these must correspond to the vertex shader!)
            % Positions
            PosLoc = glGetAttribLocation(WL.ShaderProgram,'aPos');
            glEnableVertexAttribArray(PosLoc);
            glVertexAttribPointer(PosLoc, 3, GL.FLOAT, GL.FALSE, Mesh.vertexStride, 0);
            % Normals
            NormalLoc = glGetAttribLocation(WL.ShaderProgram,'aNormal');
            glEnableVertexAttribArray(NormalLoc);
            glVertexAttribPointer(NormalLoc, 3, GL.FLOAT, GL.FALSE, Mesh.vertexStride, Mesh.byteOffsetToNormal);
            % Texture Coordinates
            TexCoordLoc = glGetAttribLocation(WL.ShaderProgram,'aTexCoord');
            glEnableVertexAttribArray(TexCoordLoc);
            glVertexAttribPointer(TexCoordLoc, 2, GL.FLOAT, GL.FALSE, Mesh.vertexStride, Mesh.byteOffsetToTexCoord);
            
%             glBindBuffer(GL.ARRAY_BUFFER, 0); % unbind VBO
%             if WL.isMac
%                 glBindVertexArrayAPPLE(0); % unbind VAO
%             else
%                 glBindVertexArray(0); % unbind VAO
%             end
            
            Screen('EndOpenGL', WL.Screen.window);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [] = init_textures(WL,textures,textureUnits)
            global GL
            % 'textures' is a cell array of RGB vectors and/or image filenames
            Screen('BeginOpenGL', WL.Screen.window);
            
            NumTextures = length(textures);
            % Texture Initialization
            % Generate textures
            WL.textures = glGenTextures(NumTextures);
            
%             while NumTextures > length(textureUnits)
%                 textureUnits(length(textureUnits+1)) = max(textureUnits)+1;
%             end

            for ti = 1:NumTextures
                % Set active texture unit, bind a texture there
                glActiveTexture(GL.TEXTURE0 + textureUnits(ti));
                glBindTexture(GL.TEXTURE_2D, WL.textures(ti));
                % Set wrap and min/mag parameters
                glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
                glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
                glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR_MIPMAP_LINEAR); % GL.NEAREST
                glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR); % No mipmaps when magnifying
                % Load image (OpenGL wants a sequence of bytes, in groups of 1-4, depending
                % on input format (e.g, RGB,RGBA))
                if ischar(textures{ti})
                    inputimage = imread(textures{ti});
                    inputimage = rot90(inputimage,-1); % rotate counterclockwise bc matlab does a weird pixel order
                    [width, height, ~] = size(inputimage);
                    inputimage = permute(inputimage,[3 1 2]); % make sure color components of each pixel are packed together
                    inputimage = inputimage(:);
                else
                    width = 1;
                    height = 1;
                    inputimage = textures{ti}; % RGB
                end
                glPixelStorei(GL.UNPACK_ALIGNMENT,1); % Across rows, we just move to the next byte (1 byte)
                % Create the texture
                glTexImage2D(GL.TEXTURE_2D, 0, GL.RGB, width, height, 0, GL.RGB, GL.UNSIGNED_BYTE, inputimage);
                glGenerateMipmap(GL.TEXTURE_2D);
                clear inputimage
            end
            Screen('EndOpenGL', WL.Screen.window);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [] = init_camera(WL)
            global GL
            Screen('BeginOpenGL', WL.Screen.window);
            % Be sure to activate shader when setting uniforms/drawing
            glUseProgram(WL.ShaderProgram);
            
            % % Camera Properties (static because 3BOT-Oculus is fixed)
            if ~WL.cfg.Stereo
                WL.IOD = 0;
            else
                WL.IOD = 6.25; % cm
            end
            
            % From the Oculus (see wl_start_screen) >> PsychVRHMD('GetStaticRenderParameters', WL.Screen.hmd)
            if WL.cfg.OculusRift
                WL.Camera.Projection = WL.Screen.projMatrix;
            else
                WL.Camera.Projection = WL.perspective(75*pi/180, WL.Screen.ar, 5, 100);
            end
            projMatLoc = glGetUniformLocation(WL.ShaderProgram, 'projection');
            glUniformMatrix4fv(projMatLoc, 1, GL.FALSE, WL.Camera.Projection);
            % Projection matrix won't change and is same for both eyes
            % So we can set it here and forget it

            % View Matrix
            WL.Camera.Position = [-0.5*WL.IOD 0.5*WL.IOD; -26 -26; 14 14]; % eyes in 3BOT coordinates
            WL.Camera.View = cat(3, WL.look_at(WL.Camera.Position(:,1)', [-0.5*WL.IOD 0 0], [0 0 1]), WL.look_at(WL.Camera.Position(:,2)', [0.5*WL.IOD 0 0], [0 0 1]));

            %WL.Camera.InvView = cat(3, inv(WL.Camera.View(:,:,1)), inv(WL.Camera.View(:,:,2)));
            %WL.Camera.InvProj = inv(WL.Camera.Projection);
            WL.Camera.InvViewProj = inv(mean(WL.Camera.View,3))*inv(WL.Camera.Projection);
            
            % Can't set the camera position or view matrix shader uniforms here because they are eye-specific
            %   So must be done in the display_func
            
            glUseProgram(0);
            Screen('EndOpenGL', WL.Screen.window);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [] = init_lighting(WL)
            global GL
            Screen('BeginOpenGL', WL.Screen.window);
            % Be sure to activate shader when setting uniforms/drawing
            glUseProgram(WL.ShaderProgram);
            
            % Lighting & Material Properties
            WL.Light.Color = [1 1 1]; % white light
            WL.Light.Diffuse = WL.Light.Color * 0.7;
            WL.Light.Ambient = WL.Light.Color * 0.3;
            WL.Light.Specular = WL.Light.Color * 0.5;
            WL.Light.Constant = 1;
            WL.Light.Linear = 0.1;
            WL.Light.Quadratic = 0.03;
            
            if isfield(WL.Light,'Shadows')
                WL.Light.View = WL.look_at(WL.Light.Position(1:3),[0 0 0],[0 0 1]);
                WL.Light.FrustumVerts = cell(6,1);
                vi = 0;
                for zn = [-1 1]
                    for yn = [-1 1]
                        for xn = [-1 1]
                            vi = vi+1;
                            ndc = [xn yn zn 1]';
                            transform = WL.Light.View * WL.Camera.InvViewProj;
                            %transform = WL.Light.View/(WL.Camera.Projection*mean(WL.Camera.View,3));
                            WL.Light.FrustumVerts{vi} = transform*ndc;
                            WL.Light.FrustumVerts{vi} = WL.Light.FrustumVerts{vi}./WL.Light.FrustumVerts{vi}(4);
                        end
                    end
                end
                WL.Light.ProjectionBounds = WL.compute_bounding_box(WL.Light.FrustumVerts);
                WL.Light.Projection = WL.orthogonal(WL.Light.ProjectionBounds(1),WL.Light.ProjectionBounds(2),WL.Light.ProjectionBounds(3),WL.Light.ProjectionBounds(4), 1, -WL.Light.ProjectionBounds(5));
                WL.Light.ViewProjection = WL.Light.Projection*WL.Light.View;
                
                WL.init_shadow_map();
                shadowMapLoc = glGetUniformLocation(WL.ShaderProgram, 'shadowMap');
                glUniform1i(shadowMapLoc, WL.Light.Shadows.TextureUnit);
                lightViewLoc = glGetUniformLocation(WL.ShaderProgram, 'lightView');
                glUniformMatrix4fv(lightViewLoc, 1, GL.FALSE, WL.Light.ViewProjection);
                
            end

            % To Fragment Shader
            for li = 1:size(WL.Light.Position,1)
                LightPosnLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].position']);
                LightAmbiLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].ambient']);
                LightDiffLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].diffuse']);
                LightSpecLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].specular']);
                LightAtten0Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].constantAtten']);
                LightAtten1Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].linearAtten']);
                LightAtten2Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].quadraticAtten']);
                glUniform4fv(LightPosnLoc, 1, WL.Light.Position(li,:)); % right now only this varies between lights
                glUniform3fv(LightAmbiLoc, 1, WL.Light.Ambient);
                glUniform3fv(LightDiffLoc, 1, WL.Light.Diffuse);
                glUniform3fv(LightSpecLoc, 1, WL.Light.Specular);
                glUniform1f(LightAtten0Loc, WL.Light.Constant);
                glUniform1f(LightAtten1Loc, WL.Light.Linear);
                glUniform1f(LightAtten2Loc, WL.Light.Quadratic);
            end
            glUseProgram(0);
            Screen('EndOpenGL', WL.Screen.window);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function [] = init_shadow_map(WL)
            global GL
            %Screen('BeginOpenGL', WL.Screen.window); % don't need because this is a helper for init_lighting
            
            WL.depthTexture = glGenTextures(1);
            glActiveTexture(GL.TEXTURE0 + WL.Light.Shadows.TextureUnit);
            glBindTexture(GL.TEXTURE_2D, WL.depthTexture);
            glTexImage2D(GL.TEXTURE_2D, 0, GL.DEPTH_COMPONENT16, WL.Light.Shadows.TextureSize, WL.Light.Shadows.TextureSize, 0, GL.DEPTH_COMPONENT, GL.UNSIGNED_SHORT, []);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            WL.Light.Shadows.ShadowMapFBO = glGenFramebuffers(1);
            glBindFramebuffer(GL.FRAMEBUFFER, WL.Light.Shadows.ShadowMapFBO);
            glFramebufferTexture2D(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.TEXTURE_2D, WL.depthTexture, 0);
            glDrawBuffer(GL.NONE);
            glReadBuffer(GL.NONE);
            glBindFramebuffer(GL.FRAMEBUFFER, 0);
            
            %Screen('EndOpenGL', WL.Screen.window);            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function object = draw_object(WL, object)
            if ~object.enabled
                return
            end
            
            global GL
            
            % Don't need these because they're called in display_func:
            %Screen('BeginOpenGL',WL.Screen.window);
            %glUseProgram(WL.ShaderProgram);
            
            if ismac
                glBindVertexArrayAPPLE(object.VAO);
            else
                glBindVertexArray(object.VAO);
            end
            
            for oi = 1:object.count
                if object.modelMatrixUpdated(oi) || ~isfield(object,'modelMatrixUpdated')
                    o = object.orientation(:,oi)*pi/180;
                    v = object.position(:,oi);
                    s = object.scale(:,oi);
                    object.modelMatrix(:,:,oi) = makehgtform('translate',v) * ...
                        makehgtform('zrotate',o(3)) * makehgtform('yrotate',o(2)) * ...
                        makehgtform('xrotate',o(1)) * makehgtform('scale',s);
                    object.invModelMatrix(:,:,oi) = inv(object.modelMatrix(:,:,oi));
                    object.modelMatrixUpdated(oi) = false;
                end
            
                if ismember(0, object.scale(:,oi))
                    % don't try to draw things with 0 scale
                    continue
                end
                
                modelMatLoc = glGetUniformLocation(WL.ShaderProgram, 'model');
                invModelMatLoc = glGetUniformLocation(WL.ShaderProgram, 'invModel');
                glUniformMatrix4fv(modelMatLoc, 1, GL.FALSE, object.modelMatrix(:,:,oi));
                glUniformMatrix4fv(invModelMatLoc, 1, GL.FALSE, object.invModelMatrix(:,:,oi));

                MatDiffColorLoc = glGetUniformLocation(WL.ShaderProgram, 'material.diffuseColor');
                if isfield(object,'diffuseColor') && ~isempty(object.diffuseColor{oi})
                    glUniform3fv(MatDiffColorLoc, 1, object.diffuseColor{oi});
                else
                    glUniform3fv(MatDiffColorLoc, 1, [1 1 1]); % white if not assigned
                end
                
                MatDiffMapLoc = glGetUniformLocation(WL.ShaderProgram, 'material.diffuseMap');
                if isfield(object,'diffuseMap') && length(object.diffuseMap)>=oi
                    glUniform1i(MatDiffMapLoc, object.diffuseMap(oi));
                else
                    glUniform1i(MatDiffMapLoc, 0); % default texture map (0) if not assigned
                end
                
                MatSpecColorLoc = glGetUniformLocation(WL.ShaderProgram, 'material.specularColor');
                if isfield(object,'specularColor') && ~isempty(object.specularColor{oi})
                    glUniform3fv(MatSpecColorLoc, 1, object.specularColor{oi});
                else
                    glUniform3fv(MatSpecColorLoc, 1, [1 1 1]); % white if not assigned
                end
                
                MatSpecMapLoc = glGetUniformLocation(WL.ShaderProgram, 'material.specularMap');
                if isfield(object,'specularMap') && length(object.specularMap)>=oi
                    glUniform1i(MatSpecMapLoc, object.specularMap(oi));
                else
                    glUniform1i(MatSpecMapLoc, 0); % default texture map (0) if not assigned
                end
                
                MatShinLoc = glGetUniformLocation(WL.ShaderProgram, 'material.shininess');
                if isfield(object,'shininess') && length(object.shininess)>=oi && object.shininess(oi)>0
                    glUniform1f(MatShinLoc, object.shininess(oi));
                else
                    glUniform1f(MatShinLoc, 8); % default shininess if not assigned
                end
                
                if isfield(object,'wireframe') && object.wireframe
                    glDrawElements(GL.LINES, length(object.indices), GL.UNSIGNED_INT, 0);
                else
                    glDrawElements(GL.TRIANGLES, length(object.indices), GL.UNSIGNED_INT, 0); % 'drawMode', 'indexCount', 'indexType', 'firstIndexLoc'
                end
            end

            if ismac
                glBindVertexArrayAPPLE(0);
            else
                glBindVertexArray(0);
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function object = draw_object_shadow(WL, object)
            global GL
            if ismac
                glBindVertexArrayAPPLE(object.VAO);
            else
                glBindVertexArray(object.VAO);
            end
            
            lightViewLoc = glGetUniformLocation(WL.Light.Shadows.ShaderProgram, 'lightView');
            glUniformMatrix4fv(lightViewLoc, 1, GL.FALSE, WL.Light.ViewProjection);

            for oi = 1:object.count
                if object.modelMatrixUpdated(oi) || ~isfield(object,'modelMatrixUpdated')
                    o = object.orientation(:,oi)*pi/180;
                    v = object.position(:,oi);
                    s = object.scale(:,oi);
                    object.modelMatrix(:,:,oi) = makehgtform('translate',v) * ...
                        makehgtform('zrotate',o(3)) * makehgtform('yrotate',o(2)) * ...
                        makehgtform('xrotate',o(1)) * makehgtform('scale',s);
                    object.invModelMatrix(:,:,oi) = inv(object.modelMatrix(:,:,oi));
                    object.modelMatrixUpdated(oi) = false;
                end
            
                if ismember(0, object.scale(:,oi))
                    % don't try to draw things with 0 scale
                    continue
                end
                
                modelMatLoc = glGetUniformLocation(WL.Light.Shadows.ShaderProgram, 'model');
                glUniformMatrix4fv(modelMatLoc, 1, GL.FALSE, object.modelMatrix(:,:,oi));

                glDrawElements(GL.TRIANGLES, length(object.indices), GL.UNSIGNED_INT, 0); % 'drawMode', 'indexCount', 'indexType', 'firstIndexLoc'
            end

            if ismac
                glBindVertexArrayAPPLE(0);
            else
                glBindVertexArray(0);
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function bounds = compute_bounding_box(WL, vertexArray)
            bounds = zeros(1,6);
            for vi = 1:length(vertexArray)
                if vertexArray{vi}(1) < bounds(1)
                    bounds(1) = vertexArray{vi}(1);
                elseif vertexArray{vi}(1) > bounds(2)
                    bounds(2) = vertexArray{vi}(1);
                end
                
                if vertexArray{vi}(2) < bounds(3)
                    bounds(3) = vertexArray{vi}(2);
                elseif vertexArray{vi}(2) > bounds(4)
                    bounds(4) = vertexArray{vi}(2);
                end
                
                if vertexArray{vi}(3) < bounds(5)
                    bounds(5) = vertexArray{vi}(3);
                elseif vertexArray{vi}(3) > bounds(6)
                    bounds(6) = vertexArray{vi}(3);
                end
            end
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function out = orthogonal(WL, left, right, bottom ,top, near, far)
            lr = 1/(left-right);
            bt = 1/(bottom-top);
            nf = 1/(near-far);
            out = [-2*lr 0 0 (left + right)*lr;
                    0 -2*bt 0 (top + bottom)*bt;
                    0 0 2*nf (far + near)*nf;
                    0 0 0 1];
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function out = perspective(WL, fovy, aspect, near, far)
            f = 1.0 / tan(fovy / 2);
            nf = 1 / (near - far);
            out = [ f/aspect 0 0 0;
                    0 f 0 0;
                    0 0 (far+near)*nf (2*far*near)*nf;
                    0 0 -1 0];
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function out = look_at(WL, pos, center, up)
            z = pos - center;

            if norm(z) < 0.0001
                out = eye(4);
                return
            end

            z = z/norm(z);

            x = up([2 3 1]).*z([3 1 2]) - up([3 1 2]).*z([2 3 1]);
            x = x/norm(x);

            y = z([2 3 1]).*x([3 1 2]) - z([3 1 2]).*x([2 3 1]);
            y = y/norm(y);

            out = [x -x*pos';
                   y -y*pos';
                   z -z*pos';
                   0 0 0 1];
        end
        
    end
end

