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
