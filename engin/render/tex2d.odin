package render

import "core:image"
import "core:image/bmp"
import "core:image/jpeg"
import "core:image/png"

import "base:runtime"
import "core:fmt"
import "vendor:OpenGL"

/*
*
*/

Tex2D_Format :: enum {
	R8,
	RG8,
	RGB8,
	RGBA8,
}

Tex2D_Filter :: enum {
	Nearest,
	Linear,
}

Tex2D :: struct {
	handle: u32,
	size:   [2]int,
	format: Tex2D_Format,
}

tex2d_load_from_bytes :: proc(
	bytes: []byte,
	size: [2]int,
	filter: Tex2D_Filter = .Linear,
	format: Tex2D_Format = .RGBA8,
) -> Tex2D {
	handle: u32
	OpenGL.GenTextures(1, &handle)
	OpenGL.BindTexture(OpenGL.TEXTURE_2D, handle)

	gl_filter := _tex2d_filter_to_gl(filter)
	internal_format, gl_format, alignment := _tex2d_format_to_gl(format)

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

tex2d_load_from_image :: proc(
	img: ^image.Image,
	filter: Tex2D_Filter = .Linear,
) -> (
	tex: Tex2D,
	ok: bool,
) {
	format := _tex2d_format_from_channels(img.channels) or_return
	return tex2d_load_from_bytes(img.pixels.buf[:], {img.width, img.height}, filter, format), true
}

tex2d_load_from_file :: proc(filepath: string, filter: Tex2D_Filter = .Linear) -> (Tex2D, bool) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	img, err := image.load_from_file(filepath, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("[ERROR]: %v", err)
		return {}, false
	}

	return tex2d_load_from_image(img, filter)
}

/*
*
*/

@(private = "file")
_tex2d_format_to_gl :: proc(
	format: Tex2D_Format,
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
_tex2d_filter_to_gl :: proc(filter: Tex2D_Filter) -> i32 {
	switch filter {
	case .Nearest:
		return OpenGL.NEAREST
	case .Linear:
		return OpenGL.LINEAR
	}
	return OpenGL.LINEAR
}

@(private = "file")
_tex2d_format_from_channels :: proc(channels: int) -> (Tex2D_Format, bool) {
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
