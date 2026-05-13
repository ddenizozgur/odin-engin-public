#+build windows
package platform

import "base:runtime"
import "core:sys/windows"
import "core:unicode"
import "core:unicode/utf16"

// TODO: blocking version
@(private)
_poll_events_this_frame :: proc() {
	msg: windows.MSG
	for windows.PeekMessageW(&msg, nil, 0, 0, windows.PM_REMOVE) {
		windows.TranslateMessage(&msg)
		windows.DispatchMessageW(&msg)
	}
}

//
// Privates
//
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
		append(&events_this_frame, Event_Window_Close{})

	case windows.WM_SIZE:
		switch wparam {
		case windows.SIZE_MINIMIZED:
			append(&events_this_frame, Event_Window_Minimize{})
		case windows.SIZE_MAXIMIZED:
			append(&events_this_frame, Event_Window_Maximize{})
		case windows.SIZE_RESTORED:
			append(&events_this_frame, Event_Window_Restore{})
		}

	case windows.WM_SETFOCUS:
		append(&events_this_frame, Event_Window_Focus{})
	case windows.WM_KILLFOCUS:
		append(&events_this_frame, Event_Window_UnFocus{})
	// TODO: ??? windows.ReleaseCapture()

	case windows.WM_INPUT: // TODO: rawinput
	case windows.WM_PAINT:
		ps: windows.PAINTSTRUCT
		hdc := windows.BeginPaint(hwnd, &ps)
		// do NOTHING here...
		windows.EndPaint(hwnd, &ps)
	// DwmFlush();

	case windows.WM_LBUTTONUP:
		windows.ReleaseCapture()

		btn := Mouse_Button.Left
		_mouse_btns_this_frame[btn] = false

		append(&events_this_frame, Event_Mouse_Button{state = .Released, button = btn})
	case windows.WM_LBUTTONDOWN:
		windows.SetCapture(hwnd)

		btn := Mouse_Button.Left
		_mouse_btns_this_frame[btn] = true

		append(&events_this_frame, Event_Mouse_Button{state = .Pressed, button = btn})
	case windows.WM_MBUTTONUP:
		windows.ReleaseCapture()

		btn := Mouse_Button.Middle
		_mouse_btns_this_frame[btn] = false

		append(&events_this_frame, Event_Mouse_Button{state = .Released, button = btn})
	case windows.WM_MBUTTONDOWN:
		windows.SetCapture(hwnd)

		btn := Mouse_Button.Middle
		_mouse_btns_this_frame[btn] = true

		append(&events_this_frame, Event_Mouse_Button{state = .Pressed, button = btn})
	case windows.WM_RBUTTONUP:
		windows.ReleaseCapture()

		btn := Mouse_Button.Right
		_mouse_btns_this_frame[btn] = false

		append(&events_this_frame, Event_Mouse_Button{state = .Released, button = btn})
	case windows.WM_RBUTTONDOWN:
		windows.SetCapture(hwnd)

		btn := Mouse_Button.Right
		_mouse_btns_this_frame[btn] = true

		append(&events_this_frame, Event_Mouse_Button{state = .Pressed, button = btn})
	case windows.WM_XBUTTONUP:
		windows.ReleaseCapture()
		// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-xbuttondown
		// Unlike the WM_LBUTTONDOWN, WM_MBUTTONDOWN, and WM_RBUTTONDOWN messages,
		// an application should return TRUE from this message if it processes it
		defer result = 1
		btn: Mouse_Button = windows.HIWORD(wparam) == 1 ? .XButton1 : .XButton2
		_mouse_btns_this_frame[btn] = false

		append(&events_this_frame, Event_Mouse_Button{state = .Released, button = btn})
	case windows.WM_XBUTTONDOWN:
		windows.SetCapture(hwnd)

		defer result = 1
		btn: Mouse_Button = windows.HIWORD(wparam) == 1 ? .XButton1 : .XButton2
		_mouse_btns_this_frame[btn] = true

		append(&events_this_frame, Event_Mouse_Button{state = .Pressed, button = btn})

	case windows.WM_MOUSEMOVE:
		x := windows.GET_X_LPARAM(lparam)
		y := windows.GET_Y_LPARAM(lparam)
		append(&events_this_frame, Event_Mouse_Move{x, y})

	case windows.WM_MOUSEWHEEL:
		vert_scroll := cast(f32)windows.GET_WHEEL_DELTA_WPARAM(wparam) / _MOUSE_SCROLL_NORMVAL // TODO: check sign
		append(&events_this_frame, Event_Mouse_Scroll{0., vert_scroll})
	case windows.WM_MOUSEHWHEEL:
		horz_scroll := cast(f32)windows.GET_WHEEL_DELTA_WPARAM(wparam) / _MOUSE_SCROLL_NORMVAL // TODO: check sign
		append(&events_this_frame, Event_Mouse_Scroll{horz_scroll, 0.})

	case windows.WM_SYSKEYUP, windows.WM_SYSKEYDOWN:
		if wparam == windows.VK_F4 {
			// return windows.DefWindowProcW(hwnd, msg, wparam, lparam)
			append(&events_this_frame, Event_Window_Close{})
			break
		}
		if wparam != windows.VK_MENU && (wparam < windows.VK_F1 || wparam > windows.VK_F24) {
			result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
		}
		fallthrough
	case windows.WM_KEYUP, windows.WM_KEYDOWN:
		was_down := (lparam & (1 << 30)) != 0
		is_down := (lparam & (1 << 31)) == 0

		keycode := _keycode_from_vkey(cast(u32)wparam)
		keymod := _get_keymod()

		// do we want this???
		#partial switch keycode {
		case .Ctrl:
			keymod -= {.Ctrl}
		case .Shift:
			keymod -= {.Shift}
		case .Alt:
			keymod -= {.Alt}
		case .Super:
			keymod -= {.Super}
		case .CapsLock:
			keymod -= {.CapsLock}
		case .NumLock:
			keymod -= {.NumLock}
		}

		append(
			&events_this_frame,
			Event_Key {
				code  = keycode,
				mod   = keymod,
				state = is_down ? .Pressed : .Released,
				// is_repeat = is_down && was_down,
				// repeat_count = is_down ? lparam & 0xffff : 0,
			},
		)

	case windows.WM_SYSCHAR:
		result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
	case windows.WM_CHAR:
		@(static) high_surrogate: rune
		w := cast(rune)wparam

		codepoint: rune
		if utf16.is_surrogate(w) {
			if high_surrogate == 0 {
				high_surrogate = w
				break
			} else {
				codepoint = utf16.decode_surrogate_pair(high_surrogate, w)
				high_surrogate = 0

				// broken/invalid
				if codepoint == unicode.REPLACEMENT_CHAR {
					break
				}
			}
		} else {
			codepoint = w
			high_surrogate = 0
		}

		// Filter out ctrl chars
		if unicode.is_print(codepoint) {
			append(&events_this_frame, cast(Event_Text)codepoint)
		}

	case windows.WM_ERASEBKGND:
		result = 1 // we fill out the client area so no need to erase the background

	case:
		result = windows.DefWindowProcW(hwnd, msg, wparam, lparam)
	}

	return result
}

// _get_mouse_source :: proc() -> Mouse_Source {
// 	signature := windows.GetMessageExtraInfo() & 0xFFFFFF80
// 	if signature == 0xFF515700 do return .Pen
// 	if signature == 0xFF515780 do return .TouchScreen
// 	return .Mouse
// }

// const bool swapped = (TRUE == GetSystemMetrics(SM_SWAPBUTTON));
// check for swapped mouse buttons???

@(private = "file")
_MOUSE_SCROLL_NORMVAL :: f32(120)

@(private = "file")
_get_keymod :: proc() -> (mod: Key_Modifiers) {
	if cast(u16)windows.GetKeyState(windows.VK_SHIFT) & 0x8000 != 0 do mod |= {.Shift}
	if cast(u16)windows.GetKeyState(windows.VK_CONTROL) & 0x8000 != 0 do mod |= {.Ctrl}
	if cast(u16)windows.GetKeyState(windows.VK_MENU) & 0x8000 != 0 do mod |= {.Alt}
	if cast(u16)windows.GetKeyState(windows.VK_CAPITAL) & 1 != 0 do mod |= {.CapsLock}
	if cast(u16)windows.GetKeyState(windows.VK_NUMLOCK) & 1 != 0 do mod |= {.NumLock}

	lwin := cast(u16)windows.GetKeyState(windows.VK_LWIN) & 0x8000 != 0
	rwin := cast(u16)windows.GetKeyState(windows.VK_RWIN) & 0x8000 != 0
	if lwin || rwin do mod |= {.Super}

	return mod
}

@(private = "file")
_keycode_from_vkey :: proc(vkey: u32) -> Key_Code {
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
		return ._0 + cast(Key_Code)(vkey - '0')
	case windows.VK_NUMPAD0 ..= windows.VK_NUMPAD9:
		return .Num0 + cast(Key_Code)(vkey - windows.VK_NUMPAD0)
	case windows.VK_F1 ..= windows.VK_F24:
		return .F1 + cast(Key_Code)(vkey - windows.VK_F1)
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
	case windows.VK_LWIN, windows.VK_RWIN:
		return .Super
	// case windows.VK_SCROLL:
	// 	return .ScrollLock
	case windows.VK_APPS:
		return .Menu
	case windows.VK_CONTROL, windows.VK_LCONTROL, windows.VK_RCONTROL:
		return .Ctrl
	case windows.VK_SHIFT, windows.VK_LSHIFT, windows.VK_RSHIFT:
		return .Shift
	case windows.VK_MENU, windows.VK_LMENU, windows.VK_RMENU:
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
	// case 0xDF ..= 0xFC:
	// 	// TODO: check
	// 	return .Ex0 + cast(Key_Code)(vkey - 0xDF)
	}
	return .Null
}

@(private = "file")
_vkey_from_keycode :: proc(keycode: Key_Code) -> u32 {
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
	case .Super:
		return windows.VK_LWIN
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
	// case .ScrollLock:
	// 	return windows.VK_SCROLL
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
	// case .Ex0 ..= .Ex29:
	// 	return cast(u32)0xDF + cast(u32)(keycode - .Ex0)
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
