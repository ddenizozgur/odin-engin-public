package platform

@(private = "file")
_Key_Mode_Flags :: enum {
	Shift,
	Ctrl,
	Alt,
	Super,
	CapsLock,
	NumLock,
	// ScrollLock, ???
}
Key_Mode_Flags :: bit_set[_Key_Mode_Flags]

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
	ScrollLock,
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
	Ex0,
	Ex1,
	Ex2,
	Ex3,
	Ex4,
	Ex5,
	Ex6,
	Ex7,
	Ex8,
	Ex9,
	Ex10,
	Ex11,
	Ex12,
	Ex13,
	Ex14,
	Ex15,
	Ex16,
	Ex17,
	Ex18,
	Ex19,
	Ex20,
	Ex21,
	Ex22,
	Ex23,
	Ex24,
	Ex25,
	Ex26,
	Ex27,
	Ex28,
	Ex29,
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
	XButton1, // TODO: better names
	XButton2,
}

/*
*
*/

// TODO: change repeat??
Event_Key :: struct {
	code:         Key_Code,
	mode:         Key_Mode_Flags,
	state:        enum {
		Press,
		Release,
	},
	is_repeat:    bool,
	repeat_count: int, // TODO: it must be zero while release
}
Event_Text :: distinct rune

Event_Mouse_Button :: struct {
	button: Mouse_Button,
	state:  enum {
		Press,
		Release,
	},
}
Event_Mouse_Move :: distinct [2]i32
Event_Mouse_Scroll :: distinct [2]f32

Event_Window_Resize :: distinct [2]i32
Event_Window_Focus :: struct {}
Event_Window_UnFocus :: struct {}
Event_Window_Minimize :: struct {}
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
	Event_Window_Maximize,
	Event_Window_Close,
}

events_this_frame: [dynamic]Event
