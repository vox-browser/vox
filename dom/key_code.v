// Copyright (c) 2018-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of UIEvents/KeyCode.h and the platform-key conversion helpers
// in UIEvents/KeyboardEvent.cpp.
module dom

import encoding.utf8

// Keep the default enum storage here. Current V can apply an explicitly backed
// enum to another module's same-named enum; a u8 backing also narrows
// gg.KeyCode, turning LeftSuper (343) into W (87) in native input events.
pub enum KeyCode {
	invalid           = 0x00
	backspace         = 0x08
	tab               = 0x09
	return_           = 0x0d
	left_shift        = 0x10
	left_control      = 0x11
	left_alt          = 0x12
	pause_break       = 0x13
	caps_lock         = 0x14
	escape            = 0x1b
	space             = 0x20
	page_up           = 0x21
	page_down         = 0x22
	end               = 0x23
	home              = 0x24
	left              = 0x25
	up                = 0x26
	right             = 0x27
	down              = 0x28
	print_screen      = 0x2a
	sys_rq            = 0x2c
	delete            = 0x2e
	key_0             = 0x30
	key_1             = 0x31
	key_2             = 0x32
	key_3             = 0x33
	key_4             = 0x34
	key_5             = 0x35
	key_6             = 0x36
	key_7             = 0x37
	key_8             = 0x38
	key_9             = 0x39
	a                 = 0x41
	b                 = 0x42
	c                 = 0x43
	d                 = 0x44
	e                 = 0x45
	f                 = 0x46
	g                 = 0x47
	h                 = 0x48
	i                 = 0x49
	j                 = 0x4a
	k                 = 0x4b
	l                 = 0x4c
	m                 = 0x4d
	n                 = 0x4e
	o                 = 0x4f
	p                 = 0x50
	q                 = 0x51
	r                 = 0x52
	s                 = 0x53
	t                 = 0x54
	u                 = 0x55
	v                 = 0x56
	w                 = 0x57
	x                 = 0x58
	y                 = 0x59
	z                 = 0x5a
	right_paren       = 0x60
	exclamation_point = 0x61
	at_sign           = 0x62
	hashtag           = 0x63
	dollar            = 0x64
	percent           = 0x65
	circumflex        = 0x66
	ampersand         = 0x67
	asterisk          = 0x68
	left_paren        = 0x69
	plus              = 0x6a
	minus             = 0x6b
	slash             = 0x6c
	comma             = 0x6d
	period            = 0x6e
	colon             = 0x6f
	f1                = 0x70
	f2                = 0x71
	f3                = 0x72
	f4                = 0x73
	f5                = 0x74
	f6                = 0x75
	f7                = 0x76
	f8                = 0x77
	f9                = 0x78
	f10               = 0x79
	f11               = 0x7a
	f12               = 0x7b
	double_quote      = 0x7c
	apostrophe        = 0x7d
	insert            = 0x7e
	semicolon         = 0x7f
	less_than         = 0x80
	equal             = 0x81
	greater_than      = 0x82
	question_mark     = 0x83
	left_bracket      = 0x84
	right_bracket     = 0x85
	backslash         = 0x86
	underscore        = 0x87
	left_brace        = 0x88
	right_brace       = 0x89
	pipe              = 0x8a
	tilde             = 0x8b
	backtick          = 0x8c
	num_lock          = 0x90
	scroll_lock       = 0x91
	left_super        = 0x92
	browser_search    = 0x93
	browser_favorites = 0x94
	browser_home      = 0x95
	previous_track    = 0x96
	browser_back      = 0x97
	browser_forward   = 0x98
	browser_refresh   = 0x99
	browser_stop      = 0x9a
	volume_down       = 0x9b
	volume_up         = 0x9c
	wake              = 0x9d
	sleep             = 0x9e
	next_track        = 0x9f
	media_select      = 0xa0
	email             = 0xa1
	my_computer       = 0xa2
	power             = 0xa3
	stop              = 0xa4
	left_gui          = 0xa5
	mute              = 0xa6
	right_gui         = 0xa7
	calculator        = 0xa8
	apps              = 0xa9
	play_pause        = 0xaa
	menu              = 0xab
	right_super       = 0xac
	right_shift       = 0xb0
	right_control     = 0xb1
	right_alt         = 0xb2
	alt_gr            = 0xe1
}

pub fn key_code_from_string(key_name string) KeyCode {
	runes := key_name.runes()
	if runes.len == 1 {
		code := code_point_to_key_code(u32(runes[0]))
		if code != .invalid {
			return code
		}
	}
	return match key_name {
		'Invalid' { .invalid }
		'Backspace' { .backspace }
		'Tab' { .tab }
		'Return' { .return_ }
		'LeftShift' { .left_shift }
		'RightShift' { .right_shift }
		'LeftControl' { .left_control }
		'RightControl' { .right_control }
		'LeftAlt' { .left_alt }
		'RightAlt' { .right_alt }
		'AltGr' { .alt_gr }
		'PauseBreak' { .pause_break }
		'CapsLock' { .caps_lock }
		'Escape' { .escape }
		'Space' { .space }
		'PageUp' { .page_up }
		'PageDown' { .page_down }
		'End' { .end }
		'Home' { .home }
		'Left' { .left }
		'Up' { .up }
		'Right' { .right }
		'Down' { .down }
		'PrintScreen' { .print_screen }
		'SysRq' { .sys_rq }
		'Delete' { .delete }
		'F1' { .f1 }
		'F2' { .f2 }
		'F3' { .f3 }
		'F4' { .f4 }
		'F5' { .f5 }
		'F6' { .f6 }
		'F7' { .f7 }
		'F8' { .f8 }
		'F9' { .f9 }
		'F10' { .f10 }
		'F11' { .f11 }
		'F12' { .f12 }
		'Insert' { .insert }
		'NumLock' { .num_lock }
		'ScrollLock' { .scroll_lock }
		'LeftSuper' { .left_super }
		'RightSuper' { .right_super }
		'BrowserSearch' { .browser_search }
		'BrowserFavorites' { .browser_favorites }
		'BrowserHome' { .browser_home }
		'PreviousTrack' { .previous_track }
		'BrowserBack' { .browser_back }
		'BrowserForward' { .browser_forward }
		'BrowserRefresh' { .browser_refresh }
		'BrowserStop' { .browser_stop }
		'VolumeDown' { .volume_down }
		'VolumeUp' { .volume_up }
		'Wake' { .wake }
		'Sleep' { .sleep }
		'NextTrack' { .next_track }
		'MediaSelect' { .media_select }
		'Email' { .email }
		'MyComputer' { .my_computer }
		'Power' { .power }
		'Stop' { .stop }
		'LeftGUI' { .left_gui }
		'Mute' { .mute }
		'RightGUI' { .right_gui }
		'Calculator' { .calculator }
		'Apps' { .apps }
		'PlayPause' { .play_pause }
		'Menu' { .menu }
		else { panic('Unknown UIEvents key code ${key_name}') }
	}
}

pub fn code_point_to_key_code(code_point u32) KeyCode {
	if code_point >= `A` && code_point <= `Z` {
		return unsafe { KeyCode(code_point) }
	}
	if code_point >= `a` && code_point <= `z` {
		return unsafe { KeyCode(code_point - 32) }
	}
	if code_point >= `0` && code_point <= `9` {
		return unsafe { KeyCode(code_point) }
	}
	return match code_point {
		8 { .backspace }
		9 { .tab }
		10 { .return_ }
		32 { .space }
		33 { .exclamation_point }
		34 { .double_quote }
		35 { .hashtag }
		36 { .dollar }
		37 { .percent }
		38 { .ampersand }
		39 { .apostrophe }
		40 { .left_paren }
		41 { .right_paren }
		42 { .asterisk }
		43 { .plus }
		44 { .comma }
		45 { .minus }
		46 { .period }
		47 { .slash }
		58 { .colon }
		59 { .semicolon }
		60 { .less_than }
		61 { .equal }
		62 { .greater_than }
		63 { .question_mark }
		64 { .at_sign }
		91 { .left_bracket }
		93 { .right_bracket }
		92 { .backslash }
		94 { .circumflex }
		95 { .underscore }
		123 { .left_brace }
		125 { .right_brace }
		124 { .pipe }
		126 { .tilde }
		96 { .backtick }
		else { .invalid }
	}
}

pub fn determine_key_code(platform_key KeyCode, code_point u32) u32 {
	if code_point >= `0` && code_point <= `9` {
		return code_point
	}
	shifted_digit := match platform_key {
		.exclamation_point { 49 }
		.at_sign { 50 }
		.hashtag { 51 }
		.dollar { 52 }
		.percent { 53 }
		.circumflex { 54 }
		.ampersand { 55 }
		.asterisk { 56 }
		.left_paren { 57 }
		.right_paren { 48 }
		else { 0 }
	}
	if shifted_digit != 0 {
		return u32(shifted_digit)
	}
	if code_point >= `a` && code_point <= `z` {
		return code_point - 32
	}
	return u32(match platform_key {
		.backspace { 8 }
		.tab { 9 }
		.return_ { 13 }
		.left_shift, .right_shift { 16 }
		.left_control, .right_control { 17 }
		.left_alt, .right_alt { 18 }
		.caps_lock { 20 }
		.escape { 27 }
		.space { 32 }
		.page_up { 33 }
		.page_down { 34 }
		.end { 35 }
		.home { 36 }
		.left { 37 }
		.up { 38 }
		.right { 39 }
		.down { 40 }
		.semicolon, .colon { 186 }
		.equal, .plus { 187 }
		.comma, .less_than { 188 }
		.minus, .underscore { 189 }
		.period, .greater_than { 190 }
		.slash, .question_mark { 191 }
		.backtick, .tilde { 192 }
		.left_bracket, .left_brace { 219 }
		.backslash, .pipe { 220 }
		.right_bracket, .right_brace { 221 }
		.apostrophe, .double_quote { 222 }
		else { int(platform_key) }
	})
}

pub fn determine_char_code(event_name string, code_point u32) u32 {
	if event_name == 'keypress' && code_point_is_printable(code_point) {
		return code_point
	}
	return 0
}

fn valid_unicode_scalar(code_point u32) bool {
	return code_point <= 0x10ffff && !(code_point >= 0xd800 && code_point <= 0xdfff)
}

fn code_point_is_printable(code_point u32) bool {
	if !valid_unicode_scalar(code_point) {
		return false
	}
	return !utf8.is_control(rune(code_point))
}

pub fn get_event_named_key(platform_key KeyCode) ?string {
	return match platform_key {
		.invalid { 'Unidentified' }
		.left_alt, .right_alt { 'Alt' }
		.alt_gr { 'AltGraph' }
		.caps_lock { 'CapsLock' }
		.left_control, .right_control { 'Control' }
		.left_super, .right_super { 'Meta' }
		.num_lock { 'NumLock' }
		.scroll_lock { 'ScrollLock' }
		.left_shift, .right_shift { 'Shift' }
		.return_ { 'Enter' }
		.tab { 'Tab' }
		.space { ' ' }
		.down { 'ArrowDown' }
		.left { 'ArrowLeft' }
		.right { 'ArrowRight' }
		.up { 'ArrowUp' }
		.end { 'End' }
		.home { 'Home' }
		.page_down { 'PageDown' }
		.page_up { 'PageUp' }
		.backspace { 'Backspace' }
		.delete { 'Delete' }
		.insert { 'Insert' }
		.menu { 'ContextMenu' }
		.escape { 'Escape' }
		.print_screen { 'PrintScreen' }
		.f1 { 'F1' }
		.f2 { 'F2' }
		.f3 { 'F3' }
		.f4 { 'F4' }
		.f5 { 'F5' }
		.f6 { 'F6' }
		.f7 { 'F7' }
		.f8 { 'F8' }
		.f9 { 'F9' }
		.f10 { 'F10' }
		.f11 { 'F11' }
		.f12 { 'F12' }
		else { none }
	}
}

pub fn get_event_key_string(code_point u32) ?string {
	if !valid_unicode_scalar(code_point) || utf8.is_control(rune(code_point)) {
		return none
	}
	return rune(code_point).str()
}

pub fn is_glyph_modifier_key(platform_key KeyCode) bool {
	return platform_key in [.left_shift, .right_shift, .caps_lock, .alt_gr]
}

pub fn remove_non_glyph_modifier_keys(modifiers u32) u32 {
	return (modifiers & modifier_shift) | (modifiers & modifier_alt)
}

pub fn get_event_key(platform_key KeyCode, code_point u32, modifiers u32) string {
	if platform_key != .invalid {
		if named_key := get_event_named_key(platform_key) {
			return named_key
		}
	}
	if key_string := get_event_key_string(code_point) {
		return key_string
	}
	if !is_glyph_modifier_key(platform_key) {
		mut unmodified_code_point := u32(platform_key)
		glyph_modifiers := remove_non_glyph_modifier_keys(modifiers)
		if unmodified_code_point >= `A` && unmodified_code_point <= `Z`
			&& glyph_modifiers & modifier_shift == 0 {
			unmodified_code_point += 32
		}
		if key_string := get_event_key_string(unmodified_code_point) {
			return key_string
		}
	}
	return 'Unidentified'
}

pub fn get_event_code(platform_key KeyCode, modifiers u32) string {
	if modifiers & modifier_keypad != 0 {
		keypad_code := match platform_key {
			.key_0 { 'Numpad0' }
			.key_1 { 'Numpad1' }
			.key_2 { 'Numpad2' }
			.key_3 { 'Numpad3' }
			.key_4 { 'Numpad4' }
			.key_5 { 'Numpad5' }
			.key_6 { 'Numpad6' }
			.key_7 { 'Numpad7' }
			.key_8 { 'Numpad8' }
			.key_9 { 'Numpad9' }
			.plus { 'NumpadAdd' }
			.comma { 'NumpadComma' }
			.period, .delete { 'NumpadDecimal' }
			.slash { 'NumpadDivide' }
			.return_ { 'NumpadEnter' }
			.asterisk { 'NumpadMultiply' }
			.minus { 'NumpadSubtract' }
			.equal { 'NumpadEqual' }
			.hashtag { 'NumpadHash' }
			.left_paren { 'NumpadParenLeft' }
			.right_paren { 'NumpadParenRight' }
			else { '' }
		}
		if keypad_code != '' {
			return keypad_code
		}
	}
	raw := u8(platform_key)
	if raw >= u8(KeyCode.a) && raw <= u8(KeyCode.z) {
		return 'Key${rune(raw).str()}'
	}
	if raw >= u8(KeyCode.key_0) && raw <= u8(KeyCode.key_9) {
		return 'Digit${rune(raw).str()}'
	}
	return match platform_key {
		.backtick, .tilde { 'Backquote' }
		.backslash, .pipe { 'Backslash' }
		.left_brace, .left_bracket { 'BracketLeft' }
		.right_brace, .right_bracket { 'BracketRight' }
		.comma, .less_than { 'Comma' }
		.right_paren { 'Digit0' }
		.exclamation_point { 'Digit1' }
		.at_sign { 'Digit2' }
		.hashtag { 'Digit3' }
		.dollar { 'Digit4' }
		.percent { 'Digit5' }
		.circumflex { 'Digit6' }
		.ampersand { 'Digit7' }
		.asterisk { 'Digit8' }
		.left_paren { 'Digit9' }
		.equal, .plus { 'Equal' }
		.minus, .underscore { 'Minus' }
		.period, .greater_than { 'Period' }
		.apostrophe, .double_quote { 'Quote' }
		.semicolon, .colon { 'Semicolon' }
		.slash, .question_mark { 'Slash' }
		.left_alt { 'AltLeft' }
		.right_alt { 'AltRight' }
		.alt_gr { 'AltGraph' }
		.backspace { 'Backspace' }
		.caps_lock { 'CapsLock' }
		.menu { 'ContextMenu' }
		.left_control { 'ControlLeft' }
		.right_control { 'ControlRight' }
		.return_ { 'Enter' }
		.left_super { 'MetaLeft' }
		.right_super { 'MetaRight' }
		.left_shift { 'ShiftLeft' }
		.right_shift { 'ShiftRight' }
		.space { 'Space' }
		.tab { 'Tab' }
		.delete { 'Delete' }
		.end { 'End' }
		.home { 'Home' }
		.insert { 'Insert' }
		.page_down { 'PageDown' }
		.page_up { 'PageUp' }
		.down { 'ArrowDown' }
		.left { 'ArrowLeft' }
		.right { 'ArrowRight' }
		.up { 'ArrowUp' }
		.num_lock { 'NumLock' }
		.escape { 'Escape' }
		.f1 { 'F1' }
		.f2 { 'F2' }
		.f3 { 'F3' }
		.f4 { 'F4' }
		.f5 { 'F5' }
		.f6 { 'F6' }
		.f7 { 'F7' }
		.f8 { 'F8' }
		.f9 { 'F9' }
		.f10 { 'F10' }
		.f11 { 'F11' }
		.f12 { 'F12' }
		.print_screen, .sys_rq { 'PrintScreen' }
		.scroll_lock { 'ScrollLock' }
		.pause_break { 'Pause' }
		.browser_search { 'BrowserSearch' }
		.browser_favorites { 'BrowserFavorites' }
		.browser_home { 'BrowserHome' }
		.previous_track { 'PreviousTrack' }
		.browser_back { 'BrowserBack' }
		.browser_forward { 'BrowserForward' }
		.browser_refresh { 'BrowserRefresh' }
		.browser_stop { 'BrowserStop' }
		.volume_down { 'AudioVolumeDown' }
		.volume_up { 'AudioVolumeUp' }
		.wake { 'WakeUp' }
		.sleep { 'Sleep' }
		.next_track { 'NextTrack' }
		.media_select { 'MediaSelect' }
		.email { 'LaunchMail' }
		.power { 'Power' }
		.stop { 'MediaStop' }
		.play_pause { 'MediaPlayPause' }
		.mute { 'AudioVolumeMute' }
		.calculator { 'LaunchApp2' }
		.my_computer { 'LaunchApp1' }
		.left_gui { 'LaunchApp2' }
		.right_gui, .apps { 'LaunchApp1' }
		.invalid { 'Unidentified' }
		else { 'Unidentified' }
	}
}

pub fn get_event_location(platform_key KeyCode, modifiers u32) u32 {
	if modifiers & modifier_keypad != 0 {
		return dom_key_location_numpad
	}
	return match platform_key {
		.left_alt, .left_control, .left_shift, .left_super { dom_key_location_left }
		.right_alt, .right_control, .right_shift, .right_super { dom_key_location_right }
		else { dom_key_location_standard }
	}
}
