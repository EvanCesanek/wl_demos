#version 460
precision lowp float;

layout (location = 0) in vec3 aPos;
layout (location = 2) in vec2 aTexCoord;
out vec2 TexCoord;
uniform mat4 model;
uniform mat4 lightView;

void main()
{
    TexCoord = aTexCoord;
    gl_Position = lightView * model * vec4(aPos, 1.0);
}