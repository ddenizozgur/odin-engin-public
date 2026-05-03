package render

import "vendor:OpenGL"

/*
*
*/

Shader_Attrib_Layout :: struct {
	name:      cstring,
	size:      int,
	type:      u32, // OpenGL.FLOAT, etc.
	offset:    uintptr,
	normalize: bool,
}

Shader :: struct {
	handle:   u32,
	uniforms: OpenGL.Uniforms,
}

shader_init :: proc(vshader_src, fshader_src: string) -> (shader: Shader, ok: bool) {
	handle := OpenGL.load_shaders_source(vshader_src, fshader_src) or_return
	return Shader{handle = handle, uniforms = OpenGL.get_uniforms_from_program(handle)}, true
}
