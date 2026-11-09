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

pub type ScriptElementFetchHook = fn(dom.URL, ScriptElementType) !string

// Completion is delivered by the embedder on the document's owning thread.
// The model, rather than the transport, owns execution order and readiness.
pub type ScriptElementAsyncFetchHook = fn (&HTMLScriptElementModel, dom.URL, ScriptElementType) !

pub type ScriptElementExecuteHook = fn(ScriptElementType, string, dom.URL) !

pub type ScriptElementExecuteHookWithElement = fn (&dom.HTMLScriptElement, ScriptElementType, string, dom.URL) !

enum ScriptElementScheduling {
	immediate
	parser_blocking
	after_parsing
	asap
}

@[heap]
pub struct HTMLScriptElementModel {
mut:
	element_                      ?&dom.HTMLScriptElement
	base_url_                     dom.URL
	event_target_                 &dom.EventTarget = unsafe { nil }
	src_                          ?string
	text_                         string
	type_attribute_               ?string
	language_attribute_           ?string
	async_attribute_              bool
	nomodule_                     bool
	connected_                    bool = true
	scripting_enabled_            bool = true
	parser_document_              ?&dom.Document
	preparation_time_document_    ?&dom.Document
	preparation_stream_generation_ u64
	force_async_                  bool = true
	already_started_              bool
	from_external_file_           bool
	script_ready_                 bool
	ready_to_be_parser_executed_  bool
	failed_to_load_               bool
	script_type_                  ScriptElementType
	fetch_hook_                   ?ScriptElementFetchHook
	async_fetch_hook_             ?ScriptElementAsyncFetchHook
	execute_hook_                 ?ScriptElementExecuteHook
	execute_hook_with_element_    ?ScriptElementExecuteHookWithElement
	scheduling_                   ScriptElementScheduling
	fetch_pending_                bool
	executed_                     bool
	execution_queued_             bool
	script_url_                   ?dom.URL
	result_source_                ?string
	import_map_result_            ?&ImportMapParseResult
	registered_import_map_        ImportMap
	event_counts_                 map[string]int
	source_line_number_           uint = 1
	crossorigin_                  CORSSettingAttribute
	referrer_policy_              string
	document_load_event_delaying_ bool
	document_load_event_delayer_  ?dom.DocumentLoadEventDelayer
}

pub fn HTMLScriptElementModel.create(base_url dom.URL) &HTMLScriptElementModel {
	return &HTMLScriptElementModel{
		base_url_: base_url
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
	event := dom.Event.create(name, dom.EventInit{})
	if element := script.element_ {
		unsafe { &dom.EventTarget(element) }
		.dispatch_event(event)
	} else {
		script.event_target_.dispatch_event(event)
	}
}

fn script_dom_element(element &dom.HTMLScriptElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn html_script_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut model := unsafe { &HTMLScriptElementModel(target) }
	model.adopted_from(old_document)
}

fn attach_html_script_element_model(element &dom.HTMLScriptElement, model &HTMLScriptElementModel) {
	mut mutable_model := unsafe { &HTMLScriptElementModel(model) }
	mutable_model.element_ = element
	mut mutable_element := unsafe { &dom.HTMLScriptElement(element) }
	mutable_element.script_element_model_ = voidptr(model)
	mut node := script_dom_element(element).as_node()
	node.set_adopted_from_hook(dom.NodeAdoptedFromHook{
		target: voidptr(model)
		callback: html_script_element_adopted_from_callback
	})
}

pub fn html_script_element_model_for_dom_element(element &dom.HTMLScriptElement) &HTMLScriptElementModel {
	if element.script_element_model_ != unsafe { nil } {
		model := unsafe { &HTMLScriptElementModel(element.script_element_model_) }
		attach_html_script_element_model(element, model)
		return model
	}
	dom_element := script_dom_element(element)
	mut model := HTMLScriptElementModel.create(dom_element.document().base_url())
	model.src_ = dom_element.get_attribute('src')
	model.text_ = dom_element.as_node().child_text_content()
	model.type_attribute_ = dom_element.get_attribute('type')
	model.language_attribute_ = dom_element.get_attribute('language')
	model.async_attribute_ = dom_element.has_attribute('async')
	model.nomodule_ = dom_element.has_attribute('nomodule')
	model.connected_ = dom_element.as_node().is_connected()
	model.crossorigin_ = cors_setting_attribute_from_keyword(dom_element.get_attribute('crossorigin'))
	model.referrer_policy_ = ascii_lowercase_string(dom_element.get_attribute_value('referrerpolicy'))
	attach_html_script_element_model(element, model)
	return model
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

pub fn (mut script HTMLScriptElementModel) set_async_fetch_hook(hook ?ScriptElementAsyncFetchHook) {
	script.async_fetch_hook_ = hook
}

pub fn (mut script HTMLScriptElementModel) set_execute_hook(hook ?ScriptElementExecuteHook) {
	script.execute_hook_ = hook
}

pub fn (mut script HTMLScriptElementModel) set_execute_hook_with_element(hook ?ScriptElementExecuteHookWithElement) {
	script.execute_hook_with_element_ = hook
}

pub fn (script &HTMLScriptElementModel) element() ?&dom.HTMLScriptElement {
	return script.element_
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

pub fn (mut script HTMLScriptElementModel) set_force_async(value bool) {
	script.force_async_ = value
}

pub fn (mut script HTMLScriptElementModel) set_already_started(value bool) {
	script.already_started_ = value
}

pub fn (mut script HTMLScriptElementModel) set_string_text(value string) {
	script.text_ = value
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

pub fn (mut script HTMLScriptElementModel) set_source_line_number(line uint) {
	script.source_line_number_ = if line == 0 { uint(1) } else { line }
}

pub fn (script &HTMLScriptElementModel) source_line_number() int {
	return int(script.source_line_number_)
}

pub fn (script &HTMLScriptElementModel) is_parser_inserted() bool {
	return script.parser_document_ != none
}

pub fn (script &HTMLScriptElementModel) has_already_started() bool {
	return script.already_started_
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
	script.prepare_script_text()
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
	if owner := document {
		script.preparation_stream_generation_ = owner.html_parser_stream_generation()
	}
	if parser_document != none && voidptr(document or { unsafe { nil } }) != voidptr(parser_document or {
		unsafe { nil }
	}) {
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
		script.script_url_ = url
		script.prepare_execution_schedule()
		if preparation_document := script.preparation_time_document_ {
			script.begin_delaying_document_load_event(preparation_document)
		}
		script.fetch_pending_ = true
		if fetch := script.async_fetch_hook_ {
			fetch(script, url, script.script_type_) or { script.complete_external_fetch(none) }
			return
		}
		fetch := script.fetch_hook_ or {
			script.complete_external_fetch(none)
			return
		}

		source := fetch(url, script.script_type_) or {
			script.complete_external_fetch(none)
			return
		}
		script.complete_external_fetch(source)
		return
	}
	if element := script.element_ {
		owner := script_dom_element(element)
		if owner.document().should_block_inline_content(owner, 'script', script.text_) { return }
	}
	if script.script_type_ == .import_map {
		result := ImportMapParseResult.create(script.text_, script.base_url_)
		script.import_map_result_ = result
		script.script_ready_ = true
		script.execute_script()
		return
	}
	script.prepare_execution_schedule()
	if script.script_type_ == .module {
		if preparation_document := script.preparation_time_document_ {
			script.begin_delaying_document_load_event(preparation_document)
		}
	}
	script.mark_as_ready(script.text_)
}

// Decide the scheduling class before calling the host. A cache hit can finish
// fetching synchronously, but must not turn an async/deferred script into a
// parser-blocking one.
fn (mut script HTMLScriptElementModel) prepare_execution_schedule() {
	if script.is_parser_inserted() {
		deferred := if element := script.element_ {
			script_dom_element(element).has_attribute('defer')
		} else { false }
		if !script.async_attribute_ && (script.script_type_ == .module
			|| (script.from_external_file_ && deferred)) {
			script.scheduling_ = .after_parsing
		} else if script.script_type_ == .classic
			&& (!script.from_external_file_ || !script.async_attribute_) {
			script.scheduling_ = .parser_blocking
		} else {
			script.scheduling_ = .asap
		}
	} else if script.from_external_file_ || script.script_type_ == .module {
		script.scheduling_ = .asap
	}
	element := script.element_ or { return }
	owner := script.preparation_time_document_ or { return }
	mut document := unsafe { &dom.Document(owner) }
	match script.scheduling_ {
		.parser_blocking { document.set_pending_parsing_blocking_script(element) }
		.after_parsing { document.add_script_to_execute_when_parsing_has_finished(element) }
		.asap { document.add_script_to_execute_as_soon_as_possible(element) }
		.immediate {}
	}
}

// Both queued requests and completed cache reads use the same transition.
pub fn (mut script HTMLScriptElementModel) complete_external_fetch(source ?string) {
	if !script.fetch_pending_ || script.executed_ { return }
	script.fetch_pending_ = false
	if !script.belongs_to_preparation_document() {
		script.cancel_external_fetch()
		return
	}
	mut allocations := enter_html_document_storage(script.preparation_time_document_)
	defer { allocations.finish() }
	owned_source := if text := source { ?string(text.clone()) } else { none }
	script.mark_as_ready(owned_source)
}

pub fn (mut script HTMLScriptElementModel) cancel_external_fetch() {
	mut allocations := enter_html_document_storage(script.preparation_time_document_)
	defer { allocations.finish() }
	script.fetch_pending_ = false
	script.executed_ = true
	// A parser waiting at this element still needs to advance past it.
	script.script_ready_ = true
	script.ready_to_be_parser_executed_ = true
	script.finish_execution()
}

fn (script &HTMLScriptElementModel) belongs_to_preparation_document() bool {
	if document := script.preparation_time_document_ {
		if document.has_been_destroyed() { return false }
		if script.preparation_stream_generation_ != document.html_parser_stream_generation() { return false }
		if element := script.element_ {
			return voidptr(script_dom_element(element).document()) == voidptr(document)
		}
	}
	return true
}

fn (mut script HTMLScriptElementModel) mark_as_ready(result ?string) {
	script.result_source_ = result
	script.script_ready_ = true
	if result == none {
		script.failed_to_load_ = true
	}
	if script.scheduling_ in [.parser_blocking, .after_parsing] {
		script.ready_to_be_parser_executed_ = true
		if document := script.preparation_time_document_ {
			document.schedule_html_parser_end_check()
		}
		return
	}
	if script.scheduling_ == .asap && script.element_ != none {
		if document := script.preparation_time_document_ {
			if script.execution_queued_ { return }
			script.execution_queued_ = true
			model := voidptr(script)
			queue_a_task(.networking, main_thread_event_loop(), document, fn [model] () {
				mut ready := unsafe { &HTMLScriptElementModel(model) }
				ready.execution_queued_ = false
				ready.execute_script()
			})
			return
		}
	}
	script.execute_script()
}

fn (mut script HTMLScriptElementModel) finish_execution() {
	script.stop_delaying_document_load_event()
	if owner := script.preparation_time_document_ {
		mut document := unsafe { &dom.Document(owner) }
		if script.scheduling_ == .asap {
			if element := script.element_ { document.remove_script_to_execute_as_soon_as_possible(element) }
		}
		document.schedule_html_parser_end_check()
	}
}

pub fn (mut script HTMLScriptElementModel) prepare_script_text() {
	if element := script.element_ {
		child_text := script_dom_element(element).as_node().child_text_content()
		if script.text_ != child_text {
			script.text_ = child_text
		}
	}
}

pub fn (mut script HTMLScriptElementModel) begin_delaying_document_load_event(document &dom.Document) {
	if mut delayer := script.document_load_event_delayer_ {
		delayer.finish()
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	script.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut mutable_document)
	script.document_load_event_delaying_ = true
}

pub fn (mut script HTMLScriptElementModel) stop_delaying_document_load_event() {
	if mut delayer := script.document_load_event_delayer_ {
		delayer.finish()
	}
	script.document_load_event_delayer_ = none
	script.document_load_event_delaying_ = false
}

pub fn (mut script HTMLScriptElementModel) adopted_from(_ &dom.Document) {
	element := script.element_ or { return }
	new_document := script_dom_element(element).document()
	script.base_url_ = new_document.base_url()
	mut was_delaying := false
	if mut delayer := script.document_load_event_delayer_ {
		delayer.finish()
		was_delaying = true
	}
	if was_delaying {
		mut mutable_new_document := unsafe { &dom.Document(new_document) }
		script.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut mutable_new_document)
		script.document_load_event_delaying_ = true
	}
}

pub fn (mut script HTMLScriptElementModel) execute_script() {
	if !script.script_ready_ || script.executed_ { return }
	if !script.belongs_to_preparation_document() {
		script.cancel_external_fetch()
		return
	}
	mut allocations := enter_html_document_storage(script.preparation_time_document_)
	defer { allocations.finish() }
	if document := script.preparation_time_document_ {
		assert document.document_ready_to_run_scripts()
	}
	script.executed_ = true
	script.ready_to_be_parser_executed_ = false
	defer { script.finish_execution() }
	if script.script_type_ == .import_map {
		mut result := script.import_map_result_ or { return }
		mut target := &script.registered_import_map_
		mut resolved := []ResolvedModuleRecord{}
		if document := script.preparation_time_document_ {
			if document.relevant_settings_object() != unsafe { nil } {
				settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
				target = unsafe { &ImportMap(settings.universal_global_scope().import_map()) }
				resolved = settings.resolved_module_set()
			}
		}
		result.register_import_map(mut target, resolved, fn (_ string) {}) or {
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

	script.execute_source(source) or {
		script.failed_to_load_ = true
		script.fire_event('error')
		return
	}
	// An element-aware module host owns graph evaluation and its eventual
	// completion event; classic evaluation has finished when the hook returns.
	if script.from_external_file_ && !(script.script_type_ == .module
		&& script.execute_hook_with_element_ != none) {
		script.fire_event('load')
	}
}

fn (script &HTMLScriptElementModel) execute_source(source string) ! {
	if owner := script.preparation_time_document_ {
		mut document := unsafe { &dom.Document(owner) }
		previous := document.current_script()
		document.set_current_script(none)
		if script.script_type_ == .classic {
			if element := script.element_ {
				if !script_dom_element(element).as_node().root().is_shadow_root() {
					document.set_current_script(script_dom_element(element))
				}
			}
		}
		ignore_destructive_writes := script.from_external_file_ || script.script_type_ == .module
		if ignore_destructive_writes { document.increment_ignore_destructive_writes_counter() }
		defer {
			document.set_current_script(previous)
			if ignore_destructive_writes { document.decrement_ignore_destructive_writes_counter() }
		}
		script.invoke_execute_hook(source)!
		return
	}
	script.invoke_execute_hook(source)!
}

fn (script &HTMLScriptElementModel) invoke_execute_hook(source string) ! {
	source_url := script.script_url_ or { script.base_url_ }
	if execute := script.execute_hook_with_element_ {
		if element := script.element_ {
			execute(element, script.script_type_, source, source_url)!
			return
		}
	}
	if execute := script.execute_hook_ {
		execute(script.script_type_, source, source_url)!
		return
	}
	if document := script.preparation_time_document_ {
		element := if owner := script.element_ { ?&dom.Element(script_dom_element(owner)) } else { none }
		_ = execute_bound_script_element(document, script.script_type_, source, int(script.source_line_number_), element)!
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
	if document := script.preparation_time_document_ {
		if document.relevant_settings_object() != unsafe { nil } {
			settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
			return settings.universal_global_scope().import_map()
		}
	}
	return &script.registered_import_map_
}

pub fn (script &HTMLScriptElementModel) is_implicitly_potentially_render_blocking() bool {
	defer_attribute := if element := script.element_ {
		script_dom_element(element).has_attribute('defer')
	} else {
		false
	}
	return script.script_type_ == .classic && script.is_parser_inserted() && !script.async_attribute_ && !defer_attribute
}

pub fn html_script_element_attribute_changed(element &dom.HTMLScriptElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := script_dom_element(element)
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if !dom_element.document().is_scripting_enabled_by_embedder() {
		return
	}
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	if name == 'crossorigin' {
		model.crossorigin_ = cors_setting_attribute_from_keyword(value)
	} else if name == 'referrerpolicy' {
		model.referrer_policy_ = ascii_lowercase_string(value or { '' })
	} else if name == 'src' {
		if namespace_ != none || value == none {
			return
		}
		model.src_ = value
		if dom_element.as_node().is_connected() {
			html_script_element_post_connection(element)
		}
	} else if name == 'async' && value != none {
		model.force_async_ = false
		model.async_attribute_ = true
	} else if name == 'async' {
		model.async_attribute_ = false
	} else if name == 'type' {
		model.type_attribute_ = value
	} else if name == 'language' {
		model.language_attribute_ = value
	} else if name == 'nomodule' {
		model.nomodule_ = value != none
	}
}

pub fn html_script_element_prepare_script_text(element &dom.HTMLScriptElement) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.prepare_script_text()
}

pub fn html_script_element_begin_delaying_document_load_event(element &dom.HTMLScriptElement, document &dom.Document) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.begin_delaying_document_load_event(document)
}

pub fn html_script_element_prepare_script(element &dom.HTMLScriptElement) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.prepare_script(script_dom_element(element).document())
}

pub fn html_script_element_execute_script(element &dom.HTMLScriptElement) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.execute_script()
}

pub fn html_script_element_is_ready_to_be_parser_executed(element &dom.HTMLScriptElement) bool {
	model := html_script_element_model_for_dom_element(element)
	return model.is_ready_to_be_parser_executed()
}

pub fn html_script_element_parser_execute_ready_script(element &dom.HTMLScriptElement) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.parser_execute_ready_script()
}

pub fn html_script_element_children_changed(element &dom.HTMLScriptElement, metadata dom.ChildrenChangedMetadata) {
	mut dom_element := script_dom_element(element)
	dom_element.children_changed(metadata)
	if metadata.type_ != .inserted || !dom_element.as_node().is_connected() {
		return
	}
	html_script_element_post_connection(element)
}

pub fn html_script_element_post_connection(element &dom.HTMLScriptElement) {
	if !script_dom_element(element).document().is_scripting_enabled_by_embedder() {
		return
	}
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	if model.is_parser_inserted() {
		return
	}
	model.set_connected(script_dom_element(element).as_node().is_connected())
	model.prepare_script(script_dom_element(element).document())
}

pub fn html_script_element_src(element &dom.HTMLScriptElement) string {
	dom_element := script_dom_element(element)
	raw := dom_element.get_attribute('src') or { return '' }
	return dom_element.document().encoding_parse_and_serialize_url(raw) or { return '' }
}

pub fn set_html_script_element_src(element &dom.HTMLScriptElement, value string) {
	mut dom_element := script_dom_element(element)
	old_value := dom_element.get_attribute('src')
	dom_element.set_attribute_value('src', value)
	html_script_element_attribute_changed(element, 'src', old_value, value, none)
}

pub fn html_script_element_text(element &dom.HTMLScriptElement) string {
	return script_dom_element(element).as_node().child_text_content()
}

pub fn set_html_script_element_text(element &dom.HTMLScriptElement, value string) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.text_ = value
	mut node := script_dom_element(element).as_node()
	node.string_replace_all(value)
}

pub fn html_script_element_text_content(element &dom.HTMLScriptElement) string {
	return script_dom_element(element).as_node().descendant_text_content()
}

pub fn html_script_element_set_text_content(element &dom.HTMLScriptElement, value string) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.text_ = value
	mut node := script_dom_element(element).as_node()
	node.string_replace_all(value)
}

pub fn html_script_element_inner_text(element &dom.HTMLScriptElement) string {
	return html_element_get_the_text_steps(unsafe { &dom.HTMLElement(element) })
}

pub fn html_script_element_set_inner_text(element &dom.HTMLScriptElement, value string) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.text_ = value
	mut dom_element := script_dom_element(element)
	dom_element.set_inner_text(value)
}

pub fn html_script_element_async(element &dom.HTMLScriptElement) bool {
	model := html_script_element_model_for_dom_element(element)
	return model.force_async_ || script_dom_element(element).has_attribute('async')
}

pub fn set_html_script_element_async(element &dom.HTMLScriptElement, async_ bool) {
	mut model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(element)) }
	model.force_async_ = false
	mut dom_element := script_dom_element(element)
	if async_ {
		dom_element.set_attribute_value('async', '')
		model.async_attribute_ = true
	} else {
		dom_element.remove_attribute('async')
		model.async_attribute_ = false
	}
}

pub fn html_script_element_cloned(element &dom.HTMLScriptElement, copy &dom.Node, subtree bool) ! {
	script_dom_element(element).as_node().cloned(copy, subtree)!
	copy_element := copy.as_element() or { return }
	if copy_element.local_name() != 'script' {
		return
	}
	copy_script := unsafe { &dom.HTMLScriptElement(copy_element) }
	mut copy_model := unsafe { &HTMLScriptElementModel(html_script_element_model_for_dom_element(copy_script)) }
	model := html_script_element_model_for_dom_element(element)
	copy_model.already_started_ = model.already_started_
}

pub fn html_script_element_is_implicitly_potentially_render_blocking(element &dom.HTMLScriptElement) bool {
	model := html_script_element_model_for_dom_element(element)
	return model.script_type_ == .classic && model.is_parser_inserted() && !script_dom_element(element).has_attribute('async') && !script_dom_element(element).has_attribute('defer')
}
