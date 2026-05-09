#version 330 core

in vec4 v_color;
in vec2 v_sdf_pos;
in vec2 v_half_size;
in float v_roundness;
in vec2 v_uv;
flat in int v_shader_kind;

uniform sampler2D u_texture;

out vec4 frag_color;

float sdf_rounded_box(vec2 p, vec2 half_size, float r) {
  vec2 q = abs(p) - half_size + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float msdf_median(float r, float g, float b) {
  return max(min(r, g), min(max(r, g), b));
}

float gradient_noise(vec2 n) {
  float f = 0.06711056 * n.x + 0.00583715 * n.y;
  return fract(52.9829189 * fract(f));
}

#define SHADER_KIND_RECT  0
#define SHADER_KIND_IMAGE	1
#define SHADER_KIND_TEXT	2

#define TEXT_THICKNESS	0.6 // 0.5 is default
#define MSDF_PXRANGE    8.0

void main() {
  float corner_alpha = 1.0;
  vec4 tex_color = vec4(1.0);

  switch (v_shader_kind) {
    case SHADER_KIND_IMAGE: // fallthrough;
    tex_color = texture(u_texture, v_uv);
    case SHADER_KIND_RECT:
    {
      if (v_roundness > 0.0) {
        float safe_radius = min(v_roundness, min(v_half_size.x, v_half_size.y));
        float dist = sdf_rounded_box(v_sdf_pos, v_half_size, safe_radius);

        float aa = length(vec2(dFdx(dist), dFdy(dist)));
        float feather = aa * 0.5;
        corner_alpha = 1.0 - smoothstep(-feather, feather, dist);
      }

      frag_color = tex_color * v_color;
      frag_color.a *= corner_alpha;
    }
    break;
    case SHADER_KIND_TEXT:
    {
      tex_color = texture(u_texture, v_uv);
      float sd = msdf_median(tex_color.r, tex_color.g, tex_color.b) - 0.5;

      vec2 msdf_tex_size = vec2(textureSize(u_texture, 0));
      vec2 unit_range = vec2(MSDF_PXRANGE) / msdf_tex_size;

      vec2 screen_tex_size = vec2(1.0) / fwidth(v_uv);
      float screen_px_range = max(0.5 * dot(unit_range, screen_tex_size), 1.0);

      float screen_px_distance = screen_px_range * sd;
      float opacity = clamp(screen_px_distance + TEXT_THICKNESS, 0.0, 1.0);

      tex_color = vec4(1.0, 1.0, 1.0, opacity);
      frag_color = tex_color * v_color;
    }
    break;
    default:
    break;
  }

  // avoid bending
  float noise = gradient_noise(gl_FragCoord.xy);
  noise = (noise - 0.5) / 255.0;
  frag_color.rgb += noise;
}
