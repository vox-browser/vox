module browserui

import math
import ui2

pub struct TabTitleEditor {
pub:
	token u64
pub mut:
	title string
	error string
}

pub fn (editor TabTitleEditor) input_id() string {
	return 'tab-title-input-${editor.token}'
}

pub fn (editor TabTitleEditor) action(name string) string {
	return 'tab-title-editor:${editor.token}:${name}'
}

pub fn (editor TabTitleEditor) elements(width f64, height f64) []ui2.Element {
	panel_width := math.min(400.0, math.max(0.0, width - 16))
	x := math.max(0.0, (width - panel_width) / 2)
	y := math.max(8.0, (height - 196) / 2)
	return [ui2.Element{
		...ui2.view('tab-title-overlay-${editor.token}', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
			ui2.with_action(ui2.button('tab-title-dismiss', '', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), editor.action('cancel')),
			ui2.Element{
				...ui2.view('tab-title-dialog', ui2.rect(x, y, panel_width, 196), ui2.BoxStyle{ bg: 0xf7f7f7, radius: 8, border_left: 1, border_top: 1, border_right: 1, border_bottom: 1, border_color: 0xadadad }, [
					ui2.label('tab-title-heading', 'Rename Tab', ui2.rect(16, 14, panel_width - 32, 24), ui2.TextStyle{ size: 18 }),
					ui2.Element{
						...ui2.text_input(id: editor.input_id(), action_id: editor.action('change'), submit_id: editor.action('save'),
							text: editor.title, hint_text: 'Tab title', multiline: false, autocorrect: false,
							frame: ui2.rect(16, 52, panel_width - 32, 28), text_style: ui2.TextStyle{ size: 13 }) or { panic(err) }
						accessibility_label: 'Custom tab title'
					},
					ui2.label('tab-title-help', 'Leave empty to use the page title.', ui2.rect(16, 88, panel_width - 32, 20), ui2.TextStyle{ size: 12 }),
					ui2.label('tab-title-error', editor.error, ui2.rect(16, 112, panel_width - 32, 20), ui2.TextStyle{ size: 12, color: 0xb42318 }),
					ui2.with_action(ui2.button('tab-title-reset', 'Use Page Title', ui2.rect(16, 150, 116, 28), ui2.BoxStyle{ bg: 0xe4e4e4, radius: 4 }, ui2.TextStyle{ size: 12 }), editor.action('reset')),
					ui2.with_action(ui2.button('tab-title-cancel', 'Cancel', ui2.rect(panel_width - 172, 150, 72, 28), ui2.BoxStyle{ bg: 0xe4e4e4, radius: 4 }, ui2.TextStyle{ size: 12 }), editor.action('cancel')),
					ui2.with_action(ui2.button('tab-title-save', 'Save', ui2.rect(panel_width - 88, 150, 72, 28), ui2.BoxStyle{ bg: 0xdbeafe, radius: 4 }, ui2.TextStyle{ size: 12 }), editor.action('save')),
				])
				accessibility_role: 'dialog'
				accessibility_label: 'Rename Tab'
			},
		])
		key: 'tab-title-overlay-${editor.token}'
	}]
}
