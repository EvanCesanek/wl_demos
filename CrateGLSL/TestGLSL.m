classdef TestGLSL < wl_experiment_v1_8
    properties
        Name = [];
        IOD = 0;
        
        ObjectPositions = [0 0 0];
        ObjectVelocity = [0 0 0];
        ObjectAcceleration = [0 0 0];
        
        ObjectOrientations = [0 0 0];
        ObjectAngularVelocity = [0 0 0];
        ObjectAngularAcceleration = [0 0 0];
        
        ObjectSize = 6.25; % cube side length (cm)
        
        dt = 0;
        prevTime = 0;
        currentTime = 0;
        
        VAO = [];
        %VBO = [];
        %EBO = [];
        ShaderProgram = 0;
        textures = [];
        ViewMatrix = [];
        CameraPosition = [];
        
        indices = [];
        
        isMac = ismac;
        
        NumObjects = 1;
        
        eyeIndex = 0;
        
    end
    methods
        % must implement ALL abstract methods or matlab will complain.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function run(WL, varargin)
            try
                WL.GUI = wl_gui('TestGLSL', 'test', 'cfg_TestGLSL', 'A', varargin{:});
                % These are custom parameters specific for this experiment.
                %WL.GUI.addParam('array', 'trials_to_run', []);
                %WL.GUI.addParam('numeric', 'reload_table', 0);
                
                ok = WL.initialise();
                if ~ok
                    WL.printf('Initialisation aborted\n')
                    return;
                end
                WL.my_initialise();
                
                if ~WL.cfg.MouseFlag
                    WL.Robot = WL.robot(WL.cfg.RobotName);
                else
                    WL.Robot = WL.mouse(WL.cfg.RobotName);
                end
                
                WL.Hardware = wl_hardware(WL.Robot);
                
                ok = WL.Hardware.Start();
                
                if ok
                    WL.main_loop(Inf, false);
                end
                WL.Hardware.Stop();
                clear mex
                
            catch msg
                sca
                
                if exist('obj')
                    if ~isempty(obj.Hardware)
                        WL.Hardware.Stop();
                    end
                end
                
                clear mex
                % [~,M]= inmem  % to see which mex are loaded
                
                error_msg = getReport(msg);
                error(error_msg)
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function my_initialise(WL, varargin)
            WL.state_init('INITIALIZE','SETUP','START', ...
                'MOVING','FINISH','NEXT','INTERTRIAL','EXIT','ERROR','REST');
            % Initialize a frame counter
            WL.FrameCounter.Stimulus = wl_frame_counter();
            % Initialize a timer
            WL.Timer.Stimulus = wl_timer();
            
            % Load bitmap font image
            % EAC: Remains to be seen if this routine will work with custom shader pipeline 
%             charsTexName = [WL.cfg.ImagesRoot 'characters.bmp'];
%             charsTex = imread(charsTexName);
%             charsTex = charsTex(:,:,1);
%             charsTex = flip(charsTex,1)';
%             charstexid = Screen('MakeTexture', WL.Screen.window, charsTex, [], 1); % final 1 is "enforcepot" flag, asks for power-of-two size image
%             [WL.CharsTextureID, WL.CharsTexture] = Screen('GetOpenGLTexture', WL.Screen.window, charstexid);

            WL.Name = upper(WL.GW.save_file(4:6));
            
            addpath .. % gives access to functions in my 'U:\experiments' folder
            
            % %%%%%%%%%%%%%%%%%% 3D Rendering Intialization %%%%%%%%%%%%%%%%%%
            global GL
            
            % %%%%%%%%%%%%%%%%%% Loading in Objects %%%%%%%%%%%%%%%%%%
            
            % Old Routine
            if WL.cfg.LoadOBJs
                if exist([WL.cfg.ObjectNames{1} '.mat'],'file')
                    % This will load the objects from the previously saved .mat file (fast):
                    WL.cfg.objects = load_obj_mtl([], WL.Screen.window, 0, 1, [WL.cfg.ObjectNames{1} '.mat']);
                else
                    filenames = cell(WL.cfg.NumObjects,1);
                    for i = 1:WL.cfg.NumObjects
                        filenames{i} = ['U:\experiments\objFiles\' WL.cfg.ObjectNames{i} '\' WL.cfg.ObjectNames{i} num2str(i) '.obj'];
                    end

                    % This will read the .obj files and save 'objects' struct to savedobjects.mat 
                    WL.cfg.objects = load_obj_mtl(filenames, WL.Screen.window, 1);
                end

                for i = 1:WL.cfg.NumObjects
                    WL.cfg.ObjectOriginToBase(i) = max(max(WL.cfg.objects{i}.vertices));
                end
            end
            
            %%%%%%%%%%%%%%%%%% Hello Cube %%%%%%%%%%%%%%%%%%
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

            numVerts = 24;
            numFloatsPerVert = 8;
            verticesInfo = whos('vertices');
            sizeOfVerticesInBytes = verticesInfo.bytes;
            vertexStride = numFloatsPerVert * (sizeOfVerticesInBytes/numel(vertices));

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
                22 23 20]); %#ok<PROPLC> % temporary variable 'indices' ~= WL.indices (bc WL.indices doesn't work with whos)
            numFaces = 12;
            indicesInfo = whos('indices');
            sizeOfIndicesInBytes = indicesInfo.bytes;
            %sizeOfIndexDatum = sizeOfIndicesInBytes/numFaces;
            WL.indices = indices; %#ok<PROPLC> % Now set WL.indices (see note above)

            byteOffsetToNormal = 3 * (sizeOfVerticesInBytes/numel(vertices)); % skip 3 position floats
            byteOffsetToTexCoord = 6 * (sizeOfVerticesInBytes/numel(vertices)); % skip 3 position & 3 normal floats
            
            % %%%%%%%%%%%%%%%%%% WL.VAO Initialization %%%%%%%%%%%%%%%%%%
            Screen('BeginOpenGL', WL.Screen.window);
            AssertGLSL;
            moglcore('DEBUGLEVEL', 2); % raised debug level

            % Shader Initialization
            % We must compile a Shader Program that contains two Shaders: Vertex shader & Fragment shader
            % Create new program object and get handle to it
            WL.ShaderProgram = glCreateProgram;

            % I. VERTEX SHADER
            % 1. Indicate the shader type
            shadertype = GL.VERTEX_SHADER; %GEOMETRY_SHADER %FRAGMENT_SHADER; %TESS_CONTROL_SHADER; %TESS_EVALUATION_SHADER;
            % 2. Read shader source code from file
            fid = fopen('../../shaders/MultiLightTextureMaterial.vert', 'rt');
            shadersrc = fread(fid);
            fclose(fid);
            % 3. Create shader
            shader_handle = glCreateShader(shadertype);
            % 4. Assign the source code
            glShaderSource(shader_handle, shadersrc);
            % 5. Compile the shader:
            glCompileShader(shader_handle);
            % 6. Attach the shader to the program
            glAttachShader(WL.ShaderProgram, shader_handle);

            % II. FRAGMENT SHADER
            % 1. Indicate the shader type
            shadertype = GL.FRAGMENT_SHADER; %TESS_CONTROL_SHADER; %TESS_EVALUATION_SHADER;
            % 2. Read shader source code from file
            fid = fopen('../../shaders/MultiLightTextureMaterial.frag', 'rt');
            shadersrc = fread(fid);
            fclose(fid);
            % 3. Create shader
            shader_handle = glCreateShader(shadertype);
            % 4. Assign the source code
            glShaderSource(shader_handle, shadersrc);
            % 5. Compile the shader:
            glCompileShader(shader_handle);
            % 6. Attach the shader to the program
            glAttachShader(WL.ShaderProgram, shader_handle);

            % --> After both/all shaders have been attached, link the shader program
            glLinkProgram(WL.ShaderProgram);

            % 0. Generate Object WL.VAO, VBO, & EBO
            if WL.isMac
                WL.VAO = glGenVertexArraysAPPLE(1); % create 1 vertex array object, is already uint32
            else
                WL.VAO = glGenVertexArrays(1);
            end
            VBO = glGenBuffers(1); % create 1 vertex buffer object, is already uint32
            EBO = glGenBuffers(1); % create 1 element buffer object
            % 1. Bind WL.VAO
            if WL.isMac
                glBindVertexArrayAPPLE(WL.VAO);
            else
                glBindVertexArray(WL.VAO);
            end
            % 2. Copy our vertices array in the VBO for OpenGL to use
            glBindBuffer(GL.ARRAY_BUFFER, VBO);
            glBufferData(GL.ARRAY_BUFFER, sizeOfVerticesInBytes, vertices, GL.STATIC_DRAW);
            % 3. Copy our indices array in the EBO for OpenGL to use
            glBindBuffer(GL.ELEMENT_ARRAY_BUFFER, EBO);
            glBufferData(GL.ELEMENT_ARRAY_BUFFER, sizeOfIndicesInBytes, WL.indices, GL.STATIC_DRAW);
            % IMPORTANT: The last element buffer object that gets bound while a WL.VAO is bound is stored
            %   as the WL.VAO's element buffer object. Binding the WL.VAO then also automatically binds that EBO.
            %   So, later when we draw, we don't need to bind EBO again.
            %   But make sure you don't unbind the EBO before the WL.VAO, or it will also unbind from the WL.VAO.
            % 4. Set our vertex-attribute pointers (these must correspond to the vertex shader!)
            % Positions
            PosLoc = glGetAttribLocation(WL.ShaderProgram,'aPos');
            glEnableVertexAttribArray(PosLoc);
            glVertexAttribPointer(PosLoc, 3, GL.FLOAT, GL.FALSE, vertexStride, 0);
            % Normals
            NormalLoc = glGetAttribLocation(WL.ShaderProgram,'aNormal');
            glEnableVertexAttribArray(NormalLoc);
            glVertexAttribPointer(NormalLoc, 3, GL.FLOAT, GL.FALSE, vertexStride, byteOffsetToNormal);
            % Texture Coordinates
            TexCoordLoc = glGetAttribLocation(WL.ShaderProgram,'aTexCoord');
            glEnableVertexAttribArray(TexCoordLoc);
            glVertexAttribPointer(TexCoordLoc, 2, GL.FLOAT, GL.FALSE, vertexStride, byteOffsetToTexCoord);

            % We're also going to make a WL.VAO for the light source (we want to draw a cube to show where it is)

            % Texture Initialization
            % Generate some textures
            WL.textures = glGenTextures(2); % Two textures

            % Set active texture unit, bind our first texture there
            glActiveTexture(GL.TEXTURE0);
            glBindTexture(GL.TEXTURE_2D, WL.textures(1));
            % Set wrap and min/mag parameters
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_BORDER);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_BORDER);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR); % No mipmaps when magnifying
            % Load image (OpenGL wants a sequence of bytes, in groups of 1-4, depending
            % on input format (e.g, RGB,RGBA))
            inputimage = imread('../../images/container2.png');
            inputimage = rot90(inputimage,-1); % rotate counterclockwise bc matlab does a weird pixel order
            [width, height, numChannels] = size(inputimage);
            inputimage = permute(inputimage,[3 1 2]); % make sure color components of each pixel are packed together
            inputimage = inputimage(:);
            glPixelStorei(GL.UNPACK_ALIGNMENT,1); % Across rows, we just move to the next byte (1 byte)
            % Create the texture
            glTexImage2D(GL.TEXTURE_2D, 0, GL.RGB, width, height, 0, GL.RGB, GL.UNSIGNED_BYTE, inputimage);
            glGenerateMipmap(GL.TEXTURE_2D);
            clear inputimage

            % Set a different active texture unit, bind our second texture there
            glActiveTexture(GL.TEXTURE1);
            glBindTexture(GL.TEXTURE_2D, WL.textures(2));
            % Set wrap and min/mag parameters
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_BORDER);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_BORDER);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR); % No mipmaps when magnifying
            % Load image (OpenGL wants a sequence of bytes, in groups of 1-4, depending
            % on input format (e.g, RGB,RGBA))
            inputimage = imread('../../images/container2_specular.png');
            inputimage = rot90(inputimage,-1); % rotate counterclockwise bc matlab does a weird pixel order
            [width, height, numChannels] = size(inputimage);
            inputimage = permute(inputimage,[3 1 2]); % make sure color components of each pixel are packed together
            inputimage = inputimage(:);
            glPixelStorei(GL.UNPACK_ALIGNMENT,1); % Across rows, we just move to the next byte (1 byte)
            % Create the texture
            glTexImage2D(GL.TEXTURE_2D, 0, GL.RGB, width, height, 0, GL.RGB, GL.UNSIGNED_BYTE, inputimage);
            glGenerateMipmap(GL.TEXTURE_2D);
            clear inputimage
            
            % Optional unbind:
            glBindBuffer(GL.ARRAY_BUFFER, 0); 
            if WL.isMac
                glBindVertexArrayAPPLE(0);
            else
                glBindVertexArray(0);
            end

            % Be sure to activate shader when setting uniforms/drawing
            glUseProgram(WL.ShaderProgram);

            % Set sampler2D uniforms when they are not in Material struct
            % tex1loc = glGetUniformLocation(WL.ShaderProgram, 'texture1');
            % glUniform1i(tex1loc, 0);
            % tex2loc = glGetUniformLocation(WL.ShaderProgram, 'texture2');
            % glUniform1i(tex2loc, 1);

            % % Camera Properties (static because 3BOT-Oculus is fixed)
            if WL.cfg.MouseFlag
                WL.IOD = 0;
            else
                WL.IOD = 6.25; % cm
            end
            
            % From the Oculus (see wl_start_screen) >> PsychVRHMD('GetStaticRenderParameters', WL.Screen.hmd)
            ProjectionMatrix = WL.Screen.projMatrix;
            projMatLoc = glGetUniformLocation(WL.ShaderProgram, 'projection');
            glUniformMatrix4fv(projMatLoc, 1, GL.FALSE, ProjectionMatrix);

            % View Matrix
            CameraWorldUp = [0 0 1];
            WL.CameraPosition = [-0.5*WL.IOD 0.5*WL.IOD; -26 -26; 14 14]; % cyclopean eye in 3BOT coordinates
            % Critical: Do not include the IOD in Camera Direction vector!
            % The headset screens are not angled toward the origin!
            CameraDirection = [0 -26 14]/norm([0 -26 14]); 
            CameraRight = cross(CameraWorldUp, CameraDirection);
            CameraUp = cross(CameraDirection, CameraRight);
            CameraViewMatrix = eye(4);
            CameraViewMatrix(1:3, 1:3) = [CameraRight; CameraUp; CameraDirection];
            multMatLeft = eye(4);
            multMatRight = eye(4);
            multMatLeft(1:3,4) = -WL.CameraPosition(:,1);
            multMatRight(1:3,4) = -WL.CameraPosition(:,2);
            WL.ViewMatrix = cat(3, CameraViewMatrix * multMatLeft, CameraViewMatrix * multMatRight);
            

            % Lighting & Material Properties
            light.color = [1 1 1]; % white light
            light.diffuse = light.color*0.5; % half influence
            light.ambient = light.color*0.2; % low influence
            light.specular = light.color; % full  brightness
            light.positions =  [ -1  -1  10  0; % directional
                                -10   4  0  1;
                                  0   4  0  1;
                                 10   4  0  1]; % w component = 1 for point, 0 for directional
            light.constant = 1;
            light.linear = 0.1;
            light.quadratic = 0.03;

            % **** Choose Texture or Solid Color ****
            %material.ambient = [1 0.5 0.3]; % Usually defined by material.diffuse (check shader) 
            %material.diffuse = [1 0.5 0.3]; % To set a solid color
            material.diffuse = int32(0); % Texture Unit 0 (GL.TEXTURE0)
            %material.specular = [0.5 0.5 0.5]; % To set a uniform specular component
            material.specular = int32(1); % Texture Unit 1 (GL.TEXTURE1)
            material.shininess = 32.0;

            % To Fragment Shader
            for li = 1:size(light.positions,1)
                LightPosnLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].position']);
                LightAmbiLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].ambient']);
                LightDiffLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].diffuse']);
                LightSpecLoc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].specular']);
                LightAtten0Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].constant']);
                LightAtten1Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].linear']);
                LightAtten2Loc = glGetUniformLocation(WL.ShaderProgram, ['lights[' num2str(li-1) '].quadratic']);
                glUniform4fv(LightPosnLoc, 1, light.positions(li,:)); % right now only this varies between lights
                glUniform3fv(LightAmbiLoc, 1, light.ambient);
                glUniform3fv(LightDiffLoc, 1, light.diffuse);
                glUniform3fv(LightSpecLoc, 1, light.specular);
                glUniform1f(LightAtten0Loc, light.constant);
                glUniform1f(LightAtten1Loc, light.linear);
                glUniform1f(LightAtten2Loc, light.quadratic);
            end

            % Material Properties
            % To Fragment Shader
            %MatAmbiLoc = glGetUniformLocation(WL.ShaderProgram, 'material.ambient');
            MatDiffLoc = glGetUniformLocation(WL.ShaderProgram, 'material.diffuse');
            MatSpecLoc = glGetUniformLocation(WL.ShaderProgram, 'material.specular'); 
            MatShinLoc = glGetUniformLocation(WL.ShaderProgram, 'material.shininess');
            %glUniform3fv(MatAmbiLoc, 1, material.ambient); % usually matches diffuse
            %glUniform3fv(MatDiffLoc, 1, material.diffuse); % solid color
            glUniform1i(MatDiffLoc, material.diffuse);  % diffuse map (texture)
            %glUniform3fv(MatSpecLoc, 1, material.specular); % uniform specular
            glUniform1i(MatSpecLoc, material.specular); % specular map (texture)
            glUniform1f(MatShinLoc, material.shininess);
            
            % Oops we did CW winding...
            glFrontFace(GL.CW);
            
            Screen('EndOpenGL', WL.Screen.window);
            
            WL.ObjectPositions = ... 
                [0, 0, 0];
            WL.NumObjects = size(WL.ObjectPositions,1);
            
            %WL.ObjectOrientations = repmat(180,10,2).*rand(10,2);
            WL.ObjectOrientations = repmat(180,WL.NumObjects,2).*zeros(WL.NumObjects,2);

        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function idle_func(WL)
            ok = WL.Hardware.GetLatest();
            WL.state_process();
            
            if WL.State.Current==WL.State.MOVING
                WL.ObjectPositions(WL.Trial.ObjID,:) = WL.Robot.Position;
            end
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function keyboard_func(WL,keyname)
            
            if strcmpi(keyname, 'a')
                WL.ObjectOrientations = repmat(180,WL.NumObjects,2).*rand(WL.NumObjects,2);
            elseif strcmpi(keyname, 's')
                WL.ObjectOrientations = repmat(180,WL.NumObjects,2).*zeros(WL.NumObjects,2);
            end
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function display_func(WL, win)
            global GL
            Screen('BeginOpenGL', win);
            
            glClearColor(WL.cfg.ClearColor(1),WL.cfg.ClearColor(2),WL.cfg.ClearColor(3),0);
            glClear();
            
            % REST BREAK TEAPOT
            if WL.State.Current == WL.State.REST
                wl_draw_teapot(WL);
                
            else
                
                glActiveTexture(GL.TEXTURE0);
                glBindTexture(GL.TEXTURE_2D, WL.textures(1));
                glActiveTexture(GL.TEXTURE1);
                glBindTexture(GL.TEXTURE_2D, WL.textures(2));
                
                glUseProgram(WL.ShaderProgram);
                
                % To vertex shader (for lighting calculations)
                viewPosLoc = glGetUniformLocation(WL.ShaderProgram, 'viewPos');
                glUniform3fv(viewPosLoc, 1, WL.CameraPosition(:,WL.eyeIndex+1));

                % To fragment shader (view matrix)
                viewMatLoc = glGetUniformLocation(WL.ShaderProgram, 'view');
                glUniformMatrix4fv(viewMatLoc, 1, GL.FALSE, WL.ViewMatrix(:,:,WL.eyeIndex+1));
            
                if WL.isMac
                    glBindVertexArrayAPPLE(WL.VAO);
                else
                    glBindVertexArray(WL.VAO);
                end
                for ci = 1:WL.NumObjects
                    % Transformations composed by: move to position in world space (translate), change azimuth (zrotate), change pitch (xrotate), scale (obj coord frame)
                    ModelMatrix = makehgtform('translate',WL.ObjectPositions(ci,:))*makehgtform('zrotate',pi/180*WL.ObjectOrientations(ci,2))*makehgtform('xrotate',pi/180*WL.ObjectOrientations(ci,1))*makehgtform('scale',WL.ObjectSize);
                    modelMatLoc = glGetUniformLocation(WL.ShaderProgram, 'model');
                    invModelMatLoc = glGetUniformLocation(WL.ShaderProgram, 'invModel');
                    glUniformMatrix4fv(modelMatLoc, 1, GL.FALSE, ModelMatrix);
                    glUniformMatrix4fv(invModelMatLoc, 1, GL.FALSE, inv(ModelMatrix)); % remember inverting can be costly...
                    
                    glDrawElements(GL.TRIANGLES, length(WL.indices), GL.UNSIGNED_INT, 0); % 'drawMode', 'indexCount', 'indexType', 'firstIndexLoc'
                end
                
                if WL.isMac
                    glBindVertexArrayAPPLE(0);
                else
                    glBindVertexArray(0);
                end
                
                glUseProgram(0); % This was necessary to keep objects from disappearing
                
            end
            
            Screen('EndOpenGL', win)
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function flip_func(WL)
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function state_process(WL)
            switch WL.State.Current % State processing.
                
                case WL.State.INITIALIZE % Initialization state.
                    WL.Timer.Paradigm.ExperimentTimer.Reset;
                    WL.state_next(WL.State.SETUP);
                    
                case WL.State.SETUP % Setup trial.
                    WL.trial_setup();
                    WL.state_next(WL.State.START);
                    
                case WL.State.START % Start trial.
                    WL.trial_start();
                    WL.Timer.MovementDurationTimer.Reset;
                    WL.state_next(WL.State.MOVING);
                    
                case WL.State.MOVING
                    if  WL.Timer.MovementDurationTimer.GetTime > WL.cfg.MovementDuration
                        WL.state_next(WL.State.FINISH);
                        
                    else
                        WL.currentTime = WL.Timer.Stimulus.GetTime;
                        WL.dt = WL.currentTime-WL.prevTime;
                        WL.prevTime = WL.currentTime;
                        
                    end
                    
                case WL.State.FINISH
                    if WL.State.Timer.GetTime > WL.cfg.FinishDelay % Trial has finished so stop trial.
                        WL.trial_stop();
                        WL.Timer.Paradigm.InterTrialDelayTimer.Reset;
                        
                        if ~WL.trial_save()
                            WL.printf(1,'Cannot save Trial %d.\n',WL.TrialNumber);
                            WL.state_next(WL.State.EXIT);
                        else
                            WL.state_next(WL.State.NEXT);
                        end
                    end
                    
                case WL.State.NEXT
                    if WL.Trial.RestFlag==1
                        WL.state_next(WL.State.REST);
                    elseif  ~WL.trial_next()
                        WL.state_next(WL.State.EXIT);
                    else
                        WL.state_next(WL.State.INTERTRIAL);
                    end
                    
                case WL.State.INTERTRIAL % Wait for the intertrial delay to expire.
                    if WL. Timer.Paradigm.InterTrialDelayTimer.GetTime > WL.cfg.InterTrialDelay
                        WL.state_next(WL.State.SETUP);
                    end
                    
                case WL.State.EXIT
                    WL.GW.ExperimentSeconds = WL.Timer.Paradigm.ExperimentTimer.GetTime;
                    WL.GW.ExperimentMinutes = WL.GW.ExperimentSeconds / 60.0;
                    WL.printf('Game Over (%.1f minutes)',WL.GW.ExperimentMinutes);
                    WL.GW.ExitFlag = true;
                    
                case WL.State.ERROR
                    if  WL.State.Timer.GetTime > WL.cfg.ErrorWait
                        WL.error_resume();
                    end
                    
                case WL.State.REST
                    RestBreakRemainSeconds = (WL.cfg.RestBreakSeconds -  WL.State.Timer.GetTime);
                    WL.cfg.RestBreakRemainPercent = (RestBreakRemainSeconds / WL.cfg.RestBreakSeconds);
                    
                    if  RestBreakRemainSeconds < 0
                        WL.Trial.RestFlag = 0;
                        WL.state_next(WL.State.NEXT);
                    end
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function trial_start(WL)
            WL.Timer.Paradigm.TrialTimer.Reset();
            WL.printf('TrialStart() Trial=%d\n',WL.TrialNumber);
            WL.GW.TrialRunning = true;
            
            WL.ObjectPositions = ... 
                [0.0, 0.0, 0.0];
            WL.NumObjects = size(WL.ObjectPositions,1);
            
            WL.ObjectOrientations = repmat(180,10,2).*zeros(10,2);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function miss_trial(WL,MissTrialType)
            WL.Trial.MissTrial = MissTrialType;
            if  ~WL.trial_save()   % Save the data for WL trial.
                WL.printf('Cannot save Trial %d.\n',WL.TrialNumber);
            end
            WL.Trial.MissTrial = 0;
         end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function draw_bitmap_font_string(WL,text,posn,rotate)
            global GL
            numColumns = 32;
            numRows = 8;
            % An 8-row by 16-column bitmap font image must already be loaded into WL.CharsTexture and WL.CharsTextureID
            % Freeware: Codehead's bitmap font generator
            % Posn is a 3-vector with the xyz coordinates of the bottom-left of the first letter 
            % Draws letters in the XZ (frontal) plane
            glPushMatrix();
            glEnable(WL.CharsTexture);
            glBindTexture(WL.CharsTexture, WL.CharsTextureID);
            %glTexEnvfv(GL.TEXTURE_ENV,GL.TEXTURE_ENV_MODE,GL.MODULATE);
            glTexParameteri(WL.CharsTexture,GL.TEXTURE_MIN_FILTER,GL.LINEAR);
            glTexParameteri(WL.CharsTexture,GL.TEXTURE_MAG_FILTER,GL.LINEAR);
            glMaterialfv(GL.FRONT_AND_BACK,GL.AMBIENT,[1 1 1 1]);
            glMaterialfv(GL.FRONT_AND_BACK,GL.DIFFUSE,[1 1 1 1]);
            len = length(text);
            charHeight = 2-2/10;
            charWidth = 1;
            glTranslated(posn(1),posn(2),posn(3));
            if(rotate)
               glRotated(rotate,1,0,0);
            end
            glBegin(GL.QUADS);
            for ci = 1:len
                char = text(ci);
                uv_x = mod(char,numColumns)/numColumns;
                uv_y = floor(char/numColumns)/numRows;
                
                cbottomleft = [uv_x 1-(uv_y+1/numRows)+1/numRows/10];
                ctopleft = [uv_x 1-uv_y];
                ctopright = [uv_x+1/numColumns 1-uv_y];
                cbottomright = [uv_x+1/numColumns 1-(uv_y+1/numRows)+1/numRows/10];
                
                vbottomleft = [(ci-1)*charWidth 0 0];
                vtopleft = [(ci-1)*charWidth 0 charHeight];
                vtopright = [(ci-1)*charWidth+charWidth 0 charHeight];
                vbottomright = [(ci-1)*charWidth+charWidth 0 0];
                
                glColor4fv([1 1 1 1]);
                
                glTexCoord2fv(ctopleft);
                glVertex3fv(vtopleft);
                
                glTexCoord2fv(cbottomleft);
                glVertex3fv(vbottomleft);
                
                glTexCoord2fv(cbottomright);
                glVertex3fv(vbottomright);
                
                glTexCoord2fv(ctopright);
                glVertex3fv(vtopright);
                
            end
            glEnd();
            glBindTexture(WL.CharsTexture,0);
            glDisable(WL.CharsTexture);
            glPopMatrix();
            glColor4fv([1 1 1 1]);
        end
    end
end
