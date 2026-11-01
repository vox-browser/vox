module browserui

import ui2

pub struct Tab {
pub:
	index    int
	title    string
	icon     string
	x        f64
	width    f64
	selected bool
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
	for tab in tabs {
		mut content := []ui2.Element{}
		if tab.icon != '' {
			content << ui2.image('tab-icon-${tab.index}', tab.icon, ui2.rect(10, 4, 16, 16))
		}
		content << ui2.label('tab-title-${tab.index}', tab.title, ui2.rect(30, 2, tab.width - 56, 22), ui2.TextStyle{ size: 11 })
		content << ui2.Element{
			...ui2.button('tab-close:${tab.index}', '×', ui2.rect(tab.width - 26, 3, 20, 20), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 14 })
			tooltip:             'Close ${tab.title}'
			accessibility_label: 'Close ${tab.title}'
		}
		children << ui2.Element{
			...ui2.view('tab-${tab.index}', ui2.rect(tab.x, 5, tab.width, 24),
				ui2.BoxStyle{ bg: if tab.selected { u32(0xf7f7f7) } else { u32(0xd2d2d2) }, radius: 8 }, content)
			key:                 'tab-${tab.index}'
			action_id:           'tabdrag-${tab.index}'
			clickable:           true
			draggable:           true
			tooltip:             tab.title
			accessibility_role:  'tab'
			accessibility_label: tab.title
			accessibility_value: if tab.selected { 'selected' } else { '' }
		}
	}
	children << ui2.Element{
		...ui2.button('tab-new', '+', ui2.rect(new_x, 7, 28, 20), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 16 })
		tooltip:             'New tab'
		accessibility_label: 'New tab'
	}
	return ui2.Element{
		...ui2.view('tab-strip', ui2.rect(0, 0, width, 29), ui2.BoxStyle{ bg: 0xdbdbdb }, children)
		accessibility_role: 'tab_list'
		action_id:          'window-drag'
		clickable:          true
	}
}
