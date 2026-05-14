#+build linux
package platform

import "base:runtime"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "vendor:x11/xlib"

@(private)
_window_init :: proc(title: string, size: [2]int, style := Window_Style.Windowed) -> bool {
	{
		// xlib.InitThreads()
		// xlib.SetErrorHandler(_err_handler)
		_display = xlib.OpenDisplay(nil)
		if _display == nil {
			fmt.eprintfln("[ERROR] xlib.OpenDisplay(): failed")
			return false
		}

		detectable: b32
		xlib.XkbSetDetectableAutoRepeat(_display, true, &detectable)
		if !detectable {
			fmt.eprintfln("[ERROR] Input system might receive key-release while key-down.")
		}

		_root_window = xlib.DefaultRootWindow(_display) // desktop as root

		{
			atom_strs := reflect.enum_field_names(_Atom_Names)
			for it, i in _Atom_Names {
				runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
				atom_cstr := strings.clone_to_cstring(
					atom_strs[i],
					allocator = context.temp_allocator,
				)
				_atoms[it] = xlib.InternAtom(_display, atom_cstr, false)
			}
		}

		_xim = xlib.OpenIM(_display, nil, nil, nil)
		if _xim == nil {
			fmt.eprintfln("[ERROR] UTF8 text input")
		}
	}

	_window = xlib.CreateWindow(
		_display,
		_root_window,
		0, // most wm dont care at all
		0, // most wm dont care at all
		cast(u32)size.x,
		cast(u32)size.y,
		0, // border width
		xlib.CopyFromParent, // copy from desktop
		.InputOutput, // allow drawing and input
		nil, // copy from desktop
		{},
		nil,
	)

	xlib.SelectInput(
		_display,
		_window,
		{
			.KeyPress,
			.KeyRelease,
			.ButtonPress,
			.ButtonRelease,
			.PointerMotion,
			.FocusChange,
			.StructureNotify,
			.PropertyChange,
			// TODO: .Exposure, maybe dont need???
			// .VisibilityChange,
			// .KeymapState,
			// .EnterWindow,
			// .LeaveWindow,
		},
	)

	protocols := []xlib.Atom{_atoms[.WM_DELETE_WINDOW], _atoms[._NET_WM_SYNC_REQUEST]}
	xlib.SetWMProtocols(_display, _window, raw_data(protocols), cast(i32)len(protocols))

	// XSyncValue initial_value;
	// XSyncIntToValue(&initial_value, 0);
	// w->counter_xid = XSyncCreateCounter(os_lnx_gfx_state->display, initial_value);
	// XChangeProperty(os_lnx_gfx_state->display, w->window, os_lnx_gfx_state->wm_sync_request_counter_atom, XA_CARDINAL, 32, PropModeReplace, (U8 *)&w->counter_xid, 1);

	// text input
	if _xim != nil {
		_xic = xlib.CreateIC(
			_xim,
			xlib.XNInputStyle,
			xlib.XIMPreeditNothing | xlib.XIMStatusNothing,
			xlib.XNClientWindow,
			_window,
			xlib.XNFocusWindow,
			_window,
			nil,
		)
	}

	// change title
	xlib.ChangeProperty(
		_display,
		_window,
		_atoms[._NET_WM_NAME],
		_atoms[.UTF8_STRING],
		8,
		xlib.PropModeReplace,
		raw_data(title),
		cast(i32)len(title),
	)

	// TODO: check
	if style == .FullScreen {
		xlib.ChangeProperty(
			_display,
			_window,
			_atoms[._NET_WM_STATE],
			xlib.XA_ATOM,
			32,
			xlib.PropModeReplace,
			&_atoms[._NET_WM_STATE_FULLSCREEN],
			1, // We are only sending 1 atom
		)
	}

	xlib.MapWindow(_display, _window)
	xlib.Flush(_display)

	return true
}

@(private)
_window_free :: proc() {
	// TODO: Destroy IC ??
	if _window != {} {
		xlib.DestroyWindow(_display, _window)
		_window = {}
	}
}

@(private)
_window_set_title :: proc(title: string) {
	xlib.ChangeProperty(
		_display,
		_window,
		_atoms[._NET_WM_NAME],
		_atoms[.UTF8_STRING],
		8,
		xlib.PropModeReplace,
		raw_data(title),
		cast(i32)len(title),
	)
}

@(private)
_window_set_focus :: proc() {
	xlib.SetInputFocus(_display, _window, .RevertToNone, xlib.CurrentTime)
}

@(private) // instead of this we can track in frame loop
_window_is_focused :: proc() -> bool {
	focused_wnd: xlib.Window
	revert_to: xlib.FocusRevert // ???
	xlib.GetInputFocus(_display, &focused_wnd, &revert_to)
	return _window == focused_wnd
}

@(private)
_get_client_size :: proc() -> [2]i32 {
	attribs: xlib.XWindowAttributes
	s := xlib.GetWindowAttributes(_display, _window, &attribs)
	return {attribs.width, attribs.height}
}

@(private)
_get_mouse_pos :: proc() -> [2]i32 {
	child: xlib.Window
	root_rel_x, root_rel_y: i32
	child_rel_x, child_rel_y: i32
	keymask: xlib.KeyMask

	xlib.QueryPointer(
		_display,
		_window,
		&_root_window,
		&child,
		&root_rel_x,
		&root_rel_y,
		&child_rel_x,
		&child_rel_y,
		&keymask,
	)

	return {child_rel_x, child_rel_y}
}

//
// Private
//
@(private)
_display: ^xlib.Display
@(private = "file")
_root_window: xlib.Window
@(private)
_window: xlib.Window

@(private)
_atoms: [_Atom_Names]xlib.Atom
@(private = "file")
_xim: xlib.XIM
@(private)
_xic: xlib.XIC

// NOTE: name must map one to one
@(private = "file")
_Atom_Names :: enum {
	WM_DELETE_WINDOW,
	_NET_WM_SYNC_REQUEST,
	// _NET_WM_SYNC_REQUEST_COUNTER,
	_NET_WM_NAME,
	UTF8_STRING,
	_NET_WM_STATE,
	_NET_WM_STATE_FULLSCREEN,
	WM_STATE,
	_NET_WM_STATE_HIDDEN, // minimize
}

/*
foreign import xlib_ext "system:X11"
@(default_calling_convention = "c")
foreign xlib_ext {
	XDestroyIC :: proc(ic: xlib.XIC) ---
}
*/

// _err_handler :: proc "c" (display: ^xlib.Display, event: ^xlib.XErrorEvent) -> i32 {
// 	context = runtime.default_context()
// 	fmt.eprintln("X11 Error!")
// 	return 0
// }
