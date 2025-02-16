#version 330 core

layout (location = 0) out vec4 fragColor;
layout (location = 1) out float depth;

in vec3 Pos;
in vec3 Normal;
in vec2 TexCoords;
in float Occlusion;
in float TextureID;
in vec2 Lightmap;

uniform sampler2DArray textures;
uniform vec3 sunDirection;
uniform vec3 skyColor;
uniform vec3 fogColor;

float luminance(vec3 color) {
    return dot(color, vec3(0.2125f, 0.7153f, 0.0721f));
}

#include tone_mapping
#include lighting

void main()
{
    vec4 albedo = texture(textures,vec3(TexCoords, TextureID));
    if (albedo.a < 0.5) discard;
    float occluse = 0.25 * Occlusion + 0.25;
    albedo.rgb *= occluse;

    vec3 diffuse = CalculateLighting(albedo.rgb, Normal, Lightmap, gl_FragCoord.xyz);

    float viewDist = length(Pos);
    depth = (viewDist - 0.1) / viewDist;

    float fragDist = length(Pos) / 3;
    float fogFactor = 1.0 - exp(fragDist * fragDist * -0.005);
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    fragColor = vec4(mix(diffuse, fogColor, fogFactor), albedo.a);
}