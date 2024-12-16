#version 330 core
layout (location=0) in vec3 aPos;
layout (location=1) in vec3 aNormal;
layout (location=2) in vec2 aTexCoords;

out vec3 Normal;
out vec2 TexCoords;

uniform float width;
uniform float height;
uniform float xOffset;
uniform float yOffset;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    vec3 FragPos = vec3(model * vec4(aPos, 1.0));
    Normal = aNormal;
    TexCoords = aTexCoords;
	vec4 pos = projection * view * vec4(FragPos, 1.0);
    gl_Position = vec4(width * pos.x - xOffset, height * pos.y - yOffset, 0.0, 1.0);
} 