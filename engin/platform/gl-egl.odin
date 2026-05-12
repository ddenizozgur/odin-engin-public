#+build linux
package platform

import "core:fmt"
import "vendor:OpenGL"
import "vendor:egl"

@(private)
_gl_swap_interval :: #force_inline proc(interval: i32) -> bool {
	return cast(bool)egl.SwapInterval(_egl_display, interval)
}

@(private)
_gl_swap_buffers :: #force_inline proc() {
	egl.SwapBuffers(_egl_display, _egl_surface)
}

@(private)
_gl_load :: proc() -> bool {
	_egl_init() or_return
	OpenGL.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, egl.gl_set_proc_address)
	return true
}

//
// Private
//
@(private = "file")
_egl_display: egl.Display
@(private = "file")
_egl_surface: egl.Surface
@(private = "file")
_egl_context: egl.Context

@(private = "file")
EGL_SAMPLES :: 0x3031
@(private = "file")
EGL_SAMPLE_BUFFERS :: 0x3032

@(private = "file")
_egl_init :: proc() -> bool {
	if _display == nil {
		assert(false, "call window_init() first")
		return false
	}

	_egl_display = egl.GetDisplay(cast(egl.NativeDisplayType)_display)
	if _egl_display == egl.NO_DISPLAY {
		fmt.eprintln("[ERROR] Failed to get EGL display")
		return false
	}

	egl_major, egl_minor: i32
	if !egl.Initialize(_egl_display, &egl_major, &egl_minor) {
		fmt.eprintln("[ERROR] Failed to initialize EGL display")
		return false
	}
	// TODO: check
	if egl_major < 1 || (egl_major == 1 && egl_minor < 4) {
		fmt.eprintln("[ERROR] Unsupported EGL version. Needed at least 1.4")
		return false
	}
	if egl_major == 1 && egl_minor == 4 {
		// The driver hopefully has the KHR_create_context extension for 1.4
		fmt.eprintln("[WARNING] EGL 1.5 recommended, 1.4 found")
	}

	cfg: egl.Config
	{
		// TODO: surface attribs
		cfg_attribs := []i32 {
			egl.RED_SIZE,
			8,
			egl.GREEN_SIZE,
			8,
			egl.BLUE_SIZE,
			8,
			egl.ALPHA_SIZE,
			8,
			egl.DEPTH_SIZE,
			24,
			egl.STENCIL_SIZE,
			8,
			egl.RENDERABLE_TYPE,
			egl.OPENGL_BIT,
			egl.SURFACE_TYPE,
			egl.WINDOW_BIT,
			// EGL_CONFORMANT,        EGL_OPENGL_BIT, ???????
			// EGL_COLOR_BUFFER_TYPE, EGL_RGB_BUFFER,
			EGL_SAMPLE_BUFFERS,
			1, // Request MSAA
			EGL_SAMPLES,
			4, // 4x MSAA
			egl.NONE,
		}

		num_cfg: i32
		pf_good := egl.ChooseConfig(_egl_display, raw_data(cfg_attribs), &cfg, 1, &num_cfg)

		// Fallback if 4x MSAA is not supported
		if !pf_good || num_cfg == 0 {
			config_attribs_no_msaa := []i32 {
				egl.RED_SIZE,
				8,
				egl.GREEN_SIZE,
				8,
				egl.BLUE_SIZE,
				8,
				egl.ALPHA_SIZE,
				8,
				egl.DEPTH_SIZE,
				24,
				egl.STENCIL_SIZE,
				8,
				egl.RENDERABLE_TYPE,
				egl.OPENGL_BIT,
				egl.SURFACE_TYPE,
				egl.WINDOW_BIT,
				egl.NONE,
			}

			pf_good = egl.ChooseConfig(
				_egl_display,
				raw_data(config_attribs_no_msaa),
				&cfg,
				1,
				&num_cfg,
			)
			if !pf_good || num_cfg == 0 {
				assert(false, "egl.ChooseConfig() Failed to choose EGL configuration")
				return false
			}
		}
	}

	if !egl.BindAPI(egl.OPENGL_API) {
		fmt.eprintln("[ERROR] Failed to initialize EGL api to OpenGL")
		return false
	}

	{
		ctx_attribs := []i32 {
			egl.CONTEXT_MAJOR_VERSION,
			GL_VERSION_MAJOR,
			egl.CONTEXT_MINOR_VERSION,
			GL_VERSION_MINOR,
			egl.CONTEXT_OPENGL_PROFILE_MASK,
			egl.CONTEXT_OPENGL_CORE_PROFILE_BIT,
			egl.CONTEXT_OPENGL_DEBUG,
			cast(i32)ODIN_DEBUG,
			egl.NONE,
		}

		_egl_context = egl.CreateContext(_egl_display, cfg, egl.NO_CONTEXT, raw_data(ctx_attribs))
		if _egl_context == egl.NO_CONTEXT {
			fmt.eprintln("[ERROR] Failed to create OpenGL context with EGL")
			return false
		}
	}

	_egl_surface = egl.CreateWindowSurface(
		_egl_display,
		cfg,
		cast(egl.NativeWindowType)uintptr(_window),
		nil,
	)
	if _egl_surface == egl.NO_SURFACE {
		fmt.eprintln("[ERROR] Failed to create EGL surface")
		return false
	}

	egl.MakeCurrent(_egl_display, _egl_surface, _egl_surface, _egl_context)

	return true
}
