package render

import "../platform/win32"
import "base:runtime"
import "core:fmt"
import "vendor:OpenGL"

/*
*
*/

resize_default_render_target :: proc() {
	client_size := win32.get_client_size()
	OpenGL.Viewport(0, 0, client_size.x, client_size.y)
}

clear_render_target :: proc(color: [4]f32) {
	OpenGL.ClearColor(color.r, color.g, color.b, color.a)
	// OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT | OpenGL.STENCIL_BUFFER_BIT | OpenGL.DEPTH_BUFFER_BIT)
	OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT | OpenGL.DEPTH_BUFFER_BIT)
}

set_render_target_to_default :: proc() {
	client_size := win32.get_client_size()
	OpenGL.Viewport(0, 0, client_size.x, client_size.y)

	OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
	OpenGL.DrawBuffer(OpenGL.BACK)
}

/*
*
*/

Shader_Attrib_Layout :: struct {
	name:   cstring,
	size:   int,
	type:   u32, // OpenGL.FLOAT, etc.
	offset: uintptr,
}

Shader :: struct {
	handle:   u32,
	uniforms: OpenGL.Uniforms,
}

shader_init :: proc(vshader_src, fshader_src: string) -> (shader: Shader, ok: bool) {
	handle := OpenGL.load_shaders_source(vshader_src, fshader_src) or_return
	return Shader{handle = handle, uniforms = OpenGL.get_uniforms_from_program(handle)}, true
}

/*
*
*/

import "core:image"
import "core:image/bmp"
import "core:image/jpeg"
import "core:image/png"

Texture_Format :: enum {
	R8,
	RG8,
	RGB8,
	RGBA8,
}

Texture_Filter :: enum {
	Nearest,
	Linear,
}

Texture :: struct {
	handle: u32,
	size:   [2]int,
	format: Texture_Format,
}

texture_load_from_bytes :: proc(
	bytes: []byte,
	size: [2]int,
	filter: Texture_Filter = .Linear,
	format: Texture_Format = .RGBA8,
) -> Texture {
	handle: u32
	OpenGL.GenTextures(1, &handle)
	OpenGL.BindTexture(OpenGL.TEXTURE_2D, handle)

	gl_filter := _texture_filter_to_gl(filter)
	internal_format, gl_format, alignment := _texture_format_to_gl(format)

	prev_alignment: i32
	OpenGL.GetIntegerv(OpenGL.UNPACK_ALIGNMENT, &prev_alignment)
	defer OpenGL.PixelStorei(OpenGL.UNPACK_ALIGNMENT, prev_alignment)

	OpenGL.PixelStorei(OpenGL.UNPACK_ALIGNMENT, alignment)
	OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MIN_FILTER, gl_filter)
	OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MAG_FILTER, gl_filter)
	OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_S, OpenGL.CLAMP_TO_EDGE) // OpenGL.REPEAT
	OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_T, OpenGL.CLAMP_TO_EDGE)

	OpenGL.TexImage2D(
		OpenGL.TEXTURE_2D,
		0,
		internal_format,
		cast(i32)size.x,
		cast(i32)size.y,
		0,
		gl_format,
		OpenGL.UNSIGNED_BYTE,
		raw_data(bytes),
	)

	return {handle = handle, size = size, format = format}
}

texture_load_from_image :: proc(
	img: ^image.Image,
	filter: Texture_Filter = .Linear,
) -> (
	tex: Texture,
	ok: bool,
) {
	format := _texture_format_from_channels(img.channels) or_return
	return texture_load_from_bytes(img.pixels.buf[:], {img.width, img.height}, filter, format),
		true
}

texture_load_from_file :: proc(
	filepath: string,
	filter: Texture_Filter = .Linear,
) -> (
	Texture,
	bool,
) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	img, err := image.load_from_file(filepath, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("[ERROR]: %v", err)
		return {}, false
	}

	return texture_load_from_image(img, filter)
}

/*
*
*/

@(private = "file")
_texture_format_to_gl :: proc(
	format: Texture_Format,
) -> (
	internal_format: i32,
	gl_format: u32,
	alignment: i32,
) {
	switch format {
	case .R8:
		return OpenGL.R8, OpenGL.RED, 1
	case .RG8:
		return OpenGL.RG8, OpenGL.RG, 1 // 2-byte rows still need align=1 if width is odd, safest is 1
	case .RGB8:
		return OpenGL.RGB8, OpenGL.RGB, 1 // RGB rows are rarely 4-byte aligned
	case .RGBA8:
		return OpenGL.RGBA8, OpenGL.RGBA, 4
	}
	return OpenGL.RGBA8, OpenGL.RGBA, 4
}

@(private = "file")
_texture_filter_to_gl :: proc(filter: Texture_Filter) -> i32 {
	switch filter {
	case .Nearest:
		return OpenGL.NEAREST
	case .Linear:
		return OpenGL.LINEAR
	}
	return OpenGL.LINEAR
}

@(private = "file")
_texture_format_from_channels :: proc(channels: int) -> (Texture_Format, bool) {
	switch channels {
	case 1:
		return .R8, true
	case 2:
		return .RG8, true
	case 3:
		return .RGB8, true
	case 4:
		return .RGBA8, true
	}

	assert(false, "unsupported channel count")
	return .RGBA8, false
}

/*
*
*/
