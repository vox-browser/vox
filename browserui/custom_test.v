module browserui

$if ui2_custom_rendering ? {
	import gg
	import gg.render
	import ui2
}

fn test_custom_ui2_readonly_address_is_focusable_and_rejects_text_mutation() {
	$if ui2_custom_rendering ? {
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		field := ui2.Element{
			...address_field(ui2.rect(98, 34, 600, 20), 'https://example.com')
			readonly: true
		}
		ui2.draw_embedded_elements(ctx, [field], map[string]int{}, fn (_ string) {})
		ui2.select_embedded_textbox('address')
		assert ui2.focused_id() == 'address'
		assert ui2.embedded_elements_event(&gg.Event{ typ: .char, char_code: u32(`X`) })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .key_down, key_code: .backspace })
		assert ui2.text('address') == 'https://example.com'
		ui2.blur_embedded_textbox()
		assert !ui2.embedded_elements_event(&gg.Event{ typ: .char, char_code: u32(`X`) })
	}
}

struct CustomUIEvents {
mut:
	events []string
}

const custom_ui_events = &CustomUIEvents{}

fn record_custom_ui_event(event string) {
	mut log := unsafe { custom_ui_events }
	log.events << event
}

fn test_custom_ui2_routes_tab_drag_middle_click_and_wheel_through_its_targets() {
	$if ui2_custom_rendering ? {
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		mut log := unsafe { custom_ui_events }
		log.events.clear()
		ui2.draw_embedded_elements(ctx, [tab_strip(800, [Tab{ index: 0, title: 'Saved', x: 62, width: 184 }], 258)], map[string]int{}, record_custom_ui_event)
		assert ctx.r.num_vertices() > 0 // the custom backend painted the vector silhouettes
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 97, mouse_y: 15 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_move, mouse_x: 197, mouse_y: 15 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 197, mouse_y: 15 })
		assert log.events.len == 3
		assert log.events[0].starts_with('pointer:down:tabdrag-0:')
		assert log.events[1].starts_with('pointer:drag:tabdrag-0:')
		assert log.events[2].starts_with('pointer:up:tabdrag-0:')
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .middle, mouse_x: 97, mouse_y: 15 })
		assert log.events.last().starts_with('pointer:middle:tabdrag-0:')
		ui2.install_embedded_wheel(fn (_ f64, y f64, _ f64, _ f64) bool { return y < 29 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_scroll, mouse_x: 97, mouse_y: 15, scroll_y: 1 })
		assert !ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 97, mouse_y: 100 })
	}
}

fn test_custom_ui2_unmount_discards_canceled_edits_before_remount() {
	$if ui2_custom_rendering ? {
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		field := ui2.text_input(
			multiline: false
			id:        'settings-host'
			text:      'saved.example'
			frame:     ui2.rect(20, 20, 200, 24)
		)!
		ui2.draw_embedded_elements(ctx, [field], map[string]int{}, fn (_ string) {})
		ui2.set_text('settings-host', 'discarded.example')
		assert ui2.text('settings-host') == 'discarded.example'
		ui2.draw_embedded_elements(ctx, [], map[string]int{}, fn (_ string) {})
		assert ui2.text('settings-host') == ''
		ui2.draw_embedded_elements(ctx, [field], map[string]int{}, fn (_ string) {})
		assert ui2.text('settings-host') == 'saved.example'
	}
}
