#version 330 core
layout (location = 0) out vec4 FragColor;
layout (location = 1) out float Depth;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;
uniform sampler2D depthTexture;

void main()
{
    FragColor = vec4(texture(screenTexture, TexCoords).rgb, 1.0);
    Depth = texture(depthTexture, TexCoords).r;
}