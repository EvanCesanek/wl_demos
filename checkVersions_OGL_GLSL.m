sca
Screen('Preference', 'SkipSyncTests', 2);

PsychDefaultSetup(0);

% Find the screen to use for display:
screenid=max(Screen('Screens')); 
InitializeMatlabOpenGL(1,1,0,4);
%InitializeMatlabOpenGL(0);
[win , winRect] = PsychImaging('OpenWindow', screenid, 0, [100 100 800 500], [], [], 0, 0);

global GL
glGetString(GL.VERSION)
glGetString(GL.SHADING_LANGUAGE_VERSION)
extensions = split(glGetString(GL.EXTENSIONS));

sca
