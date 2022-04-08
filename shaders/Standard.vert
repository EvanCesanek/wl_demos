#version 460
precision lowp float;

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoord;
out vec3 FragPos;
out vec3 Normal;
out vec2 TexCoord;
uniform mat4 model, invModel, view, projection;
uniform mat4 lightView;
out vec4 FragPosLightSpace;

void main()
{
    TexCoord = aTexCoord;
    FragPos = vec3(model * vec4(aPos, 1.0));
    FragPosLightSpace = lightView * vec4(FragPos, 1.0);
    Normal = mat3(transpose(invModel)) * aNormal;  
    gl_Position = projection * view * vec4(FragPos, 1.0);
}