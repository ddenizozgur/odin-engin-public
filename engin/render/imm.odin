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
_uber_vshader_src := cast(string)#load("shader_src/imm_uber_vshader.glsl")
@(private = "file")
_uber_fshader_src := cast(string)#load("shader_src/imm_uber_fshader.glsl")

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
