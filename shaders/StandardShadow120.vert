#version 120

varying vec3 aPos;
//varying vec2 aTexCoord;
//varying vec2 TexCoord;
uniform mat4 model;
uniform mat4 lightView;

void main()
{
    //TexCoord = aTexCoord;
    gl_Position = lightView * model * vec4(aPos, 1.0);
}