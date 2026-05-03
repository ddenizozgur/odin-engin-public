package render

import "base:runtime"
import "core:fmt"
import "core:sys/windows"
import "vendor:OpenGL"

gl_load_up_to :: proc(major, minor: int) {
	OpenGL.load_up_to(major, minor, windows.gl_set_proc_address)

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
			false,
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
}

/*
*
*/

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

	source_str: string
	switch source {
	case OpenGL.DEBUG_SOURCE_API:
		source_str = "API"
	case OpenGL.DEBUG_SOURCE_WINDOW_SYSTEM:
		source_str = "WINDOW_SYSTEM"
	case OpenGL.DEBUG_SOURCE_SHADER_COMPILER:
		return // vendor:OpenGL will handle
	// source_str = "SHADER_COMPILER"
	case OpenGL.DEBUG_SOURCE_THIRD_PARTY:
		source_str = "THIRD_PARTY"
	case OpenGL.DEBUG_SOURCE_APPLICATION:
		source_str = "APPLICATION"
	case OpenGL.DEBUG_SOURCE_OTHER:
		source_str = "OTHER"
	case:
		source_str = "UNKNOWN"
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

	fmt.eprintfln("[GL %s] [%s] [%s] (%d): %s", severity_str, source_str, type_str, id, message)
}
