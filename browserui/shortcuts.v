module browserui

import ui2

// UI2 normalizes physical keys and modifiers before application policy runs.
pub fn shortcut(event ui2.KeyEvent, editing bool, macos bool) string {
	devtools := devtools_shortcut(event, macos)
	if devtools != '' { return devtools }
	if event.alt { return '' }
	command := if macos { event.cmd && !event.ctrl } else { event.ctrl && !event.cmd }
	if event.ctrl && event.code == .tab {
		return if event.shift { 'tab-previous' } else { 'tab-next' }
	}
	if command {
		if event.code in [.equal, .kp_add, .kp_equal] { return 'zoom-in' }
		if !event.shift && event.code in [.minus, .kp_subtract] { return 'zoom-out' }
		if !event.shift && event.code in [._0, .kp_0] { return 'zoom-reset' }
		if event.code == .f && !event.shift { return 'find-open' }
		if event.code == .g { return if event.shift { 'find-previous' } else { 'find-next' } }
		if event.code == .b && event.shift { return 'bookmarks-toggle' }
		if event.code == .d { return if event.shift { 'debug-toggle' } else { 'bookmark-add' } }
		if (event.code == .y && !event.shift) || (event.code == .h && event.shift) {
			return 'history'
		}
		if event.shift && event.code == .left_bracket { return 'tab-previous' }
		if event.shift && event.code == .right_bracket { return 'tab-next' }
		if !event.shift {
			match event.code {
				.l { return 'address-focus' }
				.r { return 'reload' }
				.t { return 'tab-new' }
				.w { return 'tab-close' }
				.comma { return 'settings-open' }
				._1, ._2, ._3, ._4, ._5, ._6, ._7, ._8 {
					return 'tab-select:${int(event.code) - int(ui2.KeyCode._1)}'
				}
				._9 { return 'tab-last' }
				else {}
			}
		}
	}
	if editing && event.code == .escape { return 'address-cancel' }
	return ''
}

// devtools_shortcut follows Chrome: Cmd+Option+I (Ctrl+Shift+I elsewhere) or
// F12 toggles the panel, Cmd+Shift+C or Cmd+Option+C (Ctrl+Shift+C) starts
// picking an element in the page, and Cmd+Option+J (Ctrl+Shift+J) opens the
// console.
pub fn devtools_shortcut(event ui2.KeyEvent, macos bool) string {
	if event.code == .f12 && !event.cmd && !event.ctrl && !event.alt && !event.shift {
		return 'devtools-toggle'
	}
	if macos {
		if !event.cmd || event.ctrl { return '' }
		if event.alt && !event.shift {
			if event.code == .i { return 'devtools-toggle' }
			if event.code == .c { return 'devtools-inspect' }
			if event.code == .j { return 'devtools-console' }
		}
		if event.shift && !event.alt && event.code == .c { return 'devtools-inspect' }
		return ''
	}
	if !event.ctrl || !event.shift || event.cmd || event.alt { return '' }
	if event.code == .i { return 'devtools-toggle' }
	if event.code == .c { return 'devtools-inspect' }
	if event.code == .j { return 'devtools-console' }
	return ''
}
