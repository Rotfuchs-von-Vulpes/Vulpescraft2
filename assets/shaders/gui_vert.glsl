#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoords;

out vec2 TexCoords;

uniform float width;
uniform float height;
uniform float xOffset;
uniform float yOffset;
uniform vec2 pixelSize;

void main()
{
    gl_Position = vec4(width * aPos.x - xOffset, height * aPos.y - yOffset, 0.0, 1.0); 
    TexCoords = aTexCoords;
} 