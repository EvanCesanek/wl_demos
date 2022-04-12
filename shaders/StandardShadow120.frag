#version 120
//varying vec2 TexCoord;

void main()
{
    gl_FragDepth = gl_FragCoord.z;
}
