// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom

// parse_xml_document applies the browser's source and readiness lifecycle to
// the shared vlib XML parser. DOMParser and XML fragments use the source parser
// directly because they do not run this loading lifecycle.
pub fn parse_xml_document(document &dom.Document, source string) ! {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_source(source)
	mutable_document.set_document_type(.xml)
	mutable_document.update_readiness(.loading)
	parse_xml_document_source(document, source)!
	finish_xml_document_parsing(document)
}

// finish_xml_document_parsing retains the browser-specific completion steps
// previously owned by XMLDocumentBuilder. Embedders may resume this function
// after pending parser scripts or loading work become ready.
pub fn finish_xml_document_parsing(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_readiness(.interactive)

	// Documents without a browsing context and decoded SVG images have no
	// browsing lifecycle to wait for.
	if document.get_browsing_context() == none || document.is_decoded_svg() {
		mutable_document.update_readiness(.complete)
		return
	}

	// Deferred parser-inserted scripts execute in document order once both the
	// script and its blocking style sheets are ready.
	scripts := mutable_document.take_scripts_to_execute_when_parsing_has_finished()
	for index, script in scripts {
		mut event_loop := main_thread_event_loop()
		event_loop.spin_until(fn [document, script] () bool {
			return html_script_element_is_ready_to_be_parser_executed(script)
				&& !document.has_a_style_sheet_that_is_blocking_scripts()
		})
		if !html_script_element_is_ready_to_be_parser_executed(script)
			|| document.has_a_style_sheet_that_is_blocking_scripts() {
			// Preserve the unexecuted tail so the embedding can resume after its
			// script or stylesheet work completes.
			for pending_script in scripts[index..] {
				mutable_document.add_script_to_execute_when_parsing_has_finished(pending_script)
			}
			return
		}
		html_script_element_parser_execute_ready_script(script)
	}

	queue_a_task(.dom_manipulation, main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.mark_dom_content_loaded_event_start()
		mutable_document.dispatch_event_simple('DOMContentLoaded', true)
		mutable_document.mark_dom_content_loaded_event_end()
	})

	mut event_loop := main_thread_event_loop()
	event_loop.spin_until(fn [document] () bool {
		return !document.has_scripts_to_execute_as_soon_as_possible()
	})
	if document.has_scripts_to_execute_as_soon_as_possible() {
		return
	}
	event_loop.spin_until(fn [document] () bool {
		return !document.anything_is_delaying_the_load_event()
	})
	if document.anything_is_delaying_the_load_event() {
		return
	}

	queue_a_task(.dom_manipulation, main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_readiness(.complete)
		window := document.get_window() or { return }
		mutable_document.mark_load_event_start()
		window.dispatch_event_simple('load', false)
		mutable_document.mark_load_event_end()
		if !document.document_page_showing() {
			mutable_document.set_page_showing(true)
		}
		window.fire_a_page_transition_event('pageshow', false)
		mutable_document.completely_finish_loading()
	})

	mutable_document.set_ready_for_post_load_tasks(true)
}
