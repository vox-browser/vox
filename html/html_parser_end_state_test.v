@[has_globals]
module html

import dom
import css

@[heap]
struct ParserEndLayoutProbe {
mut:
	calls int
}

fn parser_end_count_layout(target voidptr, _ &dom.Document, _ f64, _ f64, _ bool) voidptr {
	mut probe := unsafe { &ParserEndLayoutProbe(target) }
	probe.calls++
	return unsafe { nil }
}

fn test_parser_end_avoids_fallback_layout_only_while_a_rendering_font_already_delays_load() {
	for rendering in [false, true] {
		mut document := parse_document('<!doctype html><p>pending load</p>')
		defer { document.finalize() }
		_ = WindowModel.create_top_level(document, none, 'parser-font-delay')!
		probe := &ParserEndLayoutProbe{}
		document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{target:probe,callback:parser_end_count_layout})
		mut fonts := css.FontFaceSet.create_for_font_computer(css.FontComputer.create_for_document(document))
		mut face := &css.FontFaceObject{family_:'ParserPendingFont',status_:.loading}
		if rendering { face.font_download_timer_start_ns_ = i64(1) }
		fonts.add(face)!
		document.set_font_face_set(fonts)
		mut delayer := dom.DocumentLoadEventDelayer.new(mut document)
		mut state := HTMLParserEndState.create(document, none)
		state.phase_ = .waiting_for_load_event_delay
		state.check_progress()
		assert state.phase() == .waiting_for_load_event_delay
		if rendering { assert probe.calls == 0 }
		else { assert probe.calls > 0 }
		delayer.finish()
		state.check_progress()
		assert probe.calls > 0
		assert state.phase() == .completion_queued
		process_event_loop_until(fn [state] () bool {
			return state.phase() == .completed
		})
		assert state.phase() == .completed
	}
}

__global html_parser_end_executed_scripts []string

fn html_parser_end_execute_script(_ ScriptElementType, source string, _ dom.URL) ! {
	unsafe {
		html_parser_end_executed_scripts << source
	}
}

fn process_event_loop_until(condition fn () bool) {
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 12 {
		if condition() {
			return
		}
		event_loop.process()
	}
}

fn test_parser_end_state_resumes_each_async_phase() {
	unsafe {
		html_parser_end_executed_scripts.clear()
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	_ = WindowModel.create_top_level(document, none, 'parser-end-test')!
	document.set_ready_to_run_scripts()

	mut script := HTMLScriptElementModel.create(document.base_url())
	script.set_parser_document(document)
	script.set_text('deferred()')
	script.set_execute_hook(html_parser_end_execute_script)
	script.prepare_script(document)
	mut script_element := document.create_element('script')!
	dom_script := unsafe { &dom.HTMLScriptElement(script_element) }
	attach_html_script_element_model(dom_script, script)
	document.add_script_to_execute_when_parsing_has_finished(dom_script)
	document.add_script_to_execute_as_soon_as_possible(dom_script)

	mut blocking_style := document.create_element('style')!
	document.script_blocking_style_sheet_set << blocking_style
	mut load_delayer := dom.DocumentLoadEventDelayer.new(mut document)

	HTMLParser.the_end(document, none)
	assert document.readiness() == .interactive
	assert document.has_html_parser_end_state()
	state := unsafe { &HTMLParserEndState(document.html_parser_end_state()) }
	process_event_loop_until(fn [state] () bool {
		return !state.has_pending_check()
	})
	assert state.phase() == .waiting_for_deferred_scripts
	unsafe {
		assert html_parser_end_executed_scripts.len == 0
	}

	document.script_blocking_style_sheet_set.clear()
	document.schedule_html_parser_end_check()
	process_event_loop_until(fn [state] () bool {
		return state.phase() == .waiting_for_asap_scripts
	})
	unsafe {
		assert html_parser_end_executed_scripts == ['deferred()']
	}

	document.take_scripts_to_execute_as_soon_as_possible()
	document.schedule_html_parser_end_check()
	process_event_loop_until(fn [state] () bool {
		return state.phase() == .waiting_for_load_event_delay
	})
	assert document.has_html_parser_end_state()

	load_delayer.finish()
	process_event_loop_until(fn [document] () bool {
		return !document.has_html_parser_end_state()
	})
	assert state.phase() == .completed
	assert document.document_ready_for_post_load_tasks()
	process_event_loop_until(fn [document] () bool {
		return document.readiness() == .complete
	})
	assert document.readiness() == .complete
}
