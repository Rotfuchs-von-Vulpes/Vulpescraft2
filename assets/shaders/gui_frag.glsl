#version 330 core
out vec4 FragColor;
  
in vec2 TexCoords;
in vec2 Pos;

uniform sampler2D guiTexture;

uniform int isCross;
uniform float width;
uniform float height;

void main()
{ 
    if (isCross == 1) {
        vec3 color = texture(guiTexture, Pos / 2.0 + vec2(0.5)).rgb;
        color = vec3(1.0) - color;
        FragColor = vec4(color, 1.0);
    } else {
        FragColor = texture(guiTexture, TexCoords);
    }
}