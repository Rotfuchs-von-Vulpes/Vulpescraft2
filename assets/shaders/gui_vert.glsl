#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoords;

out vec2 TexCoords;
out vec2 Pos;

uniform float width;
uniform float height;
uniform float xOffset;
uniform float yOffset;

void main()
{
    Pos = vec2(width * aPos.x - xOffset, height * aPos.y - yOffset);
    gl_Position = vec4(Pos, 0.0, 1.0);
    TexCoords = aTexCoords;
} 