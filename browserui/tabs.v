module browserui

import ui2
import browsertabs

pub struct Tab {
pub:
	index    int
	title    string
	icon     string
	x        f64
	width    f64 // distance between tab origins; shoulders overlap by 10px
	selected bool
	dragging bool
	color    browsertabs.Color
	color_action string
}

pub fn tab_fill(color browsertabs.Color, selected bool) u32 {
	if selected {
		return match color {
			.none { u32(0xf7f7f7) }
			.red { u32(0xffd6d6) }
			.orange { u32(0xffe0bd) }
			.yellow { u32(0xffefb0) }
			.green { u32(0xd0edcf) }
			.blue { u32(0xd0e4ff) }
			.purple { u32(0xe6d8fa) }
			.pink { u32(0xfad5e7) }
		}
	}
	return match color {
		.none { u32(0xd4d4d4) }
		.red { u32(0xe9b3b3) }
		.orange { u32(0xe9c49e) }
		.yellow { u32(0xe6d793) }
		.green { u32(0xafd0ad) }
		.blue { u32(0xadc6e6) }
		.purple { u32(0xc6b5df) }
		.pink { u32(0xdfb1c7) }
	}
}

pub fn tab_color_rows(selected browsertabs.Color) []MenuRow {
	mut rows := [MenuRow{ text: 'Tab Color', group: true }]
	for color in [browsertabs.Color.none, .red, .orange, .yellow, .green, .blue, .purple, .pink] {
		rows << MenuRow{
			id: 'tab-color-${color}'
			text: if color == .none { 'Default' } else { color.str().title() }
			checked: color == selected
		}
	}
	return rows
}

fn tab_cubic(mut points []ui2.VectorPoint, c1 ui2.VectorPoint, c2 ui2.VectorPoint, end ui2.VectorPoint) {
	start := points.last()
	for i in 1 .. 17 {
		t := f64(i) / 16
		u := 1 - t
		points << ui2.VectorPoint{
			x: u * u * u * start.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x
			y: u * u * u * start.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
		}
	}
}

// The previous silhouette, with smooth shoulder tangents and a half-pixel
// inset for its 1px outline. The same contour reaches both UI2 backends.
fn classic_tab_outline(width f64) []ui2.VectorPoint {
	mut points := [ui2.VectorPoint{ x: 0.5, y: 23.5 }]
	tab_cubic(mut points, ui2.VectorPoint{ x: 5.5, y: 23.5 }, ui2.VectorPoint{ x: 10.5, y: 7.5 }, ui2.VectorPoint{ x: 11.5, y: 4.5 })
	tab_cubic(mut points, ui2.VectorPoint{ x: 12.5, y: 1.5 }, ui2.VectorPoint{ x: 13.5, y: 0.5 }, ui2.VectorPoint{ x: 16.5, y: 0.5 })
	points << ui2.VectorPoint{ x: width - 16.5, y: 0.5 }
	tab_cubic(mut points, ui2.VectorPoint{ x: width - 13.5, y: 0.5 }, ui2.VectorPoint{ x: width - 12.5, y: 1.5 }, ui2.VectorPoint{ x: width - 11.5, y: 4.5 })
	tab_cubic(mut points, ui2.VectorPoint{ x: width - 10.5, y: 7.5 }, ui2.VectorPoint{ x: width - 5.5, y: 23.5 }, ui2.VectorPoint{ x: width - 0.5, y: 23.5 })
	return points
}

fn tab_fallback_icon(tab Tab) ui2.Element {
	if tab.title == 'Apps' {
		mut squares := []ui2.Element{}
		for row in 0 .. 3 {
			for col in 0 .. 3 {
				squares << ui2.view('tab-app-square-${tab.index}-${row}-${col}', ui2.rect(2 + col * 4, 3 + row * 4, 3, 3), ui2.BoxStyle{
					bg: [
						u32(0xe85447),
						0xf5b838,
						0x47a873,
					][(row + col) % 3]
				}, [])
			}
		}
		return ui2.view('tab-icon-${tab.index}', ui2.rect(12, 4, 16, 16), ui2.BoxStyle{ transparent: true }, squares)
	}
	return ui2.Element{
		...ui2.view('tab-icon-${tab.index}', ui2.rect(14, 7, 9, 11), ui2.BoxStyle{ transparent: true }, [])
		vector: ui2.VectorPath{
			points:       [ui2.VectorPoint{ x: 0.5, y: 0.5 }, ui2.VectorPoint{ x: 8.5, y: 0.5 },
				ui2.VectorPoint{ x: 8.5, y: 10.5 }, ui2.VectorPoint{ x: 0.5, y: 10.5 }]
			fill_enabled: false
			stroke:       0x808080
			stroke_width: 1
		}
	}
}

pub fn tab_strip(width f64, tabs []Tab, new_x f64) ui2.Element {
	mut children := []ui2.Element{}
	for index, action in ['close', 'minimize', 'zoom'] {
		children << ui2.Element{
			...ui2.button('window-${action}', '', ui2.rect(10 + f64(index) * 16, 8, 12, 12),
				ui2.BoxStyle{ bg: [u32(0xff5f57), 0xffbd2e, 0x28c840][index], radius: 6 }, ui2.TextStyle{})
			tooltip:             '${action} window'
			accessibility_label: '${action} window'
		}
	}
	mut inactive := []ui2.Element{}
	mut selected := []ui2.Element{}
	mut dragged := []ui2.Element{}
	for tab in tabs {
		paint_width := tab.width + 10
		mut content := []ui2.Element{}
		content << if tab.icon != '' {
			ui2.image('tab-icon-${tab.index}', tab.icon, ui2.rect(12, 4, 16, 16))
		} else {
			tab_fallback_icon(tab)
		}
		content << ui2.label('tab-title-${tab.index}', tab.title, ui2.rect(30, 3, paint_width - 56, 18), ui2.TextStyle{ size: 11, color: 0x383838, valign: .top })
		content << ui2.Element{
			...ui2.button('tab-close:${tab.index}', '×', ui2.rect(tab.width - 16, 3, 16, 16), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 11, color: 0x666666 })
			tooltip:             'Close ${tab.title}'
			accessibility_label: 'Close ${tab.title}'
		}
		if tab.selected {
			content << ui2.view('tab-seam-${tab.index}', ui2.rect(1, 23, paint_width - 2, 1), ui2.BoxStyle{ bg: tab_fill(tab.color, true) }, [])
		}
		element := ui2.Element{
			...ui2.view('tab-${tab.index}', ui2.rect(tab.x, 5, paint_width, 24), ui2.BoxStyle{ transparent: true }, content)
			vector:              ui2.VectorPath{
				points:       classic_tab_outline(paint_width)
				fill:         tab_fill(tab.color, tab.selected)
				stroke:       0xadadad
				stroke_width: 1
			}
			key:                 'tab-${tab.index}'
			action_id:           'tabdrag-${tab.index}'
			clickable:           true
			draggable:           true
			menu:                if tab.color_action != '' {
				[ui2.MenuEntry{ id: tab.color_action, title: 'Tab Color…' }]
			} else { []ui2.MenuEntry{} }
			tooltip:             tab.title
			accessibility_role:  'tab'
			accessibility_label: tab.title
			accessibility_value: if tab.selected { 'selected' } else { '' }
		}
		if tab.dragging {
			dragged << element
		} else if tab.selected {
			selected << element
		} else {
			inactive << element
		}
	}
	// Earlier inactive tabs overlap later ones. The selected tab, and then a
	// dragged tab, paint above their neighbors rather than becoming pill buttons.
	children << inactive.reverse()
	children << selected
	children << dragged
	children << ui2.Element{
		...ui2.button('tab-new', '', ui2.rect(new_x, 11, 28, 14), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{})
		vector:              ui2.VectorPath{
			points:       [ui2.VectorPoint{ x: 4.5, y: 0.5 }, ui2.VectorPoint{ x: 19.5, y: 0.5 },
				ui2.VectorPoint{ x: 26.5, y: 13.5 }, ui2.VectorPoint{ x: 0.5, y: 13.5 }]
			fill:         0xd4d4d4
			stroke:       0xadadad
			stroke_width: 1
		}
		tooltip:             'New tab'
		accessibility_label: 'New tab'
	}
	return ui2.Element{
		...ui2.view('tab-strip', ui2.rect(0, 0, width, 29), ui2.BoxStyle{ bg: 0xdbdbdb, border_bottom: 1, border_color: 0xadadad }, children)
		accessibility_role: 'tab_list'
		action_id:          'window-drag'
		clickable:          true
	}
}
