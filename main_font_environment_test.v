module main

import css
import dom
import fetch
import html
import layout
import webidl

fn font_environment_fixture() (&dom.Document, &css.FontFaceSet, &html.EventLoop) {
	mut document := html.parse_document_with_url('<!doctype html><body>fonts</body>', dom.URL{
		value: 'https://font-environment.example/'
	})
	_ = html.WindowModel.create_top_level(document, none, 'font-environment') or { panic(err) }
	document.set_cached_navigable(&dom.Navigable{ active_document_: document })
	layout.install_document_layout_hook(document)
	_ = layout.run_document_layout(document, 100, 100) or { panic("missing font environment layout") }
	return document, css.css_style_computer_for(document).font_face_set_, html.EventLoop.create(.window)
}

fn test_source_font_environment_checkpoint_gates_loading_stylesheets_imports_and_dirty_layout() {
	mut document, mut fonts, event_loop := font_environment_fixture()
	ready := fonts.ready()
	document.update_readiness(.loading)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert fonts.is_pending_on_the_environment
	assert ready.state == .pending
	document.update_readiness(.complete)
	mut request := dom.DocumentLoadEventDelayer.new_with_reason(mut document, .style_sheet_request)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert fonts.is_pending_on_the_environment
	request.finish()
	rule := &dom.CSSImportRule{}
	document.add_pending_css_import_rule(rule)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert fonts.is_pending_on_the_environment
	document.remove_pending_css_import_rule(rule)
	body := document.body() or { panic('body') }
	mut element := body.as_node().as_element() or { panic('body element') }
	element.set_attribute_value('style', 'width:20px')
	document.update_style()
	assert !document.layout_is_up_to_date()
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert fonts.is_pending_on_the_environment
	_ = layout.run_document_layout(document, 100, 100) or { panic("missing font environment layout") }
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert !fonts.is_pending_on_the_environment
	assert ready.state == .fulfilled
	assert ready.result.opaque_id == u64(voidptr(fonts))
	assert webidl.promise_realm(ready) != 0
}

@[heap]
struct ReadyFontRequests {
mut:
	pending []&fetch.PendingResponse
}

fn test_ready_flush_starts_new_style_font_load_and_loaded_transition_waits_for_it() {
	mut document, mut fonts, event_loop := font_environment_fixture()
	css.add_document_author_style_sheet(document,
		'@font-face {font-family: ReadyFlush;src:url("pending.ttf")}')
	_ = layout.run_document_layout(document, 100, 100) or { panic("missing font environment layout") }
	document.update_readiness(.complete)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	initial := fonts.ready()
	assert initial.state == .fulfilled
	face := fonts.set_entries()[0]
	assert face.status() == .unloaded
	requests := &ReadyFontRequests{}
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.set_fetch_host(&fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('must retain asynchronous font request')
		}
		perform_async: fn [requests] (request &fetch.Request) &fetch.PendingResponse {
			mut state := unsafe { &ReadyFontRequests(requests) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			state.pending << pending
			return pending
		}
	})
	body := document.body() or { panic('body') }
	mut element := body.as_node().as_element() or { panic('body element') }
	element.set_attribute_value('style', 'font-family:ReadyFlush')
	current := fonts.ready()
	assert face.status() == .loading
	assert requests.pending.len == 1
	assert voidptr(current) != voidptr(initial)
	assert current.state == .pending
	fonts.switch_to_loaded()
	assert current.state == .pending
	assert fonts.status() == .loading
}
