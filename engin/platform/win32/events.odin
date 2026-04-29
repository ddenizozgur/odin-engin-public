#+build windows
package win32

import "../../platform"
import "base:runtime"
import "core:sys/windows"

// TODO: blocking version
poll_events_this_frame :: proc() {
	clear(&platform.events_this_frame)

	msg: windows.MSG
	for windows.PeekMessageW(&msg, nil, 0, 0, windows.PM_REMOVE) {
		windows.TranslateMessage(&msg)
		windows.DispatchMessageW(&msg)
	}
}

// get_mouse_source :: proc() -> platform.Mouse_Source {
// 	signature := windows.GetMessageExtraInfo() & 0xFFFFFF80
// 	if signature == 0xFF515700 do return .Pen
// 	if signature == 0xFF515780 do return .TouchScreen
// 	return .Mouse
// }

/*
*
*/

// const bool swapped = (TRUE == GetSystemMetrics(SM_SWAPBUTTON));
// TODO: check for swapped mouse buttons???
@(private = "file")
_MOUSE_SCROLL_NORMVAL :: cast(f32)120

@(private)
_window_proc :: proc "system" (
	hwnd: windows.HWND,
	msg: windows.UINT,
	wparam: windows.WPARAM,
	lparam: windows.LPARAM,
) -> windows.LRESULT {
	context = runtime.default_context()

	result: windows.LRESULT = 0

	switch msg {
	// case windows.WM_DESTROY:
	case windows.WM_CLOSE:
		append(&platform.events_this_frame, platform.Event_Window_Close{})

	case windows.WM_SIZE:
		switch wparam {
		case windows.SIZE_MINIMIZED:
			append(&platform.events_this_frame, platform.Event_Window_Minimize{})
		case windows.SIZE_MAXIMIZED:
			append(&platform.events_this_frame, platform.Event_Window_Maximize{})
		}

	case windows.WM_SETFOCUS:
		append(&platform.events_this_frame, platform.Event_Window_Focus{})
	case windows.WM_KILLFOCUS:
		append(&platform.events_this_frame, platform.Event_Window_UnFocus{})

	case windows.WM_INPUT: // TODO: rawinput
	case windows.WM_PAINT:
		ps: windows.PAINTSTRUCT
		hdc := windows.BeginPaint(hwnd, &ps)
		// do NOTHING here...
		windows.EndPaint(hwnd, &ps)
	// DwmFlush();

	case windows.WM_LBUTTONUP:
		windows.ReleaseCapture()
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Release, button = .Left},
		)
	case windows.WM_LBUTTONDOWN:
		windows.SetCapture(hwnd)
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Press, button = .Left},
		)
	case windows.WM_MBUTTONUP:
		windows.ReleaseCapture()
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Release, button = .Middle},
		)
	case windows.WM_MBUTTONDOWN:
		windows.SetCapture(hwnd)
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Press, button = .Middle},
		)
	case windows.WM_RBUTTONUP:
		windows.ReleaseCapture()
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Release, button = .Right},
		)
	case windows.WM_RBUTTONDOWN:
		windows.SetCapture(hwnd)
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button{state = .Press, button = .Right},
		)
	case windows.WM_XBUTTONUP:
		windows.ReleaseCapture()
		// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-xbuttondown
		// Unlike the WM_LBUTTONDOWN, WM_MBUTTONDOWN, and WM_RBUTTONDOWN messages,
		// an application should return TRUE from this message if it processes it
		result = 1
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button {
				state = .Release,
				button = windows.HIWORD(wparam) == 1 ? .XButton1 : .XButton2,
			},
		)
	case windows.WM_XBUTTONDOWN:
		windows.SetCapture(hwnd)
		result = 1
		append(
			&platform.events_this_frame,
			platform.Event_Mouse_Button {
				state = .Press,
				button = windows.HIWORD(wparam) == 1 ? .XButton1 : .XButton2,
			},
		)

	case windows.WM_MOUSEMOVE:
		x := windows.GET_X_LPARAM(lparam)
		y := windows.GET_Y_LPARAM(lparam)
		append(&platform.events_this_frame, platform.Event_Mouse_Move{x, y})

	case windows.WM_MOUSEWHEEL:
		norm_delta_vert := cast(f32)windows.GET_WHEEL_DELTA_WPARAM(wparam) / _MOUSE_SCROLL_NORMVAL // TODO: check sign
		append(&platform.events_this_frame, platform.Event_Mouse_Scroll{0., norm_delta_vert})
	case windows.WM_MOUSEHWHEEL:
		norm_delta_horz := cast(f32)windows.GET_WHEEL_DELTA_WPARAM(wparam) / _MOUSE_SCROLL_NORMVAL // TODO: check sign
		append(&platform.events_this_frame, platform.Event_Mouse_Scroll{norm_delta_horz, 0.})

	case windows.WM_SYSKEYUP, windows.WM_SYSKEYDOWN:
		if wparam == windows.VK_F4 {
			return windows.DefWindowProcW(hwnd, msg, wparam, lparam)
		}
		if wparam != windows.VK_MENU && (wparam < windows.VK_F1 || wparam > windows.VK_F24) {
			result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
		}
		fallthrough
	case windows.WM_KEYUP, windows.WM_KEYDOWN:
		was_down := (lparam & (1 << 30)) != 0
		is_down := (lparam & (1 << 31)) == 0
		append(
			&platform.events_this_frame,
			platform.Event_Key {
				code = _keycode_from_vkey(cast(u32)wparam),
				mode = _get_keymode(),
				state = is_down ? .Press : .Release,
				is_repeat = was_down && is_down,
				repeat_count = lparam & 0xffff,
			},
		)

	case windows.WM_SYSCHAR:
		result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
	// TODO: fallthrough???
	case windows.WM_CHAR:
		// TODO: check
		HIGH_SURROGATE_START :: 0xd800
		HIGH_SURROGATE_END :: 0xdbff
		LOW_SURROGATE_START :: 0xdc00
		LOW_SURROGATE_END :: 0xdfff

		@(static) high_surrogate: u16 = 0
		w := cast(u16)wparam

		if w >= HIGH_SURROGATE_START && w <= HIGH_SURROGATE_END {
			high_surrogate = w
		} else {
			codepoint: rune

			if w >= LOW_SURROGATE_START && w <= LOW_SURROGATE_END {
				if high_surrogate != 0 {
					codepoint = (cast(rune)high_surrogate - HIGH_SURROGATE_START) << 10
					codepoint += (cast(rune)w - LOW_SURROGATE_START)
					codepoint += 0x10000
					high_surrogate = 0 // clear state after successful pair
				} else {
					// invalid sequence
					break
				}
			} else {
				codepoint = cast(rune)w
				high_surrogate = 0 // clear state in case of a broken sequence
			}

			// control characters
			if codepoint > 31 && codepoint != 127 {
				append(&platform.events_this_frame, cast(platform.Event_Text)codepoint)
			}
		}

	case windows.WM_ERASEBKGND:
		result = 1 // we fill out the client area so no need to erase the background

	case:
		result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
	}

	return result
}

@(private = "file")
_get_keymode :: proc() -> platform.Key_Mode_Flags {
	keymode: platform.Key_Mode_Flags

	if cast(u16)windows.GetKeyState(windows.VK_SHIFT) & 0x8000 != 0 do keymode |= {.Shift}
	if cast(u16)windows.GetKeyState(windows.VK_CONTROL) & 0x8000 != 0 do keymode |= {.Ctrl}
	if cast(u16)windows.GetKeyState(windows.VK_MENU) & 0x8000 != 0 do keymode |= {.Alt}
	if cast(u16)windows.GetKeyState(windows.VK_CAPITAL) & 1 != 0 do keymode |= {.CapsLock}
	if cast(u16)windows.GetKeyState(windows.VK_NUMLOCK) & 1 != 0 do keymode |= {.NumLock}

	lwin := cast(u16)windows.GetKeyState(windows.VK_LWIN) & 0x8000 != 0
	rwin := cast(u16)windows.GetKeyState(windows.VK_RWIN) & 0x8000 != 0
	if lwin || rwin do keymode |= {.Super}

	return keymode
}

@(private = "file")
_keycode_from_vkey :: proc(vkey: u32) -> platform.Key_Code {
	switch vkey {
	case 'A':
		return .A
	case 'B':
		return .B
	case 'C':
		return .C
	case 'D':
		return .D
	case 'E':
		return .E
	case 'F':
		return .F
	case 'G':
		return .G
	case 'H':
		return .H
	case 'I':
		return .I
	case 'J':
		return .J
	case 'K':
		return .K
	case 'L':
		return .L
	case 'M':
		return .M
	case 'N':
		return .N
	case 'O':
		return .O
	case 'P':
		return .P
	case 'Q':
		return .Q
	case 'R':
		return .R
	case 'S':
		return .S
	case 'T':
		return .T
	case 'U':
		return .U
	case 'V':
		return .V
	case 'W':
		return .W
	case 'X':
		return .X
	case 'Y':
		return .Y
	case 'Z':
		return .Z
	case '0' ..= '9':
		return ._0 + cast(platform.Key_Code)(vkey - '0')
	case windows.VK_NUMPAD0 ..= windows.VK_NUMPAD9:
		return .Num0 + cast(platform.Key_Code)(vkey - windows.VK_NUMPAD0)
	case windows.VK_F1 ..= windows.VK_F24:
		return .F1 + cast(platform.Key_Code)(vkey - windows.VK_F1)
	case windows.VK_SPACE:
		return .Space
	case windows.VK_OEM_3:
		return .Backtick
	case windows.VK_OEM_MINUS:
		return .Minus
	case windows.VK_OEM_PLUS:
		return .Equal
	case windows.VK_OEM_4:
		return .LeftBracket
	case windows.VK_OEM_6:
		return .RightBracket
	case windows.VK_OEM_1:
		return .Semicolon
	case windows.VK_OEM_7:
		return .Quote
	case windows.VK_OEM_COMMA:
		return .Comma
	case windows.VK_OEM_PERIOD:
		return .Period
	case windows.VK_OEM_2:
		return .Slash
	case windows.VK_OEM_5:
		return .BackSlash
	case windows.VK_TAB:
		return .Tab
	case windows.VK_PAUSE:
		return .Pause
	case windows.VK_ESCAPE:
		return .Esc
	case windows.VK_UP:
		return .Up
	case windows.VK_LEFT:
		return .Left
	case windows.VK_DOWN:
		return .Down
	case windows.VK_RIGHT:
		return .Right
	case windows.VK_BACK:
		return .Backspace
	case windows.VK_RETURN:
		return .Return
	case windows.VK_DELETE:
		return .Delete
	case windows.VK_INSERT:
		return .Insert
	case windows.VK_PRIOR:
		return .PageUp
	case windows.VK_NEXT:
		return .PageDown
	case windows.VK_HOME:
		return .Home
	case windows.VK_END:
		return .End
	case windows.VK_CAPITAL:
		return .CapsLock
	case windows.VK_NUMLOCK:
		return .NumLock
	case windows.VK_SCROLL:
		return .ScrollLock
	case windows.VK_APPS:
		return .Menu
	case windows.VK_CONTROL:
		return .Ctrl
	case windows.VK_LCONTROL:
		return .Ctrl
	case windows.VK_RCONTROL:
		return .Ctrl
	case windows.VK_SHIFT:
		return .Shift
	case windows.VK_LSHIFT:
		return .Shift
	case windows.VK_RSHIFT:
		return .Shift
	case windows.VK_MENU:
		return .Alt
	case windows.VK_LMENU:
		return .Alt
	case windows.VK_RMENU:
		return .Alt
	case windows.VK_DIVIDE:
		return .NumSlash
	case windows.VK_MULTIPLY:
		return .NumStar
	case windows.VK_SUBTRACT:
		return .NumMinus
	case windows.VK_ADD:
		return .NumPlus
	case windows.VK_DECIMAL:
		return .NumPeriod
	// case 0xDF ..< 0xFF:
	case 0xDF ..= 0xFC:
		// TODO: check
		return .Ex0 + cast(platform.Key_Code)(vkey - 0xDF)
	}
	return .Null
}

@(private = "file")
_vkey_from_keycode :: proc(keycode: platform.Key_Code) -> u32 {
	switch keycode {
	case .Null:
		return 0
	case .Esc:
		return windows.VK_ESCAPE
	case .F1 ..= .F24:
		return cast(u32)windows.VK_F1 + cast(u32)(keycode - .F1)
	case .Backtick:
		return windows.VK_OEM_3
	case ._0 ..= ._9:
		return cast(u32)'0' + cast(u32)(keycode - ._0)
	case .Minus:
		return windows.VK_OEM_MINUS
	case .Equal:
		return windows.VK_OEM_PLUS
	case .Backspace:
		return windows.VK_BACK
	case .Tab:
		return windows.VK_TAB
	case .Q:
		return 'Q'
	case .W:
		return 'W'
	case .E:
		return 'E'
	case .R:
		return 'R'
	case .T:
		return 'T'
	case .Y:
		return 'Y'
	case .U:
		return 'U'
	case .I:
		return 'I'
	case .O:
		return 'O'
	case .P:
		return 'P'
	case .LeftBracket:
		return windows.VK_OEM_4
	case .RightBracket:
		return windows.VK_OEM_6
	case .BackSlash:
		return windows.VK_OEM_5
	case .CapsLock:
		return windows.VK_CAPITAL
	case .A:
		return 'A'
	case .S:
		return 'S'
	case .D:
		return 'D'
	case .F:
		return 'F'
	case .G:
		return 'G'
	case .H:
		return 'H'
	case .J:
		return 'J'
	case .K:
		return 'K'
	case .L:
		return 'L'
	case .Semicolon:
		return windows.VK_OEM_1
	case .Quote:
		return windows.VK_OEM_7
	case .Return:
		return windows.VK_RETURN
	case .Shift:
		return windows.VK_SHIFT
	case .Z:
		return 'Z'
	case .X:
		return 'X'
	case .C:
		return 'C'
	case .V:
		return 'V'
	case .B:
		return 'B'
	case .N:
		return 'N'
	case .M:
		return 'M'
	case .Comma:
		return windows.VK_OEM_COMMA
	case .Period:
		return windows.VK_OEM_PERIOD
	case .Slash:
		return windows.VK_OEM_2
	case .Ctrl:
		return windows.VK_CONTROL
	case .Alt:
		return windows.VK_MENU
	case .Space:
		return windows.VK_SPACE
	case .Menu:
		return windows.VK_APPS
	case .ScrollLock:
		return windows.VK_SCROLL
	case .Pause:
		return windows.VK_PAUSE
	case .Insert:
		return windows.VK_INSERT
	case .Home:
		return windows.VK_HOME
	case .PageUp:
		return windows.VK_PRIOR
	case .Delete:
		return windows.VK_DELETE
	case .End:
		return windows.VK_END
	case .PageDown:
		return windows.VK_NEXT
	case .Up:
		return windows.VK_UP
	case .Left:
		return windows.VK_LEFT
	case .Down:
		return windows.VK_DOWN
	case .Right:
		return windows.VK_RIGHT
	case .Ex0 ..= .Ex29:
		return cast(u32)0xDF + cast(u32)(keycode - .Ex0)
	case .NumLock:
		return windows.VK_NUMLOCK
	case .NumSlash:
		return windows.VK_DIVIDE
	case .NumStar:
		return windows.VK_MULTIPLY
	case .NumMinus:
		return windows.VK_SUBTRACT
	case .NumPlus:
		return windows.VK_ADD
	case .NumPeriod:
		return windows.VK_DECIMAL
	case .Num0 ..= .Num9:
		return cast(u32)windows.VK_NUMPAD0 + cast(u32)(keycode - .Num0)
	}
	return 0
}
