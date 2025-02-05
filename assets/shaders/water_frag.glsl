#version 330 core

out vec4 fragColor;

in vec3 Normal;
in vec3 Direction;
in vec3 ViewPos;

uniform sampler2D screenTexture;
uniform sampler2D depthTexture;

uniform vec3 sunDirection;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec2 resolution;

float luminance(vec3 color) {
    return dot(color, vec3(0.2125f, 0.7153f, 0.0721f));
}

#include lighting

void main()
{
    float viewDist = length(ViewPos);
    // depth = (viewDist - 0.1) / viewDist;
    float fragDist = viewDist / 3;
    float fogFactor = 1.0 - exp(fragDist * fragDist * -0.005);
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    vec3 albedo = vec3(0.015, 0.04, 0.055);
    vec3 diffuse = CalculateLighting(albedo, Normal, vec2(0, 1), gl_FragCoord.xyz);
    vec3 color = mix(diffuse, fogColor, fogFactor);

    vec2 uv = (gl_FragCoord.xy + vec2(0.5)) / resolution;
    vec2 uv2 = uv;
    vec3 refr = refract(Direction, Normal, 1.0 / 1.333);
    if (Direction.x != 0) {
        uv2 += refr.yz;
    } else if (Direction.y != 0) {
        uv2 += refr.xz;
    } else if (Direction.z != 0) {
        uv2 += refr.xy;
    }
    vec3 belowColor = texture(screenTexture, uv2).rgb;

    float depthDist1 = 0.1 / (1.0 - texture(depthTexture, uv2).r);
    float fogFactor2 = (10.0 - (depthDist1 - viewDist + 3.0)) / 10.0; // 1.0 - exp(fragDist2 * fragDist2 * -0.005);
    fogFactor2 = clamp(fogFactor2, 0.0, 1.0);
    
    float fresnel = (0.04 + (1.0-0.04)*(pow(1.0 - max(0.0, dot(-Normal, normalize(ViewPos))), 5.0)));
    /*clamp(fresnel, 0.75, 1.0)*/

    fragColor = vec4(mix(color, mix(belowColor, belowColor * color, fogFactor2), fogFactor2), 1.0);
}