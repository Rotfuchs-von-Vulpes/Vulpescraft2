#version 330 core
layout (location = 0) out vec4 FragColor;
layout (location = 1) out float Depth;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;
uniform sampler2D depthTexture;
uniform sampler2D distanceTexture;

void main()
{
    FragColor = vec4(texture(screenTexture, TexCoords).rgb, 1.0);
    Depth = max(texture(depthTexture, TexCoords).r, texture(distanceTexture, TexCoords).r);
}