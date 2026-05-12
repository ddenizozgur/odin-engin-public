package platform

import "base:runtime"
import "core:fmt"
import "vendor:OpenGL"

gl_swap_interval :: #force_inline proc(interval: i32) -> bool {
	return _gl_swap_interval(interval)
}

gl_swap_buffers :: #force_inline proc() {
	_gl_swap_buffers()
}

// gl_cleanup :: #force_inline proc() {
// 	when ODIN_OS == .Linux {
// 		_gl_cleanup()
// 	}
// }
gl_load :: proc() -> bool {
	_gl_load() or_return

	when ODIN_DEBUG {
		OpenGL.Enable(OpenGL.DEBUG_OUTPUT)
		OpenGL.Enable(OpenGL.DEBUG_OUTPUT_SYNCHRONOUS)

		OpenGL.DebugMessageControl(
			OpenGL.DONT_CARE,
			OpenGL.DONT_CARE,
			OpenGL.DEBUG_SEVERITY_HIGH,
			0,
			nil,
			true,
		)
		OpenGL.DebugMessageControl(
			OpenGL.DONT_CARE,
			OpenGL.DONT_CARE,
			OpenGL.DEBUG_SEVERITY_MEDIUM,
			0,
			nil,
			true,
		)
		OpenGL.DebugMessageControl(
			OpenGL.DONT_CARE,
			OpenGL.DONT_CARE,
			OpenGL.DEBUG_SEVERITY_LOW,
			0,
			nil,
			false,
		)
		OpenGL.DebugMessageControl(
			OpenGL.DONT_CARE,
			OpenGL.DONT_CARE,
			OpenGL.DEBUG_SEVERITY_NOTIFICATION,
			0,
			nil,
			false,
		)

		OpenGL.DebugMessageCallback(_gl_debug_callback, nil)
	}

	return true
}

GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 3

//
// Private
//
@(private = "file")
_gl_debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = runtime.default_context()

	src_str: string
	switch source {
	case OpenGL.DEBUG_SOURCE_API:
		src_str = "API"
	case OpenGL.DEBUG_SOURCE_WINDOW_SYSTEM:
		src_str = "WINDOW_SYSTEM"
	case OpenGL.DEBUG_SOURCE_SHADER_COMPILER:
		return // vendor:OpenGL will handle
	// src_str = "SHADER_COMPILER"
	case OpenGL.DEBUG_SOURCE_THIRD_PARTY:
		src_str = "THIRD_PARTY"
	case OpenGL.DEBUG_SOURCE_APPLICATION:
		src_str = "APPLICATION"
	case OpenGL.DEBUG_SOURCE_OTHER:
		src_str = "OTHER"
	case:
		src_str = "UNKNOWN"
	}

	type_str: string
	switch type {
	case OpenGL.DEBUG_TYPE_ERROR:
		type_str = "ERROR"
	case OpenGL.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		type_str = "DEPRECATED"
	case OpenGL.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		type_str = "UNDEFINED_BEHAVIOR"
	case OpenGL.DEBUG_TYPE_PORTABILITY:
		type_str = "PORTABILITY"
	case OpenGL.DEBUG_TYPE_PERFORMANCE:
		type_str = "PERFORMANCE"
	case OpenGL.DEBUG_TYPE_MARKER:
		type_str = "MARKER"
	case OpenGL.DEBUG_TYPE_PUSH_GROUP:
		type_str = "PUSH_GROUP"
	case OpenGL.DEBUG_TYPE_POP_GROUP:
		type_str = "POP_GROUP"
	case OpenGL.DEBUG_TYPE_OTHER:
		type_str = "OTHER"
	case:
		type_str = "UNKNOWN"
	}

	severity_str: string
	switch severity {
	case OpenGL.DEBUG_SEVERITY_HIGH:
		severity_str = "HIGH"
	case OpenGL.DEBUG_SEVERITY_MEDIUM:
		severity_str = "MEDIUM"
	case OpenGL.DEBUG_SEVERITY_LOW:
		severity_str = "LOW"
	case OpenGL.DEBUG_SEVERITY_NOTIFICATION:
		severity_str = "NOTIFICATION"
	case:
		severity_str = "UNKNOWN"
	}

	fmt.eprintfln("[GL %s] [%s] [%s] (%d): %s", severity_str, src_str, type_str, id, message)
}
