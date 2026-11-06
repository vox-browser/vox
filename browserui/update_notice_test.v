module browserui

$if ui2_custom_rendering ? {
	import gg
	import gg.render
	import ui2
}

fn test_update_notice_explains_external_browser_and_exit_and_exposes_actions() {
	mut notice := UpdateNotice{ latest: '0.2.0', open: true }
	panel := notice.elements('0.1')
	assert panel.accessibility_role == 'dialog'
	assert panel.children[1].text.contains('0.2.0')
	assert panel.children[1].text.contains('0.1')
	assert panel.children[2].text.contains('default browser')
	assert panel.children[3].text.contains('closes')
	assert panel.children[4].text == ''
	assert panel.children[5].id == 'update-later'
	assert panel.children[6].id == 'update-ok'
	notice.open_failed = true
	assert notice.elements('0.1').children[4].text.contains('Try OK again')
}

fn test_update_notice_keyboard_accept_and_dismiss_actions() {
	notice := UpdateNotice{ open: true }
	assert notice.key_action('enter', false) == 'update-ok'
	assert notice.key_action('kp_enter', false) == 'update-ok'
	assert notice.key_action('escape', false) == 'update-later'
	assert notice.key_action('w', true) == 'update-later'
	assert notice.key_action('w', false) == ''
	assert notice.key_action('enter', true) == ''
	assert UpdateNotice{}.key_action('enter', false) == ''
}

struct UpdateNoticeEvents {
mut:
	events []string
}

const update_notice_events = &UpdateNoticeEvents{}

fn record_update_notice_event(event string) {
	mut log := unsafe { update_notice_events }
	log.events << event
}

fn test_custom_ui2_update_buttons_route_the_same_ok_and_later_actions() {
	$if ui2_custom_rendering ? {
		mut ctx := gg.new_context(native_rendering: true, width: 800, height: 600)
		ctx.r = render.new_context(max_vertices: 4096, max_commands: 256)
		mut log := unsafe { update_notice_events }
		log.events.clear()
		notice := UpdateNotice{ latest: '0.2.0', open: true }
		ui2.draw_embedded_elements(ctx, [notice.elements('0.1')], map[string]int{}, record_update_notice_event)
		for x in [390, 290] {
			assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: f32(x), mouse_y: 190 })
			assert ui2.embedded_elements_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: f32(x), mouse_y: 190 })
		}
		assert log.events == ['update-ok', 'update-later']
		ui2.draw_embedded_elements(ctx, [], map[string]int{}, record_update_notice_event)
	}
}
