module browserui

import ui2

$if ui2_custom_rendering ? {
	import gg
	import gg.render
}

struct TitleEditorEvents {
mut:
	events []string
}

const title_editor_events = &TitleEditorEvents{}

fn record_title_editor_event(event string) {
	mut state := unsafe { title_editor_events }
	state.events << event
}

fn test_tab_rename_and_color_menu_options_are_independent() {
	plain := tab_strip(800, [Tab{ title: 'Page', width: 184 }], 258).children[3]
	assert plain.menu.len == 0
	rename := tab_strip(800, [Tab{ title: 'Page', width: 184, rename_action: 'tab-rename:owner' }], 258).children[3]
	assert rename.menu == [ui2.MenuEntry{ id: 'tab-rename:owner', title: 'Rename Tab…' }]
	both := tab_strip(800, [Tab{ title: 'Research', width: 184, rename_action: 'tab-rename:owner', color_action: 'tab-color-menu:owner' }], 258).children[3]
	assert both.menu.len == 2
	assert both.menu[0].id == 'tab-color-menu:owner' && both.menu[1].id == 'tab-rename:owner'
	assert both.children[1].text == 'Research' && both.accessibility_label == 'Research'
	assert both.children[2].action_id == '' && both.children[2].id == 'tab-close:0'
}

fn test_title_editor_shares_accessible_input_submit_reset_cancel_and_outside_dismissal() {
	editor := TabTitleEditor{ token: 42, title: 'Research — 資料' }
	overlay := editor.elements(800, 600)[0]
	assert overlay.children[0].action_id == editor.action('cancel')
	dialog := overlay.children[1]
	assert dialog.accessibility_role == 'dialog'
	input := dialog.children[1]
	assert input.id == editor.input_id() && input.text == 'Research — 資料'
	assert input.submit_id == editor.action('save') && input.action_id == editor.action('change')
	assert input.accessibility_label == 'Custom tab title' && !input.autocorrect
	assert dialog.children[4].action_id == editor.action('reset')
	assert dialog.children[5].action_id == editor.action('cancel')
	assert dialog.children[6].action_id == editor.action('save')
	assert editor.input_id() != TabTitleEditor{ token: 43 }.input_id()
}

fn test_custom_renderer_edits_title_submits_enter_and_dismisses_outside() {
	$if ui2_custom_rendering ? {
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		mut log := unsafe { title_editor_events }
		log.events.clear()
		editor := TabTitleEditor{ token: 72, title: 'Research' }
		ui2.draw_embedded_elements(ctx, editor.elements(800, 600), map[string]int{}, record_title_editor_event)
		ui2.focus(editor.input_id())
		assert ui2.focused_id() == editor.input_id()
		assert ui2.embedded_elements_event(&gg.Event{ typ: .char, char_code: u32(`!`) })
		assert ui2.text(editor.input_id()) == 'Research!'
		assert log.events.last() == editor.action('change')
		assert ui2.embedded_elements_event(&gg.Event{ typ: .key_down, key_code: .enter })
		assert log.events.last() == editor.action('save')
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 4, mouse_y: 4 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 4, mouse_y: 4 })
		assert log.events.last() == editor.action('cancel')
		ui2.draw_embedded_elements(ctx, [], map[string]int{}, record_title_editor_event)
	}
}
