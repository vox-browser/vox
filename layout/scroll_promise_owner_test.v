module layout

import dom
import html
import time
import webidl

fn scroll_promise_document() !(&dom.Document, &html.WindowModel, &html.NavigableModel) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:1000px}#scroller{width:100px;height:50px;overflow:auto}#content{height:300px}</style><div id="scroller"><div id="content"></div></div>')
	window := html.WindowModel.create_top_level(document, none, 'scroll-promise-owner')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window, window.navigable_model()
}

fn test_instant_and_smooth_scrolls_retain_actual_document_realm_capabilities() {
	document, mut window, mut model := scroll_promise_document()!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	realm := settings.realm()
	instant := window.scroll(html.ScrollToOptions{ top: 30, behavior: .instant })
	assert instant.state() == .fulfilled
	assert webidl.promise_realm(instant.webidl_promise()?) == u64(voidptr(realm))
	first := window.scroll(html.ScrollToOptions{ top: 300, behavior: .smooth })
	second := window.scroll(html.ScrollToOptions{ top: 300, behavior: .smooth })
	assert first.state() == .pending && second.state() == .pending
	assert voidptr(first.webidl_promise()?) != voidptr(second.webidl_promise()?)
	assert webidl.promise_realm(first.webidl_promise()?) == u64(voidptr(realm))
	context := webidl.promise_context(second.webidl_promise()?)
	run := context.realm_steps_runner or { panic('missing actual owning realm runner') }
	run(fn [realm] () {
		assert realm.script_execution_depth >= 1 && realm.callback_execution_depth >= 1
	})
	time.sleep(300 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert window.scroll_y() == 300
	assert first.state() == .pending && second.state() == .pending
	html.perform_a_microtask_checkpoint()
	assert first.state() == .fulfilled && second.state() == .fulfilled
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
}

fn test_element_scroll_owner_capability_survives_replacement_until_source_microtask() {
	document, _, mut model := scroll_promise_document()!
	mut scroller := document.get_element_by_id('scroller') or { panic('scroller') }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	old := scroller.el_scroll_with_options(dom.ScrollToOptions_{ top: 200, behavior: .smooth })
	assert webidl.promise_realm(old.webidl_promise()?) == u64(voidptr(settings.realm()))
	instant := scroller.el_scroll_with_options(dom.ScrollToOptions_{ top: 40, behavior: .instant })
	assert instant.state() == .fulfilled && old.state() == .pending
	assert scroller.scroll_top() == 40
	html.perform_a_microtask_checkpoint()
	assert old.state() == .fulfilled
	assert settings.realm().script_execution_depth == 0
}
