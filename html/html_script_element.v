// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLScriptElement.{h,cpp}. LibJS parsing/evaluation and Fetch
// are host hooks; the element preparation, type selection, external/inline
// lifecycle, import-map registration, async/parser flags, and events live here.
module html

import dom

pub enum ScriptElementType {
	null_
	classic
	module
	import_map
}

pub type ScriptElementFetchHook = fn (dom.URL, ScriptElementType) !string

pub type ScriptElementExecuteHook = fn (ScriptElementType, string, dom.URL) !

@[heap]
pub struct HTMLScriptElementModel {
mut:
	base_url_                    dom.URL
	event_target_                &dom.EventTarget = unsafe { nil }
	src_                         ?string
	text_                        string
	type_attribute_              ?string
	language_attribute_          ?string
	async_attribute_             bool
	nomodule_                    bool
	connected_                   bool = true
	scripting_enabled_           bool = true
	parser_document_             ?&dom.Document
	preparation_time_document_   ?&dom.Document
	force_async_                 bool = true
	already_started_             bool
	from_external_file_          bool
	script_ready_                bool
	ready_to_be_parser_executed_ bool
	failed_to_load_              bool
	script_type_                 ScriptElementType
	fetch_hook_                  ?ScriptElementFetchHook
	execute_hook_                ?ScriptElementExecuteHook
	result_source_               ?string
	import_map_result_           ?&ImportMapParseResult
	registered_import_map_       ImportMap
	event_counts_                map[string]int
	source_line_number_          usize = 1
}

pub fn HTMLScriptElementModel.create(base_url dom.URL) &HTMLScriptElementModel {
	return &HTMLScriptElementModel{
		base_url_:     base_url
		event_target_: dom.EventTarget.new()
	}
}

pub fn html_script_element_supports(type_ string) bool {
	return type_ in ['classic', 'module', 'importmap']
}

fn is_javascript_mime_type(type_ string) bool {
	essence := ascii_lowercase_string(type_.split(';')[0].trim_space())
	return essence in ['', 'text/javascript', 'application/javascript', 'application/ecmascript',
		'text/ecmascript', 'text/jscript', 'text/livescript', 'application/x-javascript']
}

fn (mut script HTMLScriptElementModel) fire_event(name string) {
	script.event_counts_[name]++
	script.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (script &HTMLScriptElementModel) event_target() &dom.EventTarget {
	return script.event_target_
}

pub fn (script &HTMLScriptElementModel) event_count(name string) int {
	return script.event_counts_[name]
}

pub fn (mut script HTMLScriptElementModel) set_fetch_hook(hook ?ScriptElementFetchHook) {
	script.fetch_hook_ = hook
}

pub fn (mut script HTMLScriptElementModel) set_execute_hook(hook ?ScriptElementExecuteHook) {
	script.execute_hook_ = hook
}

pub fn (mut script HTMLScriptElementModel) set_src(value ?string) {
	script.src_ = value
}

pub fn (script &HTMLScriptElementModel) src() string {
	return script.src_ or { '' }
}

pub fn (mut script HTMLScriptElementModel) set_text(value string) {
	script.text_ = value
}

pub fn (script &HTMLScriptElementModel) text() string {
	return script.text_
}

pub fn (mut script HTMLScriptElementModel) set_type(value ?string) {
	script.type_attribute_ = value
}

pub fn (mut script HTMLScriptElementModel) set_language(value ?string) {
	script.language_attribute_ = value
}

pub fn (mut script HTMLScriptElementModel) set_nomodule(value bool) {
	script.nomodule_ = value
}

pub fn (mut script HTMLScriptElementModel) set_connected(value bool) {
	script.connected_ = value
}

pub fn (mut script HTMLScriptElementModel) set_scripting_enabled(value bool) {
	script.scripting_enabled_ = value
}

pub fn (mut script HTMLScriptElementModel) set_parser_document(document ?&dom.Document) {
	script.parser_document_ = document
}

pub fn (mut script HTMLScriptElementModel) set_source_line_number(line usize) {
	script.source_line_number_ = if line == 0 { usize(1) } else { line }
}

pub fn (script &HTMLScriptElementModel) is_parser_inserted() bool {
	return script.parser_document_ != none
}

pub fn (script &HTMLScriptElementModel) async_() bool {
	return script.force_async_ || script.async_attribute_
}

pub fn (mut script HTMLScriptElementModel) set_async(value bool) {
	script.force_async_ = false
	script.async_attribute_ = value
}

pub fn (script &HTMLScriptElementModel) is_force_async() bool {
	return script.force_async_
}

pub fn (script &HTMLScriptElementModel) is_ready_to_be_parser_executed() bool {
	return script.ready_to_be_parser_executed_
}

pub fn (script &HTMLScriptElementModel) failed_to_load() bool {
	return script.failed_to_load_
}

pub fn (script &HTMLScriptElementModel) script_type() ScriptElementType {
	return script.script_type_
}

fn (script &HTMLScriptElementModel) determine_type() ScriptElementType {
	type_value := if value := script.type_attribute_ {
		value.trim_space()
	} else if language := script.language_attribute_ {
		if language == '' { 'text/javascript' } else { 'text/${language}' }
	} else {
		'text/javascript'
	}
	if is_javascript_mime_type(type_value) {
		return .classic
	}
	return match ascii_lowercase_string(type_value) {
		'module' { .module }
		'importmap' { .import_map }
		else { .null_ }
	}
}

pub fn (mut script HTMLScriptElementModel) prepare_script(document ?&dom.Document) {
	if script.already_started_ {
		return
	}
	parser_document := script.parser_document_
	script.parser_document_ = none
	if parser_document != none && !script.async_attribute_ {
		script.force_async_ = true
	}
	if script.src_ == none && script.text_ == '' {
		return
	}
	if !script.connected_ {
		return
	}
	script.script_type_ = script.determine_type()
	if script.script_type_ == .null_ {
		return
	}
	if parser_document != none {
		script.parser_document_ = parser_document
		script.force_async_ = false
	}
	script.already_started_ = true
	script.preparation_time_document_ = document
	if parser_document != none && document != parser_document {
		return
	}
	if !script.scripting_enabled_ || (script.script_type_ == .classic && script.nomodule_) {
		return
	}
	if source_url := script.src_ {
		if script.script_type_ == .import_map || source_url == '' {
			script.failed_to_load_ = true
			script.fire_event('error')
			return
		}
		url := dom.dom_url_parse(source_url, script.base_url_, 'UTF-8') or {
			script.failed_to_load_ = true
			script.fire_event('error')
			return
		}
		script.from_external_file_ = true
		fetch := script.fetch_hook_ or {
			script.failed_to_load_ = true
			script.mark_as_ready(none)
			return
		}

		source := fetch(url, script.script_type_) or {
			script.failed_to_load_ = true
			script.mark_as_ready(none)
			return
		}
		script.result_source_ = source
		script.mark_as_ready(source)
		return
	}
	if script.script_type_ == .import_map {
		result := ImportMapParseResult.create(script.text_, script.base_url_)
		script.import_map_result_ = result
		script.script_ready_ = true
		script.execute_script()
		return
	}
	script.result_source_ = script.text_
	script.mark_as_ready(script.text_)
}

fn (mut script HTMLScriptElementModel) mark_as_ready(result ?string) {
	script.script_ready_ = true
	if result == none {
		script.failed_to_load_ = true
	}
	if script.is_parser_inserted() && !script.async_attribute_ {
		script.ready_to_be_parser_executed_ = true
		return
	}
	script.execute_script()
}

pub fn (mut script HTMLScriptElementModel) execute_script() {
	if !script.script_ready_ {
		return
	}
	if script.script_type_ == .import_map {
		mut result := script.import_map_result_ or { return }
		result.register_import_map(mut script.registered_import_map_, [], fn (_ string) {}) or {
			script.failed_to_load_ = true
			script.fire_event('error')
			return
		}
		return
	}
	source := script.result_source_ or {
		script.failed_to_load_ = true
		script.fire_event('error')
		return
	}

	execute := script.execute_hook_ or {
		if script.from_external_file_ {
			script.fire_event('load')
		}
		return
	}

	execute(script.script_type_, source, script.base_url_) or {
		script.failed_to_load_ = true
		script.fire_event('error')
		return
	}
	if script.from_external_file_ {
		script.fire_event('load')
	}
}

pub fn (mut script HTMLScriptElementModel) parser_execute_ready_script() {
	if !script.ready_to_be_parser_executed_ {
		return
	}
	script.ready_to_be_parser_executed_ = false
	script.execute_script()
}

pub fn (mut script HTMLScriptElementModel) unmark_as_already_started() {
	script.already_started_ = false
}

pub fn (mut script HTMLScriptElementModel) unmark_as_parser_inserted() {
	script.parser_document_ = none
}

pub fn (script &HTMLScriptElementModel) registered_import_map() &ImportMap {
	return &script.registered_import_map_
}

pub fn (script &HTMLScriptElementModel) is_implicitly_potentially_render_blocking() bool {
	return script.is_parser_inserted() && !script.async_attribute_ && script.script_type_ != .module
}
