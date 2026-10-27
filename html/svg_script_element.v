// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/SVG/SVGScriptElement.{h,cpp}. The concrete
// fetch and JavaScript execution operations remain host hooks in this port.
module html

import dom

@[heap]
pub struct SVGScriptElementModel {
mut:
	element_                     &dom.SVGScriptElement = unsafe { nil }
	document_                    &dom.Document = unsafe { nil }
	base_url_                    dom.URL
	href_                        string
	text_                        string
	parser_inserted_             bool
	already_processed_           bool
	ready_to_be_parser_executed_ bool
	result_source_               ?string
	fetch_hook_                  ?ScriptElementFetchHook
	execute_hook_                ?ScriptElementExecuteHook
	document_load_event_delayer_ ?dom.DocumentLoadEventDelayer
	source_line_number_          uint = 1
}

fn svg_script_dom_element(element &dom.SVGScriptElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn svg_script_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut model := unsafe { &SVGScriptElementModel(target) }
	model.adopted_from(old_document)
}

fn attach_svg_script_element_model(element &dom.SVGScriptElement, model &SVGScriptElementModel) {
	mut mutable_element := unsafe { &dom.SVGScriptElement(element) }
	mutable_element.script_element_model_ = voidptr(model)
	mut node := svg_script_dom_element(element).as_node()
	node.set_adopted_from_hook(dom.NodeAdoptedFromHook{
		target: voidptr(model)
		callback: svg_script_element_adopted_from_callback
	})
}

pub fn svg_script_element_model_for_dom_element(element &dom.SVGScriptElement) &SVGScriptElementModel {
	if element.script_element_model_ != unsafe { nil } {
		return unsafe { &SVGScriptElementModel(element.script_element_model_) }
	}
	dom_element := svg_script_dom_element(element)
	document := dom_element.document()
	mut model := &SVGScriptElementModel{
		element_: element
		document_: document
		base_url_: document.base_url()
		href_: dom_element.get_attribute('href') or {
			dom_element.get_attribute('xlink:href') or { '' }
		}
		text_: dom_element.as_node().child_text_content()
	}
	attach_svg_script_element_model(element, model)
	return model
}

// SVGScriptElement::adopted_from(). An in-flight external script continues to
// delay the load event of its new owner document, not the document it left.
pub fn (mut script SVGScriptElementModel) adopted_from(_ &dom.Document) {
	new_document := svg_script_dom_element(script.element_).document()
	script.document_ = new_document
	script.base_url_ = new_document.base_url()
	mut was_delaying_load := false
	if mut delayer := script.document_load_event_delayer_ {
		delayer.finish()
		was_delaying_load = true
	}
	if was_delaying_load {
		mut mutable_new_document := unsafe { &dom.Document(new_document) }
		script.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut mutable_new_document)
	}
}

pub fn (mut script SVGScriptElementModel) set_parser_inserted() {
	script.parser_inserted_ = true
}

pub fn (script &SVGScriptElementModel) is_parser_inserted() bool {
	return script.parser_inserted_
}

pub fn (mut script SVGScriptElementModel) set_source_line_number(line uint) {
	script.source_line_number_ = line
}

pub fn (mut script SVGScriptElementModel) set_text(text string) {
	script.text_ = text
}

pub fn (mut script SVGScriptElementModel) set_fetch_hook(hook ?ScriptElementFetchHook) {
	script.fetch_hook_ = hook
}

pub fn (mut script SVGScriptElementModel) set_execute_hook(hook ?ScriptElementExecuteHook) {
	script.execute_hook_ = hook
}

pub fn (script &SVGScriptElementModel) is_ready_to_be_parser_executed() bool {
	return script.ready_to_be_parser_executed_
}

pub fn (script &SVGScriptElementModel) already_processed() bool {
	return script.already_processed_
}

// https://www.w3.org/TR/SVG2/interact.html#ScriptElement
pub fn (mut script SVGScriptElementModel) process_the_script_element() {
	if script.already_processed_ {
		return
	}
	element := svg_script_dom_element(script.element_)
	if !element.as_node().is_connected() || element.as_node().is_scripting_disabled() {
		return
	}

	if script.href_ != '' {
		script_url := dom.dom_url_parse(script.href_, script.base_url_, 'UTF-8') or { return }
		// Set this before dispatching the fetch so re-entrant attribute changes do
		// not start another request while this one is in flight.
		script.already_processed_ = true
		mut document := script.document_
		script.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
		if script.parser_inserted_ {
			document.set_pending_parsing_blocking_svg_script(script.element_)
		}

		model_pointer := voidptr(script)
		queue_a_task(.networking, main_thread_event_loop(), script.document_, fn [model_pointer, script_url] () {
			mut model := unsafe { &SVGScriptElementModel(model_pointer) }
			fetch := model.fetch_hook_ or {
				model.finish_external_script_fetch(script_url, none)
				return
			}
			source := fetch(script_url, .classic) or {
				model.finish_external_script_fetch(script_url, none)
				return
			}
			model.finish_external_script_fetch(script_url, source)
		})
		return
	}

	script.text_ = element.as_node().child_text_content()
	if script.text_ == '' {
		return
	}
	script.already_processed_ = true
	script.result_source_ = script.text_
	script.execute_script()
}

pub fn (mut script SVGScriptElementModel) finish_external_script_fetch(_ dom.URL, source ?string) {
	element := svg_script_dom_element(script.element_)
	if fetched_source := source {
		if fetched_source != '' && element.as_node().is_connected()
			&& !element.as_node().is_scripting_disabled() {
			script.result_source_ = fetched_source
		}
	}

	if script.parser_inserted_ {
		script.ready_to_be_parser_executed_ = true
		script.document_.schedule_html_parser_end_check()
		return
	}

	script.stop_delaying_document_load_event()
	script.execute_script()
}

pub fn (mut script SVGScriptElementModel) execute_pending_parser_blocking_script() {
	assert script.ready_to_be_parser_executed_
	script.ready_to_be_parser_executed_ = false
	script.stop_delaying_document_load_event()
	script.execute_script()
}

fn (mut script SVGScriptElementModel) stop_delaying_document_load_event() {
	if mut delayer := script.document_load_event_delayer_ {
		delayer.finish()
	}
	script.document_load_event_delayer_ = none
}

fn (mut script SVGScriptElementModel) execute_script() {
	source := script.result_source_ or { return }
	if !script.document_.document_ready_to_run_scripts() {
		return
	}
	execute := script.execute_hook_ or { return }
	execute(.classic, source, script.base_url_) or {}
}
