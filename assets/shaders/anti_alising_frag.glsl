#version 330 core
layout (location = 0) out vec4 FragColor;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;

#extension GL_ARB_gpu_shader5 : enable
                
#define FXAA_PC 1
#define FXAA_GREEN_AS_LUMA 0
#define FXAA_GLSL_130 1

#define FXAA_QUALITY__PRESET 39
#define FXAA_QUALITY__SUBPIX 1.00
#define FXAA_QUALITY__EDGE_THRESHOLD 0.063
#define FXAA_QUALITY__EDGE_THRESHOLD_MIN 0.0312

#include fxaa

void main()
{
	vec2 screenSize = vec2(textureSize(screenTexture, 0));
	FragColor = vec4(FxaaPixelShader(TexCoords, vec4(0.0), screenTexture, screenTexture, screenTexture,  1.0 / screenSize, vec4(0.0), vec4(0.0), vec4(0.0), FXAA_QUALITY__SUBPIX, FXAA_QUALITY__EDGE_THRESHOLD, FXAA_QUALITY__EDGE_THRESHOLD_MIN, 0.0, 0.0, 0.0, vec4(0.0)).rgb, 1.0);
}