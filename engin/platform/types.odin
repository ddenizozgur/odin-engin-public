package platform

Window_Style :: enum {
	Windowed,
	FullScreen,
	// Secondary,
}

//
// Event related
//
Event_Key :: struct {
	code:  Key_Code,
	mod:   Key_Modifiers,
	state: Key_State,
	// is_repeat:    bool,
	// repeat_count: int,
}
Event_Text :: distinct rune

Event_Mouse_Button :: struct {
	button: Mouse_Button,
	state:  Key_State,
}
Event_Mouse_Move :: distinct [2]int
Event_Mouse_Scroll :: distinct [2]f32

Event_Window_Resize :: distinct [2]int
Event_Window_Focus :: struct {}
Event_Window_UnFocus :: struct {}
Event_Window_Minimize :: struct {}
Event_Window_Restore :: struct {}
Event_Window_Maximize :: struct {}
Event_Window_Close :: struct {}

Event :: union {
	Event_Key,
	Event_Text,
	Event_Mouse_Button,
	Event_Mouse_Move,
	Event_Mouse_Scroll,
	Event_Window_Resize,
	Event_Window_Focus,
	Event_Window_UnFocus,
	Event_Window_Minimize,
	Event_Window_Restore,
	Event_Window_Maximize,
	Event_Window_Close,
}

//
//
//
Key_Modifiers :: bit_set[_KeyModifier_Bit]
@(private = "file")
_KeyModifier_Bit :: enum {
	Shift,
	Ctrl,
	Alt, // AltGr ????
	Super,
	CapsLock,
	NumLock,
}

Key_Code :: enum u32 {
	Null = 0,
	Esc,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	F13,
	F14,
	F15,
	F16,
	F17,
	F18,
	F19,
	F20,
	F21,
	F22,
	F23,
	F24,
	Backtick,
	_0,
	_1,
	_2,
	_3,
	_4,
	_5,
	_6,
	_7,
	_8,
	_9,
	Minus,
	Equal,
	Backspace,
	Tab,
	Q,
	W,
	E,
	R,
	T,
	Y,
	U,
	I,
	O,
	P,
	LeftBracket,
	RightBracket,
	BackSlash,
	CapsLock,
	A,
	S,
	D,
	F,
	G,
	H,
	J,
	K,
	L,
	Semicolon,
	Quote,
	Return,
	Shift,
	Z,
	X,
	C,
	V,
	B,
	N,
	M,
	Comma,
	Period,
	Slash,
	Ctrl,
	Alt,
	Space,
	Menu,
	Super,
	// ScrollLock,
	Pause,
	Insert,
	Home,
	PageUp,
	Delete,
	End,
	PageDown,
	Up,
	Left,
	Down,
	Right,
	NumLock,
	NumSlash,
	NumStar,
	NumMinus,
	NumPlus,
	NumPeriod,
	Num0,
	Num1,
	Num2,
	Num3,
	Num4,
	Num5,
	Num6,
	Num7,
	Num8,
	Num9,
}

Mouse_Button :: enum {
	Left = 0,
	Middle,
	Right,
	XButton1, // TODO: check x11
	XButton2,
}

Key_State :: enum {
	Pressed,
	Released,
}
