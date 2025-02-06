#version 330 core
layout (location = 0) out vec4 FragColor;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;

vec4 applyTonemapping(vec2 uv, float exposure, float gamma, /*sampler3D LUT,*/ vec4 color) {
  // color.rgb = vec3(1.0) - exp(-color.rgb * exposure);
  color.rgb = pow(color.rgb, vec3(1.0/gamma));
  /*color.rgb = texture(LUT, color.rgb).rgb;*/
  const float noise = 0.5 / 255.0;
  color.rgb += mix(-noise, noise,
    fract(sin(dot(uv, vec2(12.9898,78.233))) * 43758.5453));
  color.rgb = clamp(color.rgb, 0.0, 1.0);
  color.a = dot(color.rgb, vec3(0.299, 0.587, 0.114));

  return color;
}

void main()
{ 
  FragColor = texture(screenTexture, TexCoords);
  FragColor = applyTonemapping(TexCoords, 1.5, 1.4, FragColor);
}