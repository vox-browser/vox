// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Contexts, ElementReference, and ElementLocationStrategies.
module webdriver

import math
import x.json2

pub const web_element_identifier = 'element-6066-11e4-a52e-4f735466cecf'
pub const shadow_root_identifier = 'shadow-6066-11e4-a52e-4f735466cecf'
pub const web_window_identifier = 'window-fcc6-11e5-b4f8-330a88ab9d7f'
pub const web_frame_identifier = 'frame-075b-4da1-b6ba-e579c2d3230a'

pub struct Rect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct ElementRecord {
pub:
	node_id                 string
	document_id             string
	tag_name                string
	text                    string
	attributes              map[string]string
	connected               bool = true
	rect                    Rect
	disabled                bool
	read_only               bool
	input_type              string = 'text'
	content_editable        bool
	obscured                bool
	focusable               bool
	visible                 bool = true
	visible_for_hit_testing bool = true
	shadow_id               ?string
}

pub struct ShadowRootRecord {
pub:
	node_id        string
	document_id    string
	connected      bool = true
	host_connected bool = true
}

pub struct BrowsingContext {
pub:
	handle      string
	group_id    string
	document_id string
	open        bool = true
	top_level   bool = true
	viewport    Rect
}

pub struct ReferenceStore {
pub mut:
	next_id              u64
	elements             map[string]ElementRecord
	shadows              map[string]ShadowRootRecord
	node_references      map[string]string
	reference_groups     map[string]string
	seen_node_references map[string][]string
}

fn reference_node_key(context BrowsingContext, node_id string) string {
	return '${context.group_id}\x1f${node_id}'
}

fn reference_navigable_key(context BrowsingContext) string {
	return '${context.group_id}\x1f${context.handle}'
}

fn (mut store ReferenceStore) record_node_reference(context BrowsingContext, node_id string, prefix string) string {
	key := reference_node_key(context, node_id)
	if reference := store.node_references[key] {
		return reference
	}
	store.next_id++
	reference := '${prefix}-${store.next_id}'
	store.node_references[key] = reference
	store.reference_groups[reference] = context.group_id
	navigable_key := reference_navigable_key(context)
	mut seen := store.seen_node_references[navigable_key] or { []string{} }
	seen << reference
	store.seen_node_references[navigable_key] = seen
	return reference
}

pub fn (mut store ReferenceStore) element_reference(context BrowsingContext, element ElementRecord) string {
	reference := store.record_node_reference(context, element.node_id, 'element')
	store.elements[reference] = element
	return reference
}

pub fn (mut store ReferenceStore) shadow_reference(context BrowsingContext, root ShadowRootRecord) string {
	reference := store.record_node_reference(context, root.node_id, 'shadow')
	store.shadows[reference] = root
	return reference
}

pub fn element_reference_object(reference string) map[string]json2.Any {
	return {
		web_element_identifier: reference
	}
}

pub fn shadow_reference_object(reference string) map[string]json2.Any {
	return {
		shadow_root_identifier: reference
	}
}

pub fn window_reference_object(handle string) map[string]json2.Any {
	return {
		web_window_identifier: handle
	}
}

pub fn frame_reference_object(handle string) map[string]json2.Any {
	return {
		web_frame_identifier: handle
	}
}

pub fn represents_web_window(value json2.Any) bool {
	if value !is map[string]json2.Any {
		return false
	}
	return web_window_identifier in (value as map[string]json2.Any)
}

pub fn represents_web_frame(value json2.Any) bool {
	if value !is map[string]json2.Any {
		return false
	}
	return web_frame_identifier in (value as map[string]json2.Any)
}

pub fn deserialize_web_window(value json2.Any, contexts []BrowsingContext) !BrowsingContext {
	if !represents_web_window(value) {
		return error(WebDriverError.from_code(.invalid_argument, 'Object is not a web window reference').msg())
	}
	object := value as map[string]json2.Any
	handle_value := object[web_window_identifier] or {
		return error(WebDriverError.from_code(.invalid_argument, 'Window handle is missing').msg())
	}
	if handle_value !is string {
		return error(WebDriverError.from_code(.invalid_argument, 'Object is not a web window reference').msg())
	}
	handle := handle_value as string
	for context in contexts {
		if context.top_level && context.handle == handle {
			return context
		}
	}
	return error(WebDriverError.from_code(.no_such_window, 'Window handle was not found').msg())
}

pub fn deserialize_web_frame(value json2.Any, contexts []BrowsingContext) !BrowsingContext {
	if !represents_web_frame(value) {
		return error(WebDriverError.from_code(.invalid_argument, 'Object is not a web frame reference').msg())
	}
	object := value as map[string]json2.Any
	handle_value := object[web_frame_identifier] or {
		return error(WebDriverError.from_code(.invalid_argument, 'Frame handle is missing').msg())
	}
	if handle_value !is string {
		return error(WebDriverError.from_code(.invalid_argument, 'Object is not a web frame reference').msg())
	}
	handle := handle_value as string
	for context in contexts {
		if !context.top_level && context.handle == handle {
			return context
		}
	}
	return error(WebDriverError.from_code(.no_such_frame, 'Frame handle was not found').msg())
}

pub fn represents_web_element(value json2.Any) bool {
	if value !is map[string]json2.Any {
		return false
	}
	return web_element_identifier in (value as map[string]json2.Any)
}

pub fn represents_shadow_root(value json2.Any) bool {
	if value !is map[string]json2.Any {
		return false
	}
	return shadow_root_identifier in (value as map[string]json2.Any)
}

pub fn get_known_element(store ReferenceStore, context BrowsingContext, reference string) !ElementRecord {
	seen := store.seen_node_references[reference_navigable_key(context)] or { []string{} }
	if reference !in seen {
		return error(WebDriverError.from_code(.no_such_element, 'Element reference is not known').msg())
	}
	element := store.elements[reference] or {
		return error(WebDriverError.from_code(.stale_element_reference, 'Element is stale').msg())
	}
	if !element.connected || element.document_id != context.document_id {
		return error(WebDriverError.from_code(.stale_element_reference, 'Element is stale').msg())
	}
	return element
}

pub fn get_known_shadow_root(store ReferenceStore, context BrowsingContext, reference string) !ShadowRootRecord {
	seen := store.seen_node_references[reference_navigable_key(context)] or { []string{} }
	if reference !in seen {
		return error(WebDriverError.from_code(.no_such_shadow_root, 'Shadow root reference is not known').msg())
	}
	root := store.shadows[reference] or {
		return error(WebDriverError.from_code(.detached_shadow_root, 'Shadow root is detached').msg())
	}
	if !root.connected || !root.host_connected || root.document_id != context.document_id {
		return error(WebDriverError.from_code(.detached_shadow_root, 'Shadow root is detached').msg())
	}
	return root
}

pub fn ensure_browsing_context_is_open(context ?BrowsingContext) ! {
	if actual := context {
		if actual.open {
			return
		}
	}
	return error(WebDriverError.from_code(.no_such_window, 'Browsing context is no longer open').msg())
}

pub fn in_view_center_point(element Rect, viewport Rect) (f64, f64) {
	left := math.max(0.0, math.min(element.x, element.x + element.width))
	right := math.min(viewport.width, math.max(element.x, element.x + element.width))
	top := math.max(0.0, math.min(element.y, element.y + element.height))
	bottom := math.min(viewport.height, math.max(element.y, element.y + element.height))
	return math.floor((left + right) / 2.0), math.floor((top + bottom) / 2.0)
}

pub fn is_element_pointer_interactable(element ElementRecord, context BrowsingContext) bool {
	if !element.connected || element.obscured || element.rect.width <= 0 || element.rect.height <= 0 {
		return false
	}
	x, y := in_view_center_point(element.rect, context.viewport)
	return x >= context.viewport.x && x <= context.viewport.x + context.viewport.width && y >= context.viewport.y && y <= context.viewport.y + context.viewport.height
}

pub fn is_element_in_view(element ElementRecord, context BrowsingContext) bool {
	if !element.connected || element.rect.width == 0 || element.rect.height == 0 {
		return false
	}
	x, y := in_view_center_point(element.rect, context.viewport)
	return x >= context.viewport.x && x <= context.viewport.x + context.viewport.width && y >= context.viewport.y && y <= context.viewport.y + context.viewport.height
}

pub fn is_element_obscured(element ElementRecord) bool {
	return element.obscured
}

pub fn is_element_keyboard_interactable(element ElementRecord) bool {
	return element.focusable || element.tag_name in ['body', 'html']
}

pub fn is_element_interactable(element ElementRecord, context BrowsingContext) bool {
	return is_element_pointer_interactable(element, context) || is_element_keyboard_interactable(element)
}

pub fn is_element_editable(element ElementRecord) bool {
	return is_element_mutable_form_control(element) || is_element_mutable(element)
}

pub fn is_element_mutable(element ElementRecord) bool {
	return element.content_editable
}

pub fn is_element_mutable_form_control(element ElementRecord) bool {
	if element.tag_name.to_lower() == 'textarea' {
		return !element.disabled
	}
	if element.tag_name.to_lower() != 'input' || element.disabled || element.read_only {
		return false
	}
	return element.input_type.to_lower() in [
		'text',
		'search',
		'url',
		'tel',
		'email',
		'password',
		'date',
		'month',
		'week',
		'time',
		'datetime-local',
		'number',
		'range',
		'color',
		'file',
	]
}

pub fn is_element_non_typeable_form_control(element ElementRecord) bool {
	return element.tag_name.to_lower() == 'input' && element.input_type.to_lower() in [
		'hidden',
		'range',
		'color',
		'checkbox',
		'radio',
		'file',
		'submit',
		'image',
		'reset',
		'button',
	]
}

pub enum LocationStrategy {
	css_selector
	link_text
	partial_link_text
	tag_name
	xpath
}

pub fn location_strategy_from_string(value string) ?LocationStrategy {
	return match value {
		'css selector' { .css_selector }
		'link text' { .link_text }
		'partial link text' { .partial_link_text }
		'tag name' { .tag_name }
		'xpath' { .xpath }
		else { none }
	}
}

fn simple_css_match(element ElementRecord, selector string) !bool {
	if selector.len == 0 || (selector.contains('[') && !selector.ends_with(']')) {
		return error(WebDriverError.from_code(.invalid_selector, 'querySelectorAll() failed').msg())
	}
	if selector.starts_with('#') {
		return element.attributes['id'] or { '' } == selector[1..]
	}
	if selector.starts_with('.') {
		return selector[1..] in (element.attributes['class'] or { '' }).split(' ')
	}
	return element.tag_name.to_lower() == selector.to_lower()
}

pub fn invoke_location_strategy(strategy LocationStrategy, elements []ElementRecord, selector string) ![]ElementRecord {
	if strategy == .xpath {
		return error(WebDriverError.from_code(.unsupported_operation, 'Not implemented: locate element by XPath').msg())
	}
	mut result := []ElementRecord{}
	for element in elements {
		matches := match strategy {
			.css_selector { simple_css_match(element, selector)! }
			.link_text { element.tag_name == 'a' && element.text.trim_space() == selector }
			.partial_link_text { element.tag_name == 'a' && element.text.contains(selector) }
			.tag_name { element.tag_name.to_lower() == selector.to_lower() }
			.xpath { false }
		}
		if matches { result << element }
	}
	return result
}
