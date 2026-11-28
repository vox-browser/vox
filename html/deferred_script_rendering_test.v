@[has_globals]
module html

import dom
import os

__global deferred_rendering_executed []string
__global deferred_rendering_document voidptr

// Runs the script as a module host does: its evaluation stays in flight.
fn deferred_rendering_execute(_ ScriptElementType, source string, _ dom.URL) ! {
	unsafe {
		deferred_rendering_executed << source
	}
	mut document := unsafe { &dom.Document(deferred_rendering_document) }
	document.begin_module_readiness_delay()
}

fn deferred_rendering_process_events() {
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 12 {
		event_loop.process()
	}
}

fn deferred_rendering_script(mut document dom.Document, source string) &dom.HTMLScriptElement {
	mut script := HTMLScriptElementModel.create(document.base_url())
	script.set_parser_document(document)
	script.set_text(source)
	script.set_execute_hook(deferred_rendering_execute)
	script.prepare_script(document)
	mut element := document.create_element('script') or { panic(err) }
	dom_script := unsafe { &dom.HTMLScriptElement(element) }
	attach_html_script_element_model(dom_script, script)
	return dom_script
}

// While the end of parsing can run its deferred scripts (one is ready, or a
// module graph evaluation is in flight), the document takes no rendering
// update; a script still blocked leaves rendering on, and so does the phase
// that follows the deferred scripts.
fn test_documents_skip_rendering_while_deferred_scripts_progress() {
	mut document := dom.Document.create(dom.URL{ value: 'https://deferred-rendering.test/' })
	deferred_rendering_document = voidptr(document)
	_ = WindowModel.create_top_level(document, none, 'deferred-rendering')!
	document.set_ready_to_run_scripts()
	script := deferred_rendering_script(mut document, 'deferred()')
	document.add_script_to_execute_when_parsing_has_finished(script)
	// A blocking style sheet holds the ready script back.
	mut blocking_style := document.create_element('style')!
	document.script_blocking_style_sheet_set << blocking_style
	HTMLParser.the_end(document, none)
	state := unsafe { &HTMLParserEndState(document.html_parser_end_state()) }
	deferred_rendering_process_events()
	assert state.phase() == .waiting_for_deferred_scripts
	assert !document_runs_deferred_scripts(document)
	// Ready to run: rendering waits for it.
	document.script_blocking_style_sheet_set.clear()
	enabled := os.getenv('VOX_RENDER_DURING_DEFERRED_SCRIPTS') == ''
	assert document_runs_deferred_scripts(document) == enabled
	// A module evaluation in flight holds rendering after the script ran.
	document.schedule_html_parser_end_check()
	deferred_rendering_process_events()
	assert deferred_rendering_executed == ['deferred()']
	assert state.phase() == .waiting_for_deferred_scripts
	assert document_runs_deferred_scripts(document) == enabled
	document.end_module_readiness_delay()
	deferred_rendering_process_events()
	assert state.phase() != .waiting_for_deferred_scripts
	assert !document_runs_deferred_scripts(document)
}
