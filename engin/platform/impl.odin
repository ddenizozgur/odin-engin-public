package platform

//
// General
//
win32_set_console_utf8 :: #force_inline proc() {
	when ODIN_OS == .Windows {
		_set_console_utf8()
	} else {
		// NOOP
	}
}

//
// Window related
//
window_set_title :: #force_inline proc(title: string) {_window_set_title(title)}
window_set_focus :: #force_inline proc() {_window_set_focus()}
window_is_focused :: #force_inline proc() -> bool {return _window_is_focused()}
// window_is_fullscreen :: proc() -> bool {return _window_is_fullscreen()}
window_init :: #force_inline proc(
	title: string,
	size: [2]int,
	style := Window_Style.Windowed,
) -> bool {return _window_init(title, size, style)}
window_free :: #force_inline proc() {_window_free()}

//
// Still Window related + events
//
get_client_size :: #force_inline proc() -> [2]i32 {return _get_client_size()}
get_mouse_pos :: #force_inline proc() -> [2]i32 {return _get_mouse_pos()}

mouse_is_down :: proc(btn: Mouse_Button) -> bool {
	return _mouse_btns_this_frame[btn]
}
mouse_is_pressed :: proc(btn: Mouse_Button) -> bool {
	was_down := _mouse_btns_prev_frame[btn]
	is_down := _mouse_btns_this_frame[btn]
	return is_down && !was_down
}
mouse_is_released :: proc(btn: Mouse_Button) -> bool {
	was_down := _mouse_btns_prev_frame[btn]
	is_down := _mouse_btns_this_frame[btn]
	return !is_down && was_down
}

events_this_frame: [dynamic]Event
poll_events_this_frame :: proc() {
	for it in Mouse_Button {
		state := _mouse_btns_this_frame[it]
		_mouse_btns_prev_frame[it] = state
	}
	clear(&events_this_frame)
	_poll_events_this_frame()
}

//
// Private
//
@(private)
_mouse_btns_prev_frame: [Mouse_Button]bool
@(private)
_mouse_btns_this_frame: [Mouse_Button]bool
