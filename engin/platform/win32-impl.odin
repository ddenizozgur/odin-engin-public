#+build windows
package platform

import "base:runtime"
import "core:sys/windows"

//
// General
//
@(private)
_set_console_utf8 :: proc() {
	windows.SetConsoleOutputCP(.UTF8)
	windows.SetConsoleCP(.UTF8)
}

@(private)
_graphical_error :: proc(title, msg: string) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	title16 := windows.utf8_to_wstring(title, context.temp_allocator)
	msg16 := windows.utf8_to_wstring(msg, context.temp_allocator)

	windows.MessageBoxW(nil, msg16, title16, windows.MB_OK | windows.MB_ICONERROR)
}

/*
@(private)
_caret_blink_time :: proc() -> f32 {return cast(f32)GetCaretBlinkTime() / 1000.}
@(private)
_double_click_time :: proc() -> f32 {return cast(f32)GetDoubleClickTime() / 1000.}
*/

//
// Window
//
@(private)
_get_dpi_scale :: proc() -> f32 {
	dpi := windows.GetDpiForWindow(_hwnd)
	return cast(f32)dpi / 96.
}

@(private)
_get_client_size :: proc() -> [2]i32 {
	res: [2]i32
	r: windows.RECT
	windows.GetClientRect(_hwnd, &r)
	res.x = r.right - r.left
	res.y = r.bottom - r.top
	return res
}

@(private)
_get_mouse_pos :: proc() -> [2]i32 {
	// TODO: check for focused or not ???
	// impl dpi awareness
	v: [2]i32
	p: windows.POINT
	if (windows.GetCursorPos(&p)) {
		windows.ScreenToClient(_hwnd, &p)
		v.x = p.x
		v.y = p.y
	}
	return v
}

@(private)
_window_set_title :: proc(title: string) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	title16 := windows.utf8_to_wstring(title, context.temp_allocator)
	windows.SetWindowTextW(_hwnd, title16)
}

@(private)
_window_set_focus :: proc() {
	windows.SetForegroundWindow(_hwnd)
	windows.SetFocus(_hwnd)
}

// TODO: check??
@(private)
_window_minimize :: proc() {windows.ShowWindow(_hwnd, windows.SW_MINIMIZE)}
@(private)
_window_maximize :: proc() {windows.ShowWindow(_hwnd, windows.SW_MAXIMIZE)}
@(private)
_window_restore :: proc() {windows.ShowWindow(_hwnd, windows.SW_RESTORE)}

@(private)
_window_is_focused :: proc() -> bool {
	active := windows.GetActiveWindow()
	return active == _hwnd
}

@(private)
_window_is_fullscreen :: proc() -> bool {
	style := windows.GetWindowLongW(_hwnd, windows.GWL_STYLE)
	return (cast(u32)style & windows.WS_OVERLAPPEDWINDOW) == 0
}

@(private)
_window_init :: proc(title: string, size: [2]int, style := Window_Style.Windowed) -> bool {
	// expects user to pass client size

	if (_hwnd != nil) {
		assert(false, "window already initialized")
		return false
	}

	// startup_info : windows.STARTUPINFOW
	// windows.GetStartupInfoW(&startup_info)

	hinst := cast(windows.HINSTANCE)windows.GetModuleHandleW(nil)
	hicon := windows.LoadIconW(hinst, cast(windows.LPCWSTR)windows.MAKEINTRESOURCEW(2)) // RESOURCE_ID_FIRST_ICON
	// if (!hIcon) {
	//     exe_path: [MAX_PATH]u16;
	//     GetModuleFileNameW(null, exe_path.data, MAX_PATH);
	//     icon = ExtractIconW(hInstance, exe_path.data, 0); // 0 means first icon.
	// }

	wnd_class: windows.WNDCLASSW = {
		lpfnWndProc   = _window_proc,
		style         = windows.CS_VREDRAW | windows.CS_HREDRAW | windows.CS_OWNDC,
		hInstance     = hinst,
		hIcon         = hicon,
		hCursor       = windows.LoadCursorA(nil, windows.IDC_ARROW),
		hbrBackground = cast(windows.HBRUSH)windows.GetStockObject(windows.WHITE_BRUSH), // cast(HBRUSH)(COLOR_WINDOW + 1);DKGRAY_BRUSH
		lpszClassName = _WNDCLASS_NAME,
	}
	if windows.RegisterClassW(&wnd_class) == 0 {
		assert(false, "RegisterClassW(): failed") // TODO: maybe GetLastError()
		return false
	}

	// float doubleClickTime = GetDoubleClickTime() / static_cast<float>(Thousand(1));
	// float caretBlinkTime  = GetCaretBlinkTime() / static_cast<float>(Thousand(1));

	// TODO: check https://stackoverflow.com/q/63096226 and here: https://stackoverflow.com/q/53000291
	// WS_EX_NOREDIRECTIONBITMAP flag here is needed to fix ugly bug with Windows 10
	// when window is resized and DXGI swap chain uses FLIP presentation model
	// !!! just for directx11 !!! dont use it for opengl vulkan !!!


	dw_style: windows.DWORD // | windows.WS_CLIPCHILDREN | windows.WS_CLIPSIBLINGS
	ex_style := windows.WS_EX_APPWINDOW

	xpos := windows.CW_USEDEFAULT
	ypos := windows.CW_USEDEFAULT
	window_rect: windows.RECT = {
		right  = cast(i32)size.x,
		bottom = cast(i32)size.y,
	}

	switch style {
	case .Windowed:
		dw_style = windows.WS_OVERLAPPEDWINDOW
		windows.AdjustWindowRectEx(&window_rect, dw_style, false, ex_style)
	case .FullScreen:
		dw_style = windows.WS_VISIBLE | windows.WS_POPUP

		// since window isn't created yet, we use the primary monitor
		hmonitor := windows.MonitorFromWindow(nil, .MONITOR_DEFAULTTOPRIMARY)
		mi: windows.MONITORINFO = {
			cbSize = size_of(windows.MONITORINFO),
		}
		if windows.GetMonitorInfoW(hmonitor, &mi) {
			window_rect = mi.rcMonitor
			xpos = mi.rcMonitor.left
			ypos = mi.rcMonitor.top
			// SetWindowPos(res.hwnd, HWND_TOPMOST, xpos, ypos, width, height,
			//     SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
		}
	// Secondary = windows.WS_OVERLAPPED | windows.WS_CAPTION | windows.WS_SYSMENU | windows.WS_THICKFRAME,
	}

	{
		window_w := window_rect.right - window_rect.left
		window_h := window_rect.bottom - window_rect.top

		runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
		title16 := windows.utf8_to_wstring(title, context.temp_allocator)

		_hwnd = windows.CreateWindowExW(
			ex_style,
			_WNDCLASS_NAME,
			title16,
			dw_style,
			xpos,
			ypos,
			window_w,
			window_h,
			nil,
			nil,
			hinst,
			nil,
		)
		// DragAcceptFiles(hwnd, TRUE);
	}

	if (_hwnd == nil) {
		assert(false, "CreateWindowExW(): failed")
		return false
	}
	windows.UpdateWindow(_hwnd)
	// ShowCursor(style == .WINDOWED);
	windows.ShowWindow(_hwnd, windows.SW_SHOW)

	_hdc = windows.GetDC(_hwnd)

	return true
}

@(private)
_window_free :: proc() {
	if _hwnd == nil do return

	hinst := cast(windows.HINSTANCE)windows.GetModuleHandleW(nil)
	windows.UnregisterClassW(_WNDCLASS_NAME, hinst)

	windows.ReleaseDC(_hwnd, _hdc)
	windows.DestroyWindow(_hwnd)
}

//
// Privates
//
@(private = "file")
_WNDCLASS_NAME :: "wnd-class-name"

@(private)
_hwnd: windows.HWND
@(private)
_hdc: windows.HDC

@(private)
_display_settings: windows.DEVMODEW
@(private = "file", init)
_display_settings_init :: proc "contextless" () {
	windows.EnumDisplaySettingsW(nil, windows.ENUM_CURRENT_SETTINGS, &_display_settings)
}

/*
foreign import user32 "system:User32.lib"
@(default_calling_convention = "system")
foreign user32 {
	GetCaretBlinkTime :: proc() -> windows.UINT ---
	GetDoubleClickTime :: proc() -> windows.UINT ---
}
*/
