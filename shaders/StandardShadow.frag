#version 460
precision lowp float;
in vec2 TexCoord;

void main()
{
    gl_FragDepth = gl_FragCoord.z;
}
