package render

import "core:math/linalg"
import "core:sys/windows"
import "vendor:OpenGL"

import "../platform/win32"

/*
*
*/

// TODO: flush when exceed 1MiB
Imm_Per_Data :: struct {
	src:         [4]f32,
	dst:         [4]f32,
	color_tl:    RGBA32,
	color_tr:    RGBA32,
	color_bl:    RGBA32,
	color_br:    RGBA32,
	roundness:   f32,
	// border_size:  f32,
	// border_color: RGBA32,
	shader_kind: enum i32 {
		Rect,
		Image,
		Text,
	},
}

/*
*
*/

imm_begin :: proc(allocator := context.allocator) -> bool {
	@(static) initted: bool
	if !initted {
		_init_state(allocator) or_return
		initted = true
	}
	set_target_to_default()
	return true
}

imm_end :: proc() {
	_flush()

	windows.SwapBuffers(win32._hdc)
	// windows.ValidateRect(win32._hwnd, nil) // TODO: check
}

/*
*
*/

imm_push_rect_grad :: proc(
	pos, size: [2]f32,
	color_tl, color_tr, color_bl, color_br: RGBA32,
	roundness := f32(0),
) {
	append(
		&_data_list,
		Imm_Per_Data {
			src = {0.0, 0.0, 1.0, 1.0},
			dst = {pos.x, pos.y, pos.x + size.x, pos.y + size.y},
			color_tl = color_tl,
			color_tr = color_tr,
			color_bl = color_bl,
			color_br = color_br,
			roundness = roundness,
			shader_kind = .Rect,
		},
	)
}

imm_push_rect :: proc(pos, size: [2]f32, color: RGBA32, roundness := f32(0)) {
	imm_push_rect_grad(pos, size, color, color, color, color, roundness)
}

/*
*
*/

imm_push_circle_grad :: proc(
	center: [2]f32,
	radius: f32,
	color_tl, color_tr, color_bl, color_br: RGBA32,
) {
	real_pos := pos_from_align_kind(center, radius * 2, .Center)
	imm_push_rect_grad(real_pos, radius * 2, color_tl, color_tr, color_bl, color_br, radius)
}

imm_push_circle :: proc(center: [2]f32, radius: f32, color: RGBA32) {
	imm_push_circle_grad(center, radius, color, color, color, color)
}

/*
*
*/

imm_push_image_ex_grad :: proc(
	tex2d: Tex2D,
	src_pos, src_size: [2]f32,
	dst_pos, dst_size: [2]f32,
	tint_tl, tint_tr, tint_bl, tint_br: RGBA32,
	roundness := f32(0),
) {
	_set_current_tex2d(tex2d.handle)

	tw := cast(f32)tex2d.size.x
	th := cast(f32)tex2d.size.y

	u0 := src_pos.x / tw
	v0 := src_pos.y / th
	u1 := (src_pos.x + src_size.x) / tw
	v1 := (src_pos.y + src_size.y) / th

	append(
		&_data_list,
		Imm_Per_Data {
			src = {u0, v0, u1, v1},
			dst = {dst_pos.x, dst_pos.y, dst_pos.x + dst_size.x, dst_pos.y + dst_size.y},
			color_tl = tint_tl,
			color_tr = tint_tr,
			color_bl = tint_bl,
			color_br = tint_br,
			roundness = roundness,
			shader_kind = .Image,
		},
	)
}

imm_push_image_ex :: proc(
	tex2d: Tex2D,
	src_pos, src_size: [2]f32,
	dst_pos, dst_size: [2]f32,
	tint := WHITE,
	roundness := f32(0),
) {
	imm_push_image_ex_grad(
		tex2d,
		src_pos,
		src_size,
		dst_pos,
		dst_size,
		tint,
		tint,
		tint,
		tint,
		roundness,
	)
}

imm_push_image :: proc(tex2d: Tex2D, pos, size: [2]f32, tint := WHITE, roundness: f32 = 0) {
	imm_push_image_ex(tex2d, {0, 0}, linalg.to_f32(tex2d.size), pos, size, tint, roundness)
}

/*
*
*/

imm_push_text_grad :: proc(
	font: Font,
	text: string,
	pos: [2]f32,
	size: f32,
	color_tl, color_tr, color_bl, color_br: RGBA32,
) {
	_set_current_tex2d(font.tex2d.handle)

	tw := cast(f32)font.tex2d.size.x
	th := cast(f32)font.tex2d.size.y

	cursor_x := pos.x
	cursor_y := pos.y + font.ascender * size

	prev_char: rune

	for char in text {
		if char == '\n' {
			cursor_x = pos.x
			cursor_y += font.line_height * size
			prev_char = 0 // reset kerning
			continue
		}

		glyph := font.glyphs[char] or_continue

		// kerning
		if prev_char != 0 {
			if kern_advance, ok := font.kerning[{prev_char, char}]; ok {
				cursor_x += kern_advance * size
			}
		}

		// whitespace
		if glyph.al == glyph.ar {
			cursor_x += glyph.advance * size
			prev_char = char
			continue
		}

		dst := [4]f32 {
			cursor_x + glyph.pl * size, // x0
			cursor_y - glyph.pt * size, // y0
			cursor_x + glyph.pr * size, // x1
			cursor_y - glyph.pb * size, // y1
		}

		src := [4]f32 {
			glyph.al / tw,
			1.0 - (glyph.at / th), // top UV
			glyph.ar / tw,
			1.0 - (glyph.ab / th), // bottom UV
		}

		append(
			&_data_list,
			Imm_Per_Data {
				dst = dst,
				src = src,
				color_tl = color_tl,
				color_tr = color_tr,
				color_bl = color_bl,
				color_br = color_br,
				shader_kind = .Text,
			},
		)

		cursor_x += glyph.advance * size
		prev_char = char
	}
}

imm_push_text :: proc(font: Font, text: string, pos: [2]f32, size: f32, color: RGBA32) {
	imm_push_text_grad(font, text, pos, size, color, color, color, color)
}

// imm_push_scissor :: proc(x0, y0, x1, y1: i32) {
// 	_flush()
// 	OpenGL.Enable(OpenGL.SCISSOR_TEST)
// 	OpenGL.Scissor(x0, y0, x1 - x0, y1 - y0)
// }
// imm_clear_scissor :: proc() {
// 	OpenGL.Disable(OpenGL.SCISSOR_TEST)
// }

/*
*
*/

@(private = "file")
_vao, _vbo: u32
@(private = "file")
_uber_shader: Shader
@(private = "file")
_data_list: [dynamic]Imm_Per_Data

@(private = "file")
_current_tex2d: Tex2D
@(private = "file")
_batch_has_tex2d: bool

@(private = "file")
_set_current_tex2d :: proc(handle: u32) {
	if _batch_has_tex2d && _current_tex2d.handle != handle {
		_flush()
	}
	_current_tex2d.handle = handle
	_batch_has_tex2d = true
}

@(private = "file")
_init_state :: proc(allocator := context.allocator) -> bool {
	_data_list = make([dynamic]Imm_Per_Data, allocator = allocator)

	_uber_shader = shader_init(_uber_vshader_src, _uber_fshader_src) or_return

	OpenGL.GenVertexArrays(1, &_vao)
	OpenGL.BindVertexArray(_vao)
	OpenGL.GenBuffers(1, &_vbo)
	OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, _vbo)

	return _shader_bind_layout(_uber_shader, size_of(Imm_Per_Data), _uber_shader_attrib_layout)
}

@(private = "file")
_flush :: proc() -> bool {
	if len(_data_list) == 0 do return true

	defer {
		clear(&_data_list)
		_batch_has_tex2d = false
	}

	OpenGL.Enable(OpenGL.BLEND)
	OpenGL.BlendFunc(OpenGL.SRC_ALPHA, OpenGL.ONE_MINUS_SRC_ALPHA)
	// OpenGL.BlendFunc(OpenGL.ONE, OpenGL.ONE_MINUS_SRC_ALPHA)

	// OpenGL.Disable(OpenGL.DEPTH_TEST)
	// OpenGL.Disable(OpenGL.CULL_FACE)

	OpenGL.UseProgram(_uber_shader.handle)
	OpenGL.BindVertexArray(_vao)
	OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, _vbo)

	client_size := win32.get_client_size()
	proj_ortho := linalg.matrix_ortho3d(
		0,
		cast(f32)client_size.x,
		cast(f32)client_size.y,
		0,
		-1,
		1,
	)

	u_proj_ortho, u_proj_ortho_ok := _uber_shader.uniforms["u_proj_ortho"]
	if !u_proj_ortho_ok || u_proj_ortho.location < 0 {
		assert(false, "u_proj_ortho uniform not found")
		return false
	}
	OpenGL.UniformMatrix4fv(u_proj_ortho.location, 1, false, &proj_ortho[0, 0])
	// OpenGL.UniformMatrix4fv(u_proj_ortho.location, 1, false, cast(^f32)&proj_ortho)

	// u_texture, u_texture_ok := _uber_shader.uniforms["u_texture"]
	// if u_texture_ok && u_texture.location >= 0 {
	// 	OpenGL.Uniform1i(u_texture.location, 0)
	// }

	OpenGL.ActiveTexture(OpenGL.TEXTURE0)
	OpenGL.BindTexture(OpenGL.TEXTURE_2D, _current_tex2d.handle)

	OpenGL.BufferData(
		OpenGL.ARRAY_BUFFER,
		len(_data_list) * size_of(Imm_Per_Data),
		raw_data(_data_list),
		OpenGL.STREAM_DRAW,
	)

	OpenGL.DrawArraysInstanced(OpenGL.TRIANGLE_STRIP, 0, 4, cast(i32)len(_data_list))

	return true
}

/*
*
*/

@(private = "file")
_uber_vshader_src := `
#version 330 core

in vec4  a_dst;
in vec4  a_src;
in vec4  a_color_tl;
in vec4  a_color_tr;
in vec4  a_color_bl;
in vec4  a_color_br;
in float a_roundness;
// in float a_border_size;
// in vec4  a_border_color;
in int   a_shader_kind;

out vec4  v_color;
out vec2  v_sdf_pos;
out vec2  v_half_size;
out float v_roundness;
// out float v_border_size;
// out vec4  v_border_color;
out vec2  v_uv;
flat out int v_shader_kind;

uniform mat4 u_proj_ortho;

void main() {
  vec2 verts[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2(-1.0,  1.0),
    vec2( 1.0,  1.0)
  );

  vec4 colors[4] = vec4[](
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

  	v_color        = local_color;
  	v_sdf_pos      = local_vert * half_size;
  	v_half_size    = half_size;
  	v_roundness    = a_roundness;
   	// v_border_size  = a_border_size;
    // v_border_color = a_border_color;
  	v_uv           = final_uv;
   	v_shader_kind  = a_shader_kind;
  }
}`

@(private = "file")
_uber_fshader_src := `
#version 330 core

in vec4  v_color;
in vec2  v_sdf_pos;
in vec2  v_half_size;
in float v_roundness;
// in float v_border_size;
// in vec4  v_border_color;
in vec2  v_uv;
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

#define SHADER_KIND_RECT	0
#define SHADER_KIND_IMAGE	1
#define SHADER_KIND_TEXT	2

#define TEXT_THICKNESS	0.6
#define MSDF_PXRANGE    8.0

void main() {
  float corner_alpha = 1.0;
  // float border_mix = 0.0;
  vec4 tex_color = vec4(1.0);

  if (v_shader_kind != SHADER_KIND_RECT) {
    tex_color = texture(u_texture, v_uv);
  }

  switch (v_shader_kind) {
  case SHADER_KIND_IMAGE:    // fallthrough
  case SHADER_KIND_RECT:
  	// if (v_roundness > 0.0 || v_border_size > 0.0) {
  	if (v_roundness > 0.0) {
      float safe_radius = min(v_roundness, min(v_half_size.x, v_half_size.y));
      float dist = sdf_rounded_box(v_sdf_pos, v_half_size, safe_radius);

      float aa = length(vec2(dFdx(dist), dFdy(dist)));
      float feather = aa * 0.5;
      corner_alpha = 1.0 - smoothstep(-feather, feather, dist);

      // if (v_border_size > 0.0) {
      //   vec2 inner_half_size = max(v_half_size - v_border_size, vec2(0.0));
      //   float inner_radius = max(safe_radius - v_border_size, 0.0);
      //   float inner_dist = sdf_rounded_box(v_sdf_pos, inner_half_size, inner_radius);
      //   border_mix = smoothstep(-feather, feather, inner_dist);
      // }
    }
  break;
  case SHADER_KIND_TEXT: {
    float sd = msdf_median(tex_color.r, tex_color.g, tex_color.b) - 0.5;

    vec2 msdf_tex_size = vec2(textureSize(u_texture, 0));
    vec2 unit_range = vec2(MSDF_PXRANGE) / msdf_tex_size;

    vec2 screen_tex_size = vec2(1.0) / fwidth(v_uv);
    float screen_px_range = max(0.5 * dot(unit_range, screen_tex_size), 1.0);

    float screen_px_distance = screen_px_range * sd;
    float opacity = clamp(screen_px_distance + TEXT_THICKNESS, 0.0, 1.0);

    tex_color = vec4(1.0, 1.0, 1.0, opacity);
  } break;
  default:
    break;
  }

  frag_color = tex_color * v_color;

  // if (v_shader_kind != SHADER_KIND_TEXT && v_border_size > 0.0) {
  // 	float final_mix = border_mix * v_border_color.a;
  //   frag_color = mix(frag_color, v_border_color, final_mix);
  // }

  // cut out the outside corners
  frag_color.a *= corner_alpha;

  // for bending
  float noise = gradient_noise(gl_FragCoord.xy);
  noise = (noise - 0.5) / 255.0;
  frag_color.rgb += noise;
}`


@(private = "file")
_uber_shader_attrib_layout: []Shader_Attrib_Layout = {
	{"a_src", 4, OpenGL.FLOAT, offset_of(Imm_Per_Data, src), false},
	{"a_dst", 4, OpenGL.FLOAT, offset_of(Imm_Per_Data, dst), false},
	{"a_color_tl", 4, OpenGL.UNSIGNED_BYTE, offset_of(Imm_Per_Data, color_tl), true},
	{"a_color_tr", 4, OpenGL.UNSIGNED_BYTE, offset_of(Imm_Per_Data, color_tr), true},
	{"a_color_bl", 4, OpenGL.UNSIGNED_BYTE, offset_of(Imm_Per_Data, color_bl), true},
	{"a_color_br", 4, OpenGL.UNSIGNED_BYTE, offset_of(Imm_Per_Data, color_br), true},
	{"a_roundness", 1, OpenGL.FLOAT, offset_of(Imm_Per_Data, roundness), false},
	// {"a_border_size", 1, OpenGL.FLOAT, offset_of(Imm_Per_Data, border_size), false},
	// {"a_border_color", 4, OpenGL.UNSIGNED_BYTE, offset_of(Imm_Per_Data, border_color), true},
	{"a_shader_kind", 1, OpenGL.INT, offset_of(Imm_Per_Data, shader_kind), false},
}

@(private = "file")
_shader_bind_layout :: proc(shader: Shader, stride: i32, layout: []Shader_Attrib_Layout) -> bool {
	// !!! binds on current vao, vbo
	for attrib in layout {
		loc := OpenGL.GetAttribLocation(shader.handle, attrib.name)

		if loc < 0 {
			// in production, might just print a warning and continue
			assert(false, "Failed to find shader attribute")
			return false
		}

		OpenGL.EnableVertexAttribArray(cast(u32)loc)
		if attrib.type == OpenGL.INT || attrib.type == OpenGL.UNSIGNED_INT {
			OpenGL.VertexAttribIPointer(
				cast(u32)loc,
				cast(i32)attrib.size,
				attrib.type,
				stride,
				attrib.offset,
			)
		} else {
			OpenGL.VertexAttribPointer(
				cast(u32)loc,
				cast(i32)attrib.size,
				attrib.type,
				attrib.normalize,
				stride,
				attrib.offset,
			)
		}

		OpenGL.VertexAttribDivisor(cast(u32)loc, 1)
	}

	return true
}
