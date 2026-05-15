#+build linux
//#+build linux, freebsd, openbsd, netbsd ????
package platform

import "core:fmt"
import "core:mem"
import "core:unicode"
import "vendor:x11/xlib"

@(private)
_poll_events_this_frame :: proc() {
	for xlib.Pending(_display) > 0 {
		xevnt: xlib.XEvent
		xlib.NextEvent(_display, &xevnt)

		if xlib.FilterEvent(&xevnt, xlib.None) {
			continue
		}

		#partial switch xevnt.type {
		case .KeyPress, .KeyRelease:
			is_down := xevnt.type == .KeyPress
			keysym: xlib.KeySym
			text_buf: [256]byte

			if is_down {
				status: xlib.LookupStringStatus

				// This only checks keydown events
				written := xlib.Xutf8LookupString(
					_xic,
					&xevnt.xkey,
					cast(cstring)&text_buf[0],
					len(text_buf),
					&keysym,
					&status,
				)

				if written > 0 {
					text_str := string(text_buf[:written])
					for codepoint in text_str {
						if unicode.is_graphic(codepoint) {
							append(&events_this_frame, cast(Event_Text)codepoint)
						}
					}
				}
			} else {
				// XLookupKeysym() cant handle modifiers
				status: xlib.XComposeStatus
				xlib.LookupString(&xevnt.xkey, &text_buf[0], len(text_buf), &keysym, &status)
			}

			keycode := _keycode_from_keysym(keysym)
			keymod := _get_keymod(xevnt.xkey.state)

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
				Event_Key{code = keycode, mod = keymod, state = is_down ? .Pressed : .Released},
			)

		case .ButtonPress, .ButtonRelease:
			xbtn := cast(u32)xevnt.xbutton.button
			is_down := xevnt.type == .ButtonPress

			// Scroll event
			if xbtn >= 4 && xbtn <= 7 {
				// X11 sends both for press and release
				if is_down {
					vert_scroll := f32(0)
					horz_scroll := f32(0)

					switch xbtn {
					case 4:
						vert_scroll = +1.0 // Up??
					case 5:
						vert_scroll = -1.0
					case 6:
						horz_scroll = -1.0 // Left??
					case 7:
						horz_scroll = +1.0
					}

					append(&events_this_frame, Event_Mouse_Scroll{horz_scroll, vert_scroll})
				}
			} else {
				btn: Mouse_Button
				is_valid := true

				switch xbtn {
				case 1:
					btn = .Left
				case 2:
					btn = .Middle
				case 3:
					btn = .Right
				// TODO: check
				case 8:
					btn = .XButton1
				case 9:
					btn = .XButton2
				case:
					is_valid = false
				}

				if is_valid {
					_mouse_btns_this_frame[btn] = is_down

					append(
						&events_this_frame,
						Event_Mouse_Button{state = is_down ? .Pressed : .Released, button = btn},
					)
				}
			}

		case .MotionNotify:
			mouse_x := xevnt.xmotion.x
			mouse_y := xevnt.xmotion.y
			append(&events_this_frame, Event_Mouse_Move{mouse_x, mouse_y})

		// case .EnterNotify:
		// case .LeaveNotify:
		// case .Expose:

		case .FocusIn:
			append(&events_this_frame, Event_Window_Focus{})
		case .FocusOut:
			append(&events_this_frame, Event_Window_UnFocus{})

		/*
		case .UnmapNotify:
			// dont work ???
			append(&events_this_frame, Event_Window_Minimize{})
			fmt.println("minimize")
		case .MapNotify:
			append(&events_this_frame, Event_Window_Restore{})
			fmt.println("restore")
		*/

		case .PropertyNotify:
			@(static) prev_placement: enum {
				Restore,
				Minimize,
				Maximize,
			}

			atom := xevnt.xproperty.atom
			if atom == _atoms[.WM_STATE] {
				// Minimize, Restore
				act_type: xlib.Atom
				act_format: i32
				nitems: uint
				bytes_after: uint
				prop: rawptr

				status := xlib.GetWindowProperty(
					_display,
					xevnt.xproperty.window,
					_atoms[.WM_STATE],
					0, // Read offset
					2, // Read amount (2*size_of(u32))
					false, // delete
					xlib.AnyPropertyType, // req_type
					&act_type,
					&act_format,
					&nitems,
					&bytes_after,
					&prop,
				)

				if status == 0 && prop != nil {
					defer xlib.Free(prop)

					if nitems > 0 {
						state := (cast(^u32)prop)^

						switch state {
						case 1:
							if prev_placement != .Restore {
								append(&events_this_frame, Event_Window_Restore{})
								prev_placement = .Restore
							}
						case 3:
							if prev_placement != .Minimize { 	// Minimize seems not spammy but whatever
								append(&events_this_frame, Event_Window_Minimize{})
								prev_placement = .Minimize
							}
						}
					}
				}
			} else if atom == _atoms[._NET_WM_STATE] {
				// Maximize
				act_type: xlib.Atom
				act_format: i32
				nitems: uint
				bytes_after: uint
				prop: rawptr

				status := xlib.GetWindowProperty(
					_display,
					xevnt.xproperty.window,
					_atoms[._NET_WM_STATE],
					0,
					32, // Do we need to read that much ??
					false,
					xlib.XA_ATOM,
					&act_type,
					&act_format,
					&nitems,
					&bytes_after,
					&prop,
				)
				/*
				if bytes_after != 0 {
					if prop != nil {
						xlib.Free(prop)
					}

					status = xlib.GetWindowProperty(
						_display,
						xevnt.xproperty.window,
						_atoms[._NET_WM_STATE],
						0,
						64,
						false,
						xlib.XA_ATOM,
						&act_type,
						&act_format,
						&nitems,
						&bytes_after,
						&prop,
					)
				}
				*/

				if status == 0 && prop != nil {
					defer xlib.Free(prop)

					// _NET_WM_STATE returns an array of Atoms representing current states
					atoms := mem.slice_ptr(cast(^xlib.Atom)prop, cast(int)nitems)

					is_max_v := false
					is_max_h := false

					for atom in atoms {
						if atom == _atoms[._NET_WM_STATE_MAXIMIZED_VERT] do is_max_v = true
						if atom == _atoms[._NET_WM_STATE_MAXIMIZED_HORZ] do is_max_h = true
					}

					if is_max_v && is_max_h { 	// Also maximize is not spammy
						if prev_placement != .Maximize {
							append(&events_this_frame, Event_Window_Maximize{})
							prev_placement = .Maximize
						}
					} else {
						if prev_placement == .Maximize {	// Only fire if maximize ??
							append(&events_this_frame, Event_Window_Restore{})
							prev_placement = .Restore
						}
					}
				}
			}

		case .ConfigureNotify:
			@(static) client_w, client_h: i32

			new_w := xevnt.xconfigure.width
			new_h := xevnt.xconfigure.height

			if new_w != client_w || new_h != client_h {
				// not so spammy btw but just in case
				client_w, client_h = new_w, new_h
				// append(&events_this_frame, Event_Window_Resize{new_w, new_h})
			}

		case .ClientMessage:
			atom := cast(xlib.Atom)xevnt.xclient.data.l[0]
			if atom == _atoms[.WM_DELETE_WINDOW] {
				append(&events_this_frame, Event_Window_Close{})
			} else if atom == _atoms[._NET_WM_SYNC_REQUEST] {
				// smth
			}
		}
	}
}

//
// Privates
//
@(private = "file")
_get_keymod :: proc(mask: xlib.InputMask) -> (mod: Key_Modifiers) {
	if .ShiftMask in mask do mod += {.Shift}
	if .ControlMask in mask do mod += {.Ctrl}
	if .Mod1Mask in mask do mod += {.Alt}
	if .Mod4Mask in mask do mod += {.Super}
	if .LockMask in mask do mod += {.CapsLock}
	if .Mod2Mask in mask do mod += {.NumLock}

	return mod
}

@(private = "file")
_keycode_from_keysym :: proc(keysym: xlib.KeySym) -> Key_Code {
	#partial switch keysym {
	case .XK_A, .XK_a:
		return .A
	case .XK_B, .XK_b:
		return .B
	case .XK_C, .XK_c:
		return .C
	case .XK_D, .XK_d:
		return .D
	case .XK_E, .XK_e:
		return .E
	case .XK_F, .XK_f:
		return .F
	case .XK_G, .XK_g:
		return .G
	case .XK_H, .XK_h:
		return .H
	case .XK_I, .XK_i:
		return .I
	case .XK_J, .XK_j:
		return .J
	case .XK_K, .XK_k:
		return .K
	case .XK_L, .XK_l:
		return .L
	case .XK_M, .XK_m:
		return .M
	case .XK_N, .XK_n:
		return .N
	case .XK_O, .XK_o:
		return .O
	case .XK_P, .XK_p:
		return .P
	case .XK_Q, .XK_q:
		return .Q
	case .XK_R, .XK_r:
		return .R
	case .XK_S, .XK_s:
		return .S
	case .XK_T, .XK_t:
		return .T
	case .XK_U, .XK_u:
		return .U
	case .XK_V, .XK_v:
		return .V
	case .XK_W, .XK_w:
		return .W
	case .XK_X, .XK_x:
		return .X
	case .XK_Y, .XK_y:
		return .Y
	case .XK_Z, .XK_z:
		return .Z
	case .XK_0 ..= .XK_9:
		return ._0 + cast(Key_Code)(keysym - xlib.KeySym.XK_0)
	case .XK_KP_0 ..= .XK_KP_9:
		return .Num0 + cast(Key_Code)(keysym - xlib.KeySym.XK_KP_0)
	case .XK_F1 ..= .XK_F24:
		return .F1 + cast(Key_Code)(keysym - xlib.KeySym.XK_F1)
	case .XK_space:
		// 	fallthrough
		// case .XK_KP_Space: Check
		return .Space
	case .XK_grave:
		return .Backtick
	case .XK_minus:
		return .Minus
	case .XK_equal:
		return .Equal
	case .XK_bracketleft:
		return .LeftBracket
	case .XK_bracketright:
		return .RightBracket
	case .XK_semicolon:
		return .Semicolon
	case .XK_apostrophe:
		return .Quote
	case .XK_comma:
		return .Comma
	case .XK_period:
		return .Period
	case .XK_slash:
		return .Slash
	case .XK_backslash:
		return .BackSlash
	case .XK_Tab:
		return .Tab
	case .XK_Pause:
		return .Pause
	case .XK_Escape:
		return .Esc
	case .XK_Up, .XK_KP_Up:
		return .Up
	case .XK_Left, .XK_KP_Left:
		return .Left
	case .XK_Down, .XK_KP_Down:
		return .Down
	case .XK_Right, .XK_KP_Right:
		return .Right
	case .XK_BackSpace:
		return .Backspace
	case .XK_Return, .XK_KP_Enter:
		return .Return
	case .XK_Delete, .XK_KP_Delete:
		return .Delete
	case .XK_Insert, .XK_KP_Insert:
		return .Insert
	case .XK_Page_Up, .XK_KP_Page_Up:
		return .PageUp
	case .XK_Page_Down, .XK_KP_Page_Down:
		return .PageDown
	case .XK_Home, .XK_KP_Home:
		return .Home
	case .XK_End, .XK_KP_End:
		return .End
	case .XK_Caps_Lock:
		return .CapsLock
	case .XK_Num_Lock:
		return .NumLock
	case .XK_Menu:
		return .Menu
	case .XK_Super_L, .XK_Super_R:
		return .Super
	// case .XK_Scroll_Lock:
	// 	return .ScrollLock
	case .XK_Control_L, .XK_Control_R:
		return .Ctrl
	case .XK_Shift_L, .XK_Shift_R:
		return .Shift
	case .XK_Alt_L, .XK_Alt_R:
		return .Alt
	case .XK_KP_Divide:
		return .NumSlash
	case .XK_KP_Multiply:
		return .NumStar
	case .XK_KP_Subtract:
		return .NumMinus
	case .XK_KP_Add:
		return .NumPlus
	case .XK_KP_Decimal:
		return .NumPeriod
	}
	return .Null
}
