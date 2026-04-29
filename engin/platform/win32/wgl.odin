#+build windows
package win32

import "core:sys/windows"

wgl_init :: proc() -> bool {
	if _hwnd == nil {
		assert(false, "call win32.window_init() first")
		return false
	}

	_wgl_init0() or_return

	pf: i32 = 0
	pf_count: u32 = 0

	pf_attribs := []i32 {
		windows.WGL_DRAW_TO_WINDOW_ARB,
		1,
		windows.WGL_SUPPORT_OPENGL_ARB,
		1,
		windows.WGL_DOUBLE_BUFFER_ARB,
		1,
		windows.WGL_PIXEL_TYPE_ARB,
		windows.WGL_TYPE_RGBA_ARB,
		windows.WGL_COLOR_BITS_ARB,
		32,
		windows.WGL_DEPTH_BITS_ARB,
		24,
		windows.WGL_STENCIL_BITS_ARB,
		8,
		windows.WGL_SAMPLE_BUFFERS_ARB,
		1,
		windows.WGL_SAMPLES_ARB, // fallback
		4,
		0,
	}
	pf_ok := windows.wglChoosePixelFormatARB(_hdc, raw_data(pf_attribs), nil, 1, &pf, &pf_count)

	// fallback for MSAA
	if !pf_ok || pf_count == 0 {
		pf_attribs_no_msaa := []i32 {
			windows.WGL_DRAW_TO_WINDOW_ARB,
			1,
			windows.WGL_SUPPORT_OPENGL_ARB,
			1,
			windows.WGL_DOUBLE_BUFFER_ARB,
			1,
			windows.WGL_PIXEL_TYPE_ARB,
			windows.WGL_TYPE_RGBA_ARB,
			windows.WGL_COLOR_BITS_ARB,
			32,
			windows.WGL_DEPTH_BITS_ARB,
			24,
			windows.WGL_STENCIL_BITS_ARB,
			8,
			0,
		}

		pf_ok = windows.wglChoosePixelFormatARB(
			_hdc,
			raw_data(pf_attribs_no_msaa),
			nil,
			1,
			&pf,
			&pf_count,
		)

		if !pf_ok || pf_count == 0 {
			assert(false, "wglChoosePixelFormatARB(): failed")
			return false
		}
	}

	dummy_pfd: windows.PIXELFORMATDESCRIPTOR
	windows.DescribePixelFormat(_hdc, pf, size_of(dummy_pfd), &dummy_pfd)
	if !windows.SetPixelFormat(_hdc, pf, &dummy_pfd) {
		assert(false, "SetPixelFormat(): failed")
		return false
	}
	// if !windows.SetPixelFormat(_window_state.hdc, pf, nil) { 	// TODO: check
	// 	assert(false, "SetPixelFormat(): failed")
	// 	return false
	// }

	context_attribs := []i32 {
		windows.WGL_CONTEXT_MAJOR_VERSION_ARB,
		4,
		windows.WGL_CONTEXT_MINOR_VERSION_ARB,
		3,
		windows.WGL_CONTEXT_PROFILE_MASK_ARB,
		windows.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
		windows.WGL_CONTEXT_FLAGS_ARB,
		cast(i32)ODIN_DEBUG * windows.WGL_CONTEXT_DEBUG_BIT_ARB,
		0,
	}

	hglrc := windows.wglCreateContextAttribsARB(_hdc, nil, raw_data(context_attribs))
	if hglrc == nil {
		assert(false, "wglCreateContextAttribsARB(): failed")
		return false
	}

	if !windows.wglMakeCurrent(_hdc, hglrc) {
		assert(false, "wglMakeCurrent(): failed")
		windows.wglDeleteContext(hglrc)
		return false
	}

	return true
}

@(private = "file")
_wgl_init0 :: proc() -> bool {
	hinst := cast(windows.HINSTANCE)windows.GetModuleHandleW(nil)

	wnd_class: windows.WNDCLASSW = {
		lpfnWndProc   = windows.DefWindowProcW,
		hInstance     = hinst,
		lpszClassName = "dummy-wnd-class-name",
	}
	if windows.RegisterClassW(&wnd_class) == 0 {
		assert(false, "RegisterClassW(): failed")
		return false
	}
	defer windows.UnregisterClassW(wnd_class.lpszClassName, hinst)

	hwnd := windows.CreateWindowExW(
		0,
		wnd_class.lpszClassName,
		"dummy-window-name",
		0,
		windows.CW_USEDEFAULT,
		windows.CW_USEDEFAULT,
		windows.CW_USEDEFAULT,
		windows.CW_USEDEFAULT,
		nil,
		nil,
		hinst,
		nil,
	)
	if hwnd == nil {
		assert(false, "CreateWindowExW(): failed")
		return false
	}
	defer windows.DestroyWindow(hwnd)

	hdc := windows.GetDC(hwnd)
	defer windows.ReleaseDC(hwnd, hdc)

	pfd: windows.PIXELFORMATDESCRIPTOR = {
		nSize        = size_of(windows.PIXELFORMATDESCRIPTOR),
		nVersion     = 1,
		dwFlags      = windows.PFD_DRAW_TO_WINDOW | windows.PFD_SUPPORT_OPENGL | windows.PFD_DOUBLEBUFFER,
		iPixelType   = windows.PFD_TYPE_RGBA,
		cColorBits   = 32,
		cDepthBits   = 24,
		cStencilBits = 8,
		iLayerType   = windows.PFD_MAIN_PLANE,
	}
	pf := windows.ChoosePixelFormat(hdc, &pfd)
	if pf == 0 {
		assert(false, "ChoosePixelFormat(): failed")
		return false
	}
	if windows.DescribePixelFormat(hdc, pf, size_of(pfd), &pfd) == 0 {
		assert(false, "DescribePixelFormat(): failed")
		return false
	}
	if !windows.SetPixelFormat(hdc, pf, &pfd) {
		assert(false, "SetPixelFormat(): failed")
		return false
	}

	hglrc := windows.wglCreateContext(hdc)
	if hglrc == nil {
		assert(false, "wglCreateContext(): failed")
		return false
	}
	if !windows.wglMakeCurrent(hdc, hglrc) {
		assert(false, "wglMakeCurrent(): failed")
		return false
	}
	defer {
		windows.wglMakeCurrent(nil, nil)
		windows.wglDeleteContext(hglrc)
	}

	windows.gl_set_proc_address(&windows.wglCreateContextAttribsARB, "wglCreateContextAttribsARB")
	windows.gl_set_proc_address(&windows.wglChoosePixelFormatARB, "wglChoosePixelFormatARB")
	windows.gl_set_proc_address(&windows.wglSwapIntervalEXT, "wglSwapIntervalEXT")
	windows.gl_set_proc_address(&windows.wglGetExtensionsStringARB, "wglGetExtensionsStringARB")

	return true
}
