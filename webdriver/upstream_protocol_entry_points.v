// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Upstream-named protocol entry-points. Browser-owned objects are represented
// by the typed records in this module; each adapter delegates to the same
// validation, reference, serialization, and dispatch implementations used by
// the public portable API.
module webdriver

import x.json2

__global webdriver_default_interface_mode InterfaceMode
__global webdriver_has_proxy_configuration = true
__global webdriver_user_prompt_state UserPromptState

pub fn page_load_strategy_from_string(value string) ?PageLoadStrategy {
	return match value {
		'none' { .none }
		'eager' { .eager }
		'normal' { .normal }
		else { none }
	}
}

pub fn deserialize_as_a_page_load_strategy(value json2.Any) Response {
	if value !is string || page_load_strategy_from_string(value as string) == none {
		return failure(.invalid_argument, 'Invalid pageLoadStrategy')
	}
	return success(value)
}

pub fn set_default_interface_mode(mode InterfaceMode) {
	webdriver_default_interface_mode = mode
}

pub fn deserialize_as_ladybird_capability(name string, value json2.Any) Response {
	validated := validate_capability(name, value) or {
		return failure(.invalid_argument, err.msg())
	}
	return success(validated)
}

pub fn set_default_ladybird_capabilities(mut options map[string]json2.Any) {
	if 'ladybird:headless' !in options {
		options['ladybird:headless'] = webdriver_default_interface_mode == .headless
	}
}

pub fn matches_browser_version(requested string, required string) bool {
	return requested == required
}

pub fn matches_platform_name(requested string, required string) bool {
	return platform_matches(requested, required)
}

pub fn window_proxy_reference_object(context BrowsingContext) map[string]json2.Any {
	return if context.top_level {
		window_reference_object(context.handle)
	} else {
		frame_reference_object(context.handle)
	}
}

pub fn find_navigable_with_handle(contexts []BrowsingContext, handle string, should_be_top_level bool) ?BrowsingContext {
	for context in contexts {
		if context.handle == handle && context.top_level == should_be_top_level {
			return context
		}
	}
	return none
}

pub fn represents_a_web_frame(value json2.Any) bool {
	return represents_web_frame(value)
}

pub fn represents_a_web_window(value json2.Any) bool {
	return represents_web_window(value)
}

pub fn locate_element_by_css_selector(elements []ElementRecord, selector string) ![]ElementRecord {
	return invoke_location_strategy(.css_selector, elements, selector)
}

pub fn locate_element_by_link_text(elements []ElementRecord, selector string) ![]ElementRecord {
	return invoke_location_strategy(.link_text, elements, selector)
}

pub fn locate_element_by_partial_link_text(elements []ElementRecord, selector string) ![]ElementRecord {
	return invoke_location_strategy(.partial_link_text, elements, selector)
}

pub fn locate_element_by_tag_name(elements []ElementRecord, selector string) []ElementRecord {
	return invoke_location_strategy(.tag_name, elements, selector) or { []ElementRecord{} }
}

pub fn locate_element_by_x_path(elements []ElementRecord, selector string) ![]ElementRecord {
	return invoke_location_strategy(.xpath, elements, selector)
}

pub fn get_node(store ReferenceStore, context BrowsingContext, reference string) ?ElementRecord {
	element := store.elements[reference] or { return none }
	if element.document_id != context.document_id {
		return none
	}
	return element
}

pub fn get_or_create_a_node_reference(mut store ReferenceStore, element ElementRecord) string {
	return store.element_reference(element)
}

pub fn node_reference_is_known(store ReferenceStore, context BrowsingContext, reference string) bool {
	return get_node(store, context, reference) != none
}

pub fn get_or_create_a_web_element_reference(mut store ReferenceStore, element ElementRecord) string {
	return store.element_reference(element)
}

pub fn web_element_reference_object(mut store ReferenceStore, element ElementRecord) map[string]json2.Any {
	return element_reference_object(store.element_reference(element))
}

pub fn represents_a_web_element(value json2.Any) bool {
	return represents_web_element(value)
}

pub fn deserialize_web_element(store ReferenceStore, context BrowsingContext, value json2.Any) !ElementRecord {
	if !represents_web_element(value) {
		return error(WebDriverError.from_code(.invalid_argument,
			'Object is not a web element reference').msg())
	}
	reference := extract_web_element_reference(value as map[string]json2.Any)!
	return get_known_element(store, context, reference)
}

pub fn extract_web_element_reference(object map[string]json2.Any) !string {
	return string_property(object, web_element_identifier)
}

pub fn get_web_element_origin(store ReferenceStore, context BrowsingContext, origin string) !ElementRecord {
	return get_known_element(store, context, origin)
}

pub fn is_element_stale(element ElementRecord, context BrowsingContext) bool {
	return !element.connected || element.document_id != context.document_id
}

pub fn pointer_interactable_tree(elements []ElementRecord, context BrowsingContext) []ElementRecord {
	return elements.filter(is_element_pointer_interactable(it, context))
}

pub fn get_or_create_a_shadow_root_reference(mut store ReferenceStore, root ShadowRootRecord) string {
	return store.shadow_reference(root)
}

pub fn shadow_root_reference_object(mut store ReferenceStore, root ShadowRootRecord) map[string]json2.Any {
	return webdriver.shadow_reference_object(store.shadow_reference(root))
}

pub fn represents_a_shadow_root(value json2.Any) bool {
	return represents_shadow_root(value)
}

pub fn deserialize_shadow_root(store ReferenceStore, context BrowsingContext, value json2.Any) !ShadowRootRecord {
	if !represents_shadow_root(value) {
		return error(WebDriverError.from_code(.invalid_argument,
			'Object is not a shadow root reference').msg())
	}
	object := value as map[string]json2.Any
	reference := string_property(object, shadow_root_identifier)!
	return get_known_shadow_root(store, context, reference)
}

pub fn is_shadow_root_detached(root ShadowRootRecord, context BrowsingContext) bool {
	return !root.connected || root.document_id != context.document_id
}

pub fn element_rendered_text(element ElementRecord) string {
	return element.text.trim_space()
}

pub fn (timer &HeapTimer) is_timed_out() bool {
	return timer.fired
}

pub fn input_source_type(source InputSource) InputSourceType {
	return source.type_
}

pub fn get_pointer_id(source InputSource) u32 {
	return source.pointer_id
}

pub fn (state GlobalKeyState) modifiers() u32 {
	mut modifiers := u32(0)
	if state.alt_key { modifiers |= 1 }
	if state.ctrl_key { modifiers |= 2 }
	if state.meta_key { modifiers |= 4 }
	if state.shift_key { modifiers |= 8 }
	return modifiers
}

pub fn pointer_input_source_subtype_from_string(value string) ?PointerSubtype {
	return pointer_subtype_from_string(value)
}

pub fn add_input_source(mut state InputState, id string, source InputSource) {
	state.input_state_map[id] = source
}

pub fn get_input_source(state InputState, id string) ?InputSource {
	return state.input_state_map[id]
}

pub fn get_global_key_state(state InputState) GlobalKeyState {
	return state.global_key_state()
}

pub fn get_input_state(state InputState) InputState {
	return state
}

pub fn reset_input_state(mut state InputState) {
	state.input_state_map.clear()
	state.input_cancel_list.clear()
	state.actions_queue.clear()
}

pub fn is_collection(value json2.Any) bool {
	return value is []json2.Any || value is map[string]json2.Any
}

pub fn json_object_to_js_object(value map[string]json2.Any) !map[string]json2.Any {
	cloned := json_clone(json2.Any(value))!
	return cloned as map[string]json2.Any
}

pub fn json_array_to_js_array(value []json2.Any) ![]json2.Any {
	cloned := json_clone(json2.Any(value))!
	return cloned as []json2.Any
}

pub fn json_value_to_js_value(value json2.Any) !json2.Any {
	return json_clone(value)
}

pub fn clone_an_object(value map[string]json2.Any) !map[string]json2.Any {
	return json_object_to_js_object(value)
}

pub fn internal_json_clone(value json2.Any) !json2.Any {
	return json_clone(value)
}

pub fn internal_json_deserialize(value json2.Any) !json2.Any {
	return json_deserialize(value)
}

pub fn get_optional_property(object map[string]json2.Any, key string) ?json2.Any {
	return object[key] or { none }
}

pub fn get_property_with_limits(object map[string]json2.Any, key string, minimum i64, maximum i64) !i64 {
	return integer_property_in_range(object, key, minimum, maximum)
}

pub struct OptionalLimitedInteger {
pub:
	value ?i64
}

pub fn get_optional_property_with_limits(object map[string]json2.Any, key string, minimum i64, maximum i64) !OptionalLimitedInteger {
	if key !in object {
		return OptionalLimitedInteger{}
	}
	return OptionalLimitedInteger{
		value: integer_property_in_range(object, key, minimum, maximum)!
	}
}

pub fn has_proxy_configuration() bool {
	return webdriver_has_proxy_configuration
}

pub fn set_has_proxy_configuration(value bool) {
	webdriver_has_proxy_configuration = value
}

pub fn reset_has_proxy_configuration() {
	webdriver_has_proxy_configuration = true
}

pub fn validate_proxy_item(key string, value json2.Any) ! {
	_ = deserialize_proxy(json2.Any({key: value}))!
}

pub fn deserialize_as_a_proxy(value json2.Any) !map[string]json2.Any {
	return deserialize_proxy(value)
}

pub fn timeouts_object(configuration TimeoutsConfiguration) map[string]json2.Any {
	return configuration.to_object()
}

pub fn json_deserialize_as_a_timeouts_configuration(value json2.Any) !TimeoutsConfiguration {
	return deserialize_timeouts(value)
}

pub fn json_deserialize_as_a_timeouts_configuration_into(value json2.Any, mut configuration TimeoutsConfiguration) ! {
	deserialize_timeouts_into(value, mut configuration)!
}

pub fn prompt_handler_from_string(value string) ?PromptHandler {
	return match value {
		'dismiss', 'dismiss and notify' { .dismiss }
		'accept', 'accept and notify' { .accept }
		'ignore' { .ignore }
		else { none }
	}
}

pub fn prompt_type_to_string(value PromptType) string {
	return match value {
		.alert { 'alert' }
		.before_unload { 'beforeUnload' }
		.confirm { 'confirm' }
		.default_ { 'default' }
		.file { 'file' }
		.prompt { 'prompt' }
		.fallback_default { 'fallbackDefault' }
	}
}

pub fn prompt_type_from_string(value string) ?PromptType {
	return prompt_type_from_name(value) or { none }
}

pub fn PromptHandlerConfiguration.deserialize(value json2.Any) !PromptHandlerConfiguration {
	if value !is string {
		return error(WebDriverError.from_code(.invalid_argument,
			'Prompt handler must be a string').msg())
	}
	return parse_prompt_configuration(value as string)
}

pub fn user_prompt_handler() ?map[PromptType]PromptHandlerConfiguration {
	return webdriver_user_prompt_state.handler
}

pub fn set_user_prompt_handler(value map[PromptType]PromptHandlerConfiguration) {
	webdriver_user_prompt_state.handler = value.clone()
}

pub fn deserialize_as_an_unhandled_prompt_behavior(value json2.Any) Response {
	handler := deserialize_unhandled_prompt_behavior(value) or {
		return failure(.invalid_argument, err.msg())
	}
	return success(serialize_user_prompt_handler(handler))
}

pub fn check_user_prompt_handler_matches(requested map[PromptType]PromptHandlerConfiguration) bool {
	return webdriver_user_prompt_state.matches(requested)
}

pub fn update_the_user_prompt_handler(requested map[PromptType]PromptHandlerConfiguration) {
	webdriver_user_prompt_state.update(requested)
}

pub fn serialize_the_user_prompt_handler() json2.Any {
	return webdriver_user_prompt_state.serialize()
}

pub fn draw_bounding_box_from_the_framebuffer(frame FramebufferImage, rect Rect) !FramebufferImage {
	return draw_bounding_box_from_framebuffer(frame, rect)
}
