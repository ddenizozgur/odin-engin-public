#+build windows
package win32

import "base:runtime"
import "core:sys/windows"

/*
*
*/

display_settings: windows.DEVMODEW

@(private = "file", init)
_display_settings_init :: proc "contextless" () {
	windows.EnumDisplaySettingsW(nil, windows.ENUM_CURRENT_SETTINGS, &display_settings)
}

set_console_utf8 :: proc() {
	windows.SetConsoleOutputCP(.UTF8)
	windows.SetConsoleCP(.UTF8)
}

graphical_error :: proc(title, msg: string) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	title16 := windows.utf8_to_wstring(title, context.temp_allocator)
	msg16 := windows.utf8_to_wstring(msg, context.temp_allocator)

	windows.MessageBoxW(nil, msg16, title16, windows.MB_OK | windows.MB_ICONERROR)
}

/*
*
*/

foreign import user32 "system:User32.lib"

@(default_calling_convention = "system")
foreign user32 {
	GetCaretBlinkTime :: proc() -> windows.UINT ---
	GetDoubleClickTime :: proc() -> windows.UINT ---
}

caret_blink_time :: proc() -> f32 {return cast(f32)GetCaretBlinkTime() / 1000.}
double_click_time :: proc() -> f32 {return cast(f32)GetDoubleClickTime() / 1000.}
