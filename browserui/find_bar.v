module browserui

import math
import ui2

pub struct FindBar {
pub:
	token u64
pub mut:
	query     string
	matched   bool = true
	current   int
	total     int
	searched  bool
}

pub fn (bar FindBar) input_id() string {
	return 'find-input-${bar.token}'
}

pub fn (bar FindBar) action(name string) string {
	return 'find-bar:${bar.token}:${name}'
}

pub fn (bar FindBar) status() string {
	return find_status_text(bar.query, bar.searched, bar.current, bar.total)
}

// elements floats a compact panel at the document's top-right corner.
pub fn (bar FindBar) elements(width f64, top f64) []ui2.Element {
	panel_width := math.min(360.0, math.max(0.0, width - 16))
	x := math.max(0.0, width - panel_width - 8)
	status_color := if bar.searched && bar.total == 0 && bar.query != '' { u32(0xb42318) } else { u32(0x555555) }
	return [ui2.Element{
		...ui2.view('find-bar', ui2.rect(x, top + 6, panel_width, 36), ui2.BoxStyle{ bg: 0xf7f7f7, radius: 8, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1, border_color: 0xadadad }, [
			ui2.Element{
				...ui2.text_input(id: bar.input_id(), action_id: bar.action('change'), submit_id: bar.action('next'),
					text: bar.query, hint_text: tr('find.hint'), multiline: false, autocorrect: false,
					frame: ui2.rect(8, 5, panel_width - 164, 26), text_style: ui2.TextStyle{ size: 13 }) or { panic(err) }
				accessibility_label: tr('find.hint')
			},
			ui2.label('find-status', bar.status(), ui2.rect(panel_width - 150, 9, 64, 18), ui2.TextStyle{ size: 11, color: status_color }),
			ui2.with_action(ui2.button('find-previous', '‹', ui2.rect(panel_width - 82, 5, 26, 26), ui2.BoxStyle{ bg: 0xe4e4e4, radius: 4 }, ui2.TextStyle{ size: 14 }), bar.action('previous')),
			ui2.with_action(ui2.button('find-next', '›', ui2.rect(panel_width - 54, 5, 26, 26), ui2.BoxStyle{ bg: 0xe4e4e4, radius: 4 }, ui2.TextStyle{ size: 14 }), bar.action('next')),
			ui2.with_action(ui2.button('find-close', '×', ui2.rect(panel_width - 26, 5, 22, 26), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 14 }), bar.action('close')),
		])
		accessibility_role: 'search'
		accessibility_label: tr('find.hint')
	}]
}
