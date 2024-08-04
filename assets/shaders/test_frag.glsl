#version 330 core

out vec4 fragColor;
in vec3 Normal;
in vec2 TexCoords;

uniform sampler2D ourTexture;

void main()
{
    vec4 tex = texture(ourTexture, TexCoords);

    vec3 ambient = vec3(0.5) * tex.rgb;

    vec3 lightDir = normalize(-vec3(-0.2f, -1.0f, -0.3f));
    float diff = max(dot(Normal, lightDir),0.);
    vec3 diffuse = vec3(0.8) * diff * tex.rgb;

    vec3 result = ambient + diffuse;

    fragColor = tex;
}