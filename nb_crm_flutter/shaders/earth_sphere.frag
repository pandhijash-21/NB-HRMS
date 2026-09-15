#include <flutter/runtime_effect.glsl>

uniform float uCenterX;
uniform float uCenterY;
uniform float uRadius;
uniform float uYaw;
uniform float uPitch;
uniform sampler2D uEarth;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = vec2(frag.x - uCenterX, uCenterY - frag.y);
  float dist = length(p);
  float edge = 1.4;
  float alpha = 1.0 - smoothstep(uRadius - edge, uRadius + 0.35, dist);
  if (alpha <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  float clamped = min(dist, uRadius - 0.25);
  float z = sqrt(max(uRadius * uRadius - clamped * clamped, 0.0));
  vec3 n = normalize(vec3(p.x, p.y, z));

  float cp = cos(-uPitch);
  float sp = sin(-uPitch);
  vec3 q = vec3(n.x, n.y * cp - n.z * sp, n.y * sp + n.z * cp);

  float cy = cos(-uYaw);
  float sy = sin(-uYaw);
  vec3 r = vec3(q.x * cy + q.z * sy, q.y, -q.x * sy + q.z * cy);

  float lon = atan(r.x, r.z);
  float lat = asin(clamp(r.y, -1.0, 1.0));
  vec2 uv = vec2(fract(0.5 + lon / TWO_PI), clamp(0.5 - lat / PI, 0.0, 1.0));

  vec4 color = texture(uEarth, uv);
  float light = 0.48 + 0.52 * clamp(n.z, 0.0, 1.0);
  color.rgb *= light;
  color *= alpha;
  fragColor = color;
}
