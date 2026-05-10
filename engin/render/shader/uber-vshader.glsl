#version 330 core

in vec4 a_dst;
in vec4 a_src;
in vec4 a_color_tl;
in vec4 a_color_tr;
in vec4 a_color_bl;
in vec4 a_color_br;
in float a_roundness;
// in float a_border_size;
// in vec4  a_border_color;
in int a_shader_kind;

out vec4 v_color;
out vec2 v_sdf_pos;
out vec2 v_half_size;
out float v_roundness;
// out float v_border_size;
// out vec4  v_border_color;
out vec2 v_uv;
flat out int v_shader_kind;

uniform mat4 u_proj_ortho;

void main() {
  vec2 verts[4] =
    vec2[](
      vec2(-1, -1),
      vec2(1, -1),
      vec2(-1, 1),
      vec2(1, 1)
    );
  vec4 colors[4] =
    vec4[](
      a_color_tl,
      a_color_tr,
      a_color_bl,
      a_color_br
    );

  vec4 local_color = colors[gl_VertexID];
  vec2 local_vert = verts[gl_VertexID];
  vec2 local_uv = local_vert * 0.5 + 0.5;
  vec2 final_uv = mix(a_src.xy, a_src.zw, local_uv);

  vec2 half_size = (a_dst.zw - a_dst.xy) * 0.5;
  vec2 center = a_dst.xy + half_size;
  vec2 pos = center + (local_vert * half_size);

  {
    gl_Position = u_proj_ortho * vec4(pos, 0.0, 1.0);

    v_color = local_color;
    v_sdf_pos = local_vert * half_size;
    v_half_size = half_size;
    v_roundness = a_roundness;
    // v_border_size  = a_border_size;
    // v_border_color = a_border_color;
    v_uv = final_uv;
    v_shader_kind = a_shader_kind;
  }
}
