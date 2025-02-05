#version 330 core
out vec4 FragColor;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;

uniform vec2 resolution;
uniform int axis;

void main()
{
    float r = 3;
    float x, y, rr = r * r, d, w, w0;
    vec2 p = TexCoords;
    vec4 col = vec4(0);

    w0 = 0.5135 / pow(r, 0.96);

    if (axis==0) for (d = 1.0 / resolution.x, x = -r, p.x += x*d; x<=r; x++, p.x += d){
        w = w0 * exp((-x * x) / (2.0 * rr));
        col += texture2D(screenTexture, p) * w;
    }
    if (axis==1) for (d = 1.0 / resolution.y, y = -r, p.y += y*d; y<=r; y++, p.y += d){
        w = w0 * exp((-y * y) / (2.0 * rr));
        col += texture2D(screenTexture, p) * w;
    }

    FragColor = vec4(col.rgb, 1.0);
}