#version 120

attribute vec3 aPos;
attribute vec3 aNormal;
attribute vec2 aTexCoord;
varying vec3 FragPos;
varying vec3 Normal;
varying vec2 TexCoord;
uniform mat4 model, invModel, view, projection;
uniform mat4 lightView;
varying vec4 FragPosLightSpace;

void main()
{
    TexCoord = aTexCoord;
    FragPos = vec3(model * vec4(aPos, 1.0));
    FragPosLightSpace = lightView * vec4(FragPos, 1.0);
    Normal = mat3(transpose(invModel)) * aNormal;  
    gl_Position = projection * view * vec4(FragPos, 1.0);
}