module browserui

import math
import ui2

pub struct MenuRow {
pub:
	id        string
	text      string
	enabled   bool = true
	group     bool
	separator bool
	checked   bool
	indent    int
}

pub struct Popup {
pub:
	token u64
	x     f64
	y     f64
	width f64 = 240
	rows  []MenuRow
pub mut:
	active int = -1
}

pub fn (popup Popup) action(index int) string {
	if index < 0 || index >= popup.rows.len { return '' }
	row := popup.rows[index]
	if !row.enabled || row.group || row.separator { return '' }
	return 'browser-menu:${popup.token}:${row.id}'
}

pub fn (mut popup Popup) key(key string) string {
	if key == 'escape' { return 'browser-menu:${popup.token}:dismiss' }
	if key == 'enter' || key == 'space' { return popup.action(popup.active) }
	if key !in ['up', 'down', 'home', 'end'] { return '' }
	step := if key in ['up', 'end'] { -1 } else { 1 }
	mut index := if key == 'home' {
		-1
	} else if key == 'end' {
		popup.rows.len
	} else {
		popup.active
	}
	for _ in 0 .. popup.rows.len {
		index = (index + step + popup.rows.len) % popup.rows.len
		if popup.action(index) != '' {
			popup.active = index
			break
		}
	}
	return ''
}

pub fn (popup Popup) elements(width f64, height f64) []ui2.Element {
	panel_width := math.min(math.max(0.0, width - 8), math.max(100.0, popup.width))
	x := math.max(4.0, math.min(popup.x, width - panel_width - 4))
	panel_height := math.min(math.max(0.0, height - 8), f64(popup.rows.len) * 28 + 4)
	y := math.max(4.0, math.min(popup.y, height - panel_height - 4))
	mut children := []ui2.Element{}
	for index, row in popup.rows {
		top := f64(index) * 28 + 2
		if row.separator {
			children << ui2.view('menu-separator-${index}', ui2.rect(8, top + 13, panel_width - 16, 1), ui2.BoxStyle{ bg: 0xd6d6d6 }, [])
			continue
		}
		text := '${if row.checked { '✓ ' } else { '  ' }}${row.text}'
		children << ui2.Element{
			...ui2.button('menu-row-${index}', text, ui2.rect(4 + f64(row.indent) * 12, top, math.max(0.0, panel_width - 8 - f64(row.indent) * 12), 26),
				ui2.BoxStyle{ bg: if index == popup.active { u32(0xdbeafe) } else { u32(0xf7f7f7) }, radius: 4 },
				ui2.TextStyle{
					size:  12
					bold:  row.group
					align: .left
					color: if row.enabled {
						u32(0x222222)
					} else {
						u32(0x888888)
					}
				})
			action_id:           popup.action(index)
			enabled:             row.enabled && !row.group
			accessibility_role:  if row.group { 'group' } else { 'menu_item' }
			tooltip:             row.text
			accessibility_label: row.text
			accessibility_value: if row.checked { 'selected' } else { '' }
		}
	}
	return [ui2.Element{
		...ui2.view('browser-menu-overlay', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
			ui2.with_action(ui2.button('browser-menu-dismiss', '', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), 'browser-menu:${popup.token}:dismiss'),
			ui2.Element{ ...ui2.scroll('browser-menu-list', ui2.rect(x, y, panel_width, panel_height), 0xf7f7f7, children), accessibility_role: 'menu' },
		])
		key: 'browser-menu-${popup.token}'
	}]
}
