#version 120

struct Material {
    vec3 diffuseColor;
    vec3 specularColor;
    sampler2D diffuseMap;
    sampler2D specularMap;
    float shininess;
}; 

struct Light {
    vec4 position;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float constantAtten;
    float linearAtten;
    float quadraticAtten;
};
  
varying vec3 FragPos, Normal;
varying vec2 TexCoord;

uniform vec3 viewPos;
uniform Material material;

varying vec4 FragPosLightSpace;
uniform sampler2D shadowMap;

#define NR_LIGHTS 1
uniform Light lights[NR_LIGHTS];

vec3 CalcLight(Light light, vec3 norm, vec3 viewDir, vec3 diffColor, vec3 specColor);
float ShadowCalculation();

void main()
{
    // compute fragment properties
    vec3 norm = normalize(Normal);
    vec3 viewDir = normalize(viewPos - FragPos);

    // define an output color value
    vec3 result = vec3(0.0, 0.0, 0.0);
    vec3 diffColor = vec3(texture2D(material.diffuseMap, TexCoord)) * material.diffuseColor;
    vec3 specColor = vec3(texture2D(material.specularMap, TexCoord)) * material.specularColor;
    
    // accumulate contributions of the lights
    for(int i = 0; i < NR_LIGHTS; i++){
        result += CalcLight(lights[i], norm, viewDir, diffColor, specColor);
    }
    gl_FragColor = vec4(result, 1.0);
}

vec3 CalcLight(Light light, vec3 norm, vec3 viewDir, vec3 diffColor, vec3 specColor)
{
    // FragPos only matters for point light (as it is multiplied by w = 0 for directional)
    vec3 lightDir = normalize(light.position.xyz - FragPos * light.position.w);
    // diffuse 
    float diff = max(dot(norm, lightDir), 0.0);
    // Blinn-Phong model
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(norm, halfwayDir), 0.0), material.shininess);
    
    // Shadows
    float shadowMult = 1.0 - ShadowCalculation();
    
    // combine
    vec3 ambient = light.ambient * diffColor;
    vec3 diffuse = light.diffuse * diff * diffColor * shadowMult;
    vec3 specular = light.specular * spec * specColor * shadowMult;

    // attenuation
    float d = length(light.position.xyz - FragPos);
    float lightDenom = light.constantAtten + light.linearAtten * d + light.quadraticAtten * d * d;
    float attenuation = max(1.0 / lightDenom, 1.0 - light.position.w);
    ambient  *= attenuation;
    diffuse  *= attenuation;
    specular *= attenuation;
    
    // return
    return(ambient + diffuse + specular);
}

float ShadowCalculation()
{
    vec3 projCoords = FragPosLightSpace.xyz / FragPosLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;
    float closestDepth = texture2D(shadowMap, projCoords.xy).r;
    float currentDepth = projCoords.z;
    float bias = 0.002;
    float shadow = 0.0;
    vec2 texelSize = 1.0 / vec2(4096, 4096); //vec2(textureSize(shadowMap,0));
    for (int x = -3; x <= 3; ++x){
        for (int y = -2; y<= 3; ++y){
            float pcfDepth = texture2D(shadowMap, projCoords.xy + vec2(x,y) * texelSize).r;
            shadow += (currentDepth - bias > pcfDepth) ? 1.0 : 0.0;
        }
    }
    shadow /= 49.0;
    
    return (shadow);
}
