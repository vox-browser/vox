module bookmarkui

$if ui2_custom_rendering ? {
	import gg
	import gg.render
	import ui2
}

$if ui2_custom_rendering ? {
	struct EventLog {
	mut:
		events []string
	}

	const event_log = &EventLog{}

	fn record_event(action string) {
		mut log := unsafe { event_log }
		log.events << action
	}
}

fn test_custom_backend_routes_bookmark_buttons_and_leaves_document_input_available() {
	$if ui2_custom_rendering ? {
		mut log := unsafe { event_log }
		log.events.clear()
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		state := State{ width: 800, height: 600, top: 60, visible: true, items: [Item{ title: 'Saved', url: 'about:blank' }] }
		ui2.draw_embedded_elements(ctx, elements(state), map[string]int{}, record_event)
		assert !ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 50, mouse_y: 180 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 30, mouse_y: 70 })
		assert log.events.len == 0
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 30, mouse_y: 70 })
		assert log.events == ['bookmark-open:0']
		// A context menu is also composed of UI2 controls on the custom backend.
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .right, mouse_x: 30, mouse_y: 70 })
		ui2.draw_embedded_elements(ctx, elements(state), map[string]int{}, record_event)
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 40, mouse_y: 80 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 40, mouse_y: 80 })
		assert log.events.last() == 'bookmark-remove:0'
		ui2.draw_embedded_elements(ctx, []ui2.Element{}, map[string]int{}, record_event)
		assert !ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 30, mouse_y: 70 })
	}
}

fn test_custom_backend_uses_compact_icons_and_routes_hacker_news_in_overflow() {
	$if ui2_custom_rendering ? {
		mut log := unsafe { event_log }
		log.events.clear()
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		state := State{ width: 800, height: 600, top: 60, visible: true,
			items: [Item{title: 'Hacker News', url: 'https://news.ycombinator.com/', icon: 'symbol:bookmark'}] }
		button := elements(state)[0].children[0]
		assert ui2.embedded_button_image_frame(button) == ui2.rect(5, 3.5, 16, 16)
		ui2.draw_embedded_elements(ctx, elements(state), map[string]int{}, record_event)
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 30, mouse_y: 70 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 30, mouse_y: 70 })
		assert log.events == ['bookmark-open:0']
		narrow := State{...state, width: 140, overflow: true}
		assert visible_count(narrow) == 0
		ui2.draw_embedded_elements(ctx, elements(narrow), map[string]int{}, record_event)
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: 30, mouse_y: 100 })
		assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 30, mouse_y: 100 })
		assert log.events == ['bookmark-open:0', 'bookmark-open:0']
		ui2.draw_embedded_elements(ctx, []ui2.Element{}, map[string]int{}, record_event)
	}
}
