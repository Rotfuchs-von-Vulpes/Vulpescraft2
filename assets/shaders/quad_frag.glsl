#version 330 core
layout (location = 0) out vec4 FragColor;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;
// uniform sampler2D depthTexture;

void main()
{ 
    FragColor = texture(screenTexture, TexCoords);
}