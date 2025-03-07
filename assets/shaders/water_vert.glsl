#version 330 core

layout(location=0)in vec3 aPos;
layout(location=1)in vec3 aNormal;

out vec3 Normal;
out vec3 Direction;
out vec3 ViewPos;

uniform float time;
uniform vec3 chunkPosition;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
	float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}

/* skew constants for 3d simplex functions */
const float F3 =  0.3333333;
const float G3 =  0.1666667;

float simplex3d(vec3 p) {
	 /* 1. find current tetrahedron T and it's four vertices */
	 /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
	 /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
	 
	 /* calculate s and x */
	 vec3 s = floor(p + dot(p, vec3(F3)));
	 vec3 x = p - s + dot(s, vec3(G3));
	 
	 /* calculate i1 and i2 */
	 vec3 e = step(vec3(0.0), x - x.yzx);
	 vec3 i1 = e*(1.0 - e.zxy);
	 vec3 i2 = 1.0 - e.zxy*(1.0 - e);
	 	
	 /* x1, x2, x3 */
	 vec3 x1 = x - i1 + G3;
	 vec3 x2 = x - i2 + 2.0*G3;
	 vec3 x3 = x - 1.0 + 3.0*G3;
	 
	 /* 2. find four surflets and store them in d */
	 vec4 w, d;
	 
	 /* calculate surflet weights */
	 w.x = dot(x, x);
	 w.y = dot(x1, x1);
	 w.z = dot(x2, x2);
	 w.w = dot(x3, x3);
	 
	 /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
	 w = max(0.6 - w, 0.0);
	 
	 /* calculate surflet components */
	 d.x = dot(random3(s), x);
	 d.y = dot(random3(s + i1), x1);
	 d.z = dot(random3(s + i2), x2);
	 d.w = dot(random3(s + 1.0), x3);
	 
	 /* multiply d by w^4 */
	 w *= w;
	 w *= w;
	 d *= w;
	 
	 /* 3. return the sum of the four surflets */
	 return dot(d, vec4(52.0));
}

void main() {
    vec3 FragPos = vec3(model * vec4(aPos, 1.0));
    ViewPos = FragPos;
    Normal = aNormal;
    Direction = aNormal;
    if (aNormal.y == 1.0) {
        vec3 pos = vec3(aPos.x + chunkPosition.x, aPos.y + chunkPosition.y, aPos.z + chunkPosition.z);
        vec3 P = vec3(pos.x, pos.z, time);
        FragPos.y += 0.05 * simplex3d(P);
        vec2 e = vec2(0.5, 0);
    
        vec3 v1 = vec3(pos.x + e.x, pos.y + 0.05 * simplex3d(P + e.xyy), pos.z);
        vec3 v2 = vec3(pos.x, pos.y + 0.05 * simplex3d(P + e.yxy), pos.z + e.x);

        vec3 v3 = v1 - pos;
        vec3 v4 = v2 - pos;

        Normal = normalize(cross(v3, v4));
    }
	gl_Position = projection * view * vec4(FragPos, 1.0);
}