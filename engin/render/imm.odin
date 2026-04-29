package render

import "core:math/linalg"
import "core:sys/windows"
import "vendor:OpenGL"

import "../platform/win32"

/*
*
*/

Glyph :: struct {
	unicode:        rune,
	advance:        f32,
	al, ab, ar, at: f32, // atlas bounds
	pl, pb, pr, pt: f32, // plane bounds
}

Font :: struct {
	texture:        Texture,
	distance_range: f32,
	line_height:    f32,
	ascender:       f32,
	descender:      f32,
	glyphs:         map[rune]Glyph,
	kerning:        map[[2]rune]f32,
}

// TODO: flush when exceed 1MiB
Imm_Data :: struct {
	src, dst:    [4]f32,
	color:       [4]f32,
	roundness:   f32,
	shader_kind: enum i32 {
		Rect,
		Image,
		Text,
	},
}

imm_init :: proc(allocator := context.allocator) -> bool {
	_imm_data_list = make([dynamic]Imm_Data, allocator = allocator)

	_imm_uber_shader = shader_init(_imm_uber_vshader_src, _imm_uber_fshader_src) or_return

	OpenGL.GenVertexArrays(1, &_imm_vao)
	OpenGL.BindVertexArray(_imm_vao)
	OpenGL.GenBuffers(1, &_imm_vbo)
	OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, _imm_vbo)

	return _imm_shader_bind_layout(
		_imm_uber_shader,
		size_of(Imm_Data),
		_imm_uber_shader_attrib_layout,
	)
}

imm_begin :: proc() {
	set_render_target_to_default()
	// clear_render_target({0,0,0,1})
}

imm_end :: proc() {
	_imm_flush()

	windows.SwapBuffers(win32._hdc)
	// windows.ValidateRect(win32._hwnd, nil) // TODO: check
}

imm_push_rect :: proc(pos, size: [2]f32, color: [4]f32, roundness: f32 = 0) {
	append(
		&_imm_data_list,
		Imm_Data {
			src = {0.0, 0.0, 1.0, 1.0},
			dst = {pos.x, pos.y, pos.x + size.x, pos.y + size.y},
			color = color,
			roundness = roundness,
			shader_kind = .Rect,
		},
	)
}

imm_push_rect_center :: proc(center, size: [2]f32, color: [4]f32, roundness: f32 = 0) {
	pos := center - size * 0.5
	imm_push_rect(pos, size, color, roundness)
}

imm_push_circle :: proc(center: [2]f32, radius: f32, color: [4]f32) {
	imm_push_rect_center(center, radius, color, radius)
}

imm_push_image_ex :: proc(
	texture: Texture,
	src_pos, src_size: [2]f32,
	dst_pos, dst_size: [2]f32,
	color: [4]f32 = {1, 1, 1, 1},
	roundness: f32 = 0,
) {
	_set_current_texture(texture.handle)

	tw := cast(f32)texture.size.x
	th := cast(f32)texture.size.y

	u0 := src_pos.x / tw
	v0 := src_pos.y / th
	u1 := (src_pos.x + src_size.x) / tw
	v1 := (src_pos.y + src_size.y) / th

	append(
		&_imm_data_list,
		Imm_Data {
			src = {u0, v0, u1, v1},
			dst = {dst_pos.x, dst_pos.y, dst_pos.x + dst_size.x, dst_pos.y + dst_size.y},
			color = color,
			roundness = roundness,
			shader_kind = .Image,
		},
	)
}

imm_push_image :: proc(
	texture: Texture,
	pos, size: [2]f32,
	color: [4]f32 = {1.0, 1.0, 1.0, 1.0},
	roundness: f32 = 0,
) {
	imm_push_image_ex(texture, {0, 0}, linalg.to_f32(texture.size), pos, size, color, roundness)
}

imm_push_text :: proc(font: Font, text: string, pos: [2]f32, size: f32, color: [4]f32) {
	_set_current_texture(font.texture.handle)

	tw := cast(f32)font.texture.size.x
	th := cast(f32)font.texture.size.y

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

		append(&_imm_data_list, Imm_Data{dst = dst, src = src, color = color, shader_kind = .Text})

		cursor_x += glyph.advance * size
		prev_char = char
	}
}

/*
*
*/

@(private = "file")
_imm_vao, _imm_vbo: u32
@(private = "file")
_imm_uber_shader: Shader
@(private = "file")
_imm_data_list: [dynamic]Imm_Data

@(private = "file")
_imm_current_texture: Texture
@(private = "file")
_imm_batch_has_texture: bool

@(private = "file")
_set_current_texture :: proc(handle: u32) {
	if _imm_batch_has_texture && _imm_current_texture.handle != handle {
		_imm_flush()
	}
	_imm_current_texture.handle = handle
	_imm_batch_has_texture = true
}

@(private = "file")
_imm_flush :: proc() -> bool {
	if len(_imm_data_list) == 0 do return true

	defer {
		clear(&_imm_data_list)
		_imm_batch_has_texture = false
	}

	OpenGL.Enable(OpenGL.BLEND)
	OpenGL.BlendFunc(OpenGL.SRC_ALPHA, OpenGL.ONE_MINUS_SRC_ALPHA)

	// OpenGL.Disable(OpenGL.DEPTH_TEST)
	// OpenGL.Disable(OpenGL.CULL_FACE)

	OpenGL.UseProgram(_imm_uber_shader.handle)
	OpenGL.BindVertexArray(_imm_vao)
	OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, _imm_vbo)

	client_size := win32.get_client_size()
	proj_ortho := linalg.matrix_ortho3d(
		0,
		cast(f32)client_size.x,
		cast(f32)client_size.y,
		0,
		-1,
		1,
	)

	u_proj_ortho, u_proj_ortho_ok := _imm_uber_shader.uniforms["u_proj_ortho"]
	if !u_proj_ortho_ok || u_proj_ortho.location < 0 {
		assert(false, "u_proj_ortho uniform not found")
		return false
	}
	OpenGL.UniformMatrix4fv(u_proj_ortho.location, 1, false, &proj_ortho[0, 0])
	// OpenGL.UniformMatrix4fv(u_proj_ortho.location, 1, false, cast(^f32)&proj_ortho)

	// u_texture, u_texture_ok := _imm_uber_shader.uniforms["u_texture"]
	// if u_texture_ok && u_texture.location >= 0 {
	// 	OpenGL.Uniform1i(u_texture.location, 0)
	// }

	OpenGL.ActiveTexture(OpenGL.TEXTURE0)
	OpenGL.BindTexture(OpenGL.TEXTURE_2D, _imm_current_texture.handle)

	OpenGL.BufferData(
		OpenGL.ARRAY_BUFFER,
		len(_imm_data_list) * size_of(Imm_Data),
		raw_data(_imm_data_list),
		OpenGL.STREAM_DRAW,
	)

	OpenGL.DrawArraysInstanced(OpenGL.TRIANGLE_STRIP, 0, 4, cast(i32)len(_imm_data_list))

	return true
}

/*
*
*/

@(private = "file")
_imm_uber_vshader_src := `
#version 330 core

in vec4  a_dst;
in vec4  a_src;
in vec4  a_color;
in float a_roundness;
in int a_shader_kind;

out vec4  v_color;
out vec2  v_sdf_pos;
out vec2  v_half_size;
out float v_roundness;
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

  vec2 local_vert = verts[gl_VertexID];
  vec2 local_uv = local_vert * 0.5 + 0.5;
  vec2 final_uv = mix(a_src.xy, a_src.zw, local_uv);

  vec2 half_size = (a_dst.zw - a_dst.xy) * 0.5;
  vec2 center = a_dst.xy + half_size;
  vec2 pos = center + (local_vert * half_size);

  {
  	gl_Position = u_proj_ortho * vec4(pos, 0.0, 1.0);

  	v_color     = a_color;
  	v_sdf_pos   = local_vert * half_size;
  	v_half_size = half_size;
  	v_roundness = a_roundness;
  	v_uv        = final_uv;
   	v_shader_kind = a_shader_kind;
  }
}`

@(private = "file")
_imm_uber_fshader_src := `
#version 330 core

in vec4  v_color;
in vec2  v_sdf_pos;
in vec2  v_half_size;
in float v_roundness;
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

#define SHADER_KIND_RECT	0
#define SHADER_KIND_IMAGE	1
#define SHADER_KIND_TEXT	2

#define TEXT_THICKNESS	0.6	// 0.5 is default
#define MSDF_PXRANGE	8

void main() {
	float corner_alpha = 1.0;
	vec4 tex_color = vec4(1.0);

	if (v_shader_kind != SHADER_KIND_RECT) {
		tex_color = texture(u_texture, v_uv);
	}

	switch (v_shader_kind) {
	case SHADER_KIND_IMAGE:	// fallthrough
	case SHADER_KIND_RECT:
		if (v_roundness > 0.0) {
      float safe_radius = min(v_roundness, min(v_half_size.x, v_half_size.y));
      float dist = sdf_rounded_box(v_sdf_pos, v_half_size, safe_radius);

      float aa = length(vec2(dFdx(dist), dFdy(dist)));
      float feather = aa * 0.5;
      corner_alpha = 1.0 - smoothstep(-feather, feather, dist);
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
  frag_color.a *= corner_alpha;
}`

@(private = "file")
_imm_uber_shader_attrib_layout: []Shader_Attrib_Layout = {
	{"a_src", 4, OpenGL.FLOAT, offset_of(Imm_Data, src)},
	{"a_dst", 4, OpenGL.FLOAT, offset_of(Imm_Data, dst)},
	{"a_color", 4, OpenGL.FLOAT, offset_of(Imm_Data, color)},
	{"a_roundness", 1, OpenGL.FLOAT, offset_of(Imm_Data, roundness)},
	{"a_shader_kind", 1, OpenGL.INT, offset_of(Imm_Data, shader_kind)},
}

@(private = "file")
_imm_shader_bind_layout :: proc(
	shader: Shader,
	stride: i32,
	layout: []Shader_Attrib_Layout,
) -> bool {
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
				false,
				stride,
				attrib.offset,
			)
		}

		OpenGL.VertexAttribDivisor(cast(u32)loc, 1)
	}

	return true
}
