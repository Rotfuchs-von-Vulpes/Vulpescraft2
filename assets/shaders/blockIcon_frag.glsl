#version 330 core

out vec4 fragColor;
in vec3 Normal;
in vec2 TexCoords;

uniform sampler2DArray textures;
uniform float textureIDTop;
uniform float textureIDSide1;
uniform float textureIDSide2;

float luminance(vec3 color) {
    return dot(color, vec3(0.2125f, 0.7153f, 0.0721f));
}

const vec3 sunColor = vec3(0.98, 0.73, 0.15);
const vec3 _Ambient = vec3(0.02, 0.04, 0.08);
const vec3 skyColor = vec3(0.4666, 0.6588, 1.0);

float AdjustTorchLighting(in float torchLight) {
    return max(3 * pow(torchLight, 4), 0.0f);
}

float AdjustSkyLighting(in float skyLight) {
    return max(pow(skyLight, 3), 0.0f);
}

vec2 AdjustLightmap(in vec2 lightmap) {
    vec2 newLightmap = lightmap;
    newLightmap.r = AdjustTorchLighting(lightmap.r);
    newLightmap.g = AdjustSkyLighting(lightmap.g);

    return newLightmap;
}

vec3 CalculateLighting(vec3 albedo, vec3 normal, vec2 lightmapCoords) {
    vec3 sunDirection = normalize(vec3(-0.5, 1.0, 0.1));
    float sunVisibility  = clamp((dot( sunDirection, vec3(0.0, 1.0, 0.0)) + 0.05) * 10.0, 0.0, 1.0);

    vec2 lightmap = AdjustLightmap(lightmapCoords);
    vec3 skyLight = lightmap.y * skyColor;

    vec3 ndotl = sunColor * clamp(4 * dot(normal, sunDirection), 0.0f, 1.0f) * sunVisibility;
    ndotl *= 1.3;
    ndotl *= (luminance(skyColor) + 0.01f);
    ndotl *= lightmap.g;

    vec3 lighting = ndotl + skyLight + _Ambient;

    vec3 diffuse = albedo.rgb;
    diffuse *= lighting;

    return diffuse;
}

vec3 ACESFilm(vec3 rgb) {
  rgb *= 0.6;
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return (rgb*(a*rgb+b))/(rgb*(c*rgb+d)+e);
}

void main()
{
    float textureID;
    if (Normal.x > 0) {
        textureID = textureIDSide1;
    } else if (Normal.y > 0) {
        textureID = textureIDTop;
    } else {
        textureID = textureIDSide2;
    }
    vec4 albedo = texture(textures,vec3(TexCoords, textureID));
    if (albedo.a < 0.5) discard;
    albedo.rgb = pow(ACESFilm(albedo.rgb), vec3(1.0 / 2.2));

    vec3 diffuse = CalculateLighting(albedo.rgb, Normal, vec2(0.0, 1.0));

    fragColor = vec4(diffuse, albedo.a);
}
