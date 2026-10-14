module main

import browserjs
import dom
import css
import strconv
import x.json2

@[heap]
struct CompactElementQueryBinding {
	document &dom.Document
	runtime  &browserjs.Runtime
mut:
	elements map[string]&dom.Element
	keys     map[voidptr]string
	next_key int
}

// Retain native node identity across insertions instead of serializing each
// ancestor's complete subtree into the compact script bridge's initial state.
fn install_compact_element_content_binding(document &dom.Document, mut runtime browserjs.Runtime) ! {
	elements := css.query_selector_all(unsafe { &dom.Node(document) }, '*')
	mut binding := &CompactElementQueryBinding{
		document: document
		runtime:  &runtime
	}
	for index, element in elements {
		key := '__element_${index}'
		binding.elements[key] = element
		binding.keys[voidptr(element)] = key
	}
	runtime.add_canvas_element_provider_with_lookup(fn [binding] () map[string]&dom.Element {
		return binding.elements.clone()
	}, fn [binding] (key string) ?&dom.Element {
		return binding.elements[key] or { return none }
	})
	runtime.define_host_function('__ladybirdReadElementContent', fn [elements, binding] (input string) !string {
		parts := input.split(':')
		if parts.len != 2 {
			return error('Invalid element content request')
		}
		element := binding.elements[parts[0]] or {
			index := strconv.atoi(parts[0])!
			if index < 0 || index >= elements.len {
				return error('Invalid element content index')
			}
			elements[index]
		}
		return match parts[1] {
			'textContent' { element.as_node().text_content() or { '' } }
			'innerHTML' { element.inner_html() or { '' } }
			else { return error('Invalid element content property') }
		}
	})!
	runtime.define_host_function('__ladybirdElementQuery', fn [binding] (input string) !string {
		mut mutable_binding := unsafe { &CompactElementQueryBinding(binding) }
		return mutable_binding.query(input)
	})!
}

fn (mut binding CompactElementQueryBinding) element_state(element &dom.Element) json2.Any {
	if key := binding.keys[voidptr(element)] {
		return json2.Any({
			'bridgeKey': json2.Any(key)
		})
	}
	binding.next_key++
	key := '__query_${binding.next_key}'
	binding.keys[voidptr(element)] = key
	binding.elements[key] = element
	mut attributes := map[string]json2.Any{}
	for name in element.get_attribute_names() {
		attributes[name] = json2.Any(element.get_attribute_value(name))
	}
	return json2.Any({
		'bridgeKey':    json2.Any(key)
		'elementIndex': json2.Any(-1)
		'tagName':      json2.Any(element.local_name())
		'namespaceURI': json2.Any(element.namespace_uri() or { '' })
		'attributes':   json2.Any(attributes)
		'id':           json2.Any(element.get_attribute_value('id'))
		'src':          json2.Any(element.get_attribute_value('src'))
		'width':        json2.Any(element.get_attribute_value('width'))
		'height':       json2.Any(element.get_attribute_value('height'))
		'className':    json2.Any(element.get_attribute_value('class'))
		'styleText':    json2.Any(element.get_attribute_value('style'))
		'onclick':      json2.Any(element.get_attribute_value('onclick'))
		'hasChildren':  json2.Any(element.as_node().has_children())
		'disabled':     json2.Any(element.has_attribute('disabled'))
	})
}

fn (mut binding CompactElementQueryBinding) query(input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	if snapshot := json_string_property(request, 'snapshot') {
		mut messages := []string{}
		apply_javascript_state(binding.document, snapshot,
			binding.runtime.canvas_elements_for_binding(), mut messages)
		// Console output stays in the script snapshot for its normal consumer;
		// only DOM replay failures can reject this selector operation.
		mut log_count := json_int_property(request, 'logCount') or { 0 }
		if log_count < 0 { log_count = 0 }
		if log_count > messages.len { log_count = messages.len }
		if messages.len > log_count {
			return error(messages[..messages.len - log_count].join('\n'))
		}
		for key, element in binding.runtime.canvas_elements_for_binding() {
			binding.elements[key] = element
			binding.keys[voidptr(element)] = key
		}
	}
	selector := json_string_property(request, 'selector') or {
		return error('Invalid selector request')
	}
	action := json_string_property(request, 'action') or { return error('Invalid selector action') }
	key := json_string_property(request, 'key') or { '' }
	root := if key == '' {
		unsafe { &dom.Node(binding.document) }
	} else {
		element := binding.elements[key] or {
			binding.runtime.canvas_element_for_binding(key) or {
				return error('TypeError: Invalid Element receiver')
			}
		}
		binding.elements[key] = element
		binding.keys[voidptr(element)] = key
		element.as_node()
	}
	if action == 'getElementById' {
		return if element := binding.document.get_element_by_id(selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	css.install_document_selector_query_hook(binding.document)
	// Use the DOM entry point for validation, preserving its SyntaxError before
	// queries that otherwise return no matches for an invalid selector.
	validation_element := root.as_element() or {
		binding.document.document_element() or { return error('Invalid selector document') }
	}
	matched := validation_element.matches(selector)!
	if action == 'matches' { return json2.encode(matched) }
	if action == 'closest' {
		return if element := validation_element.closest(selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'querySelector' {
		return if element := css.query_selector(root, selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'querySelectorAll' {
		mut result := []json2.Any{}
		for element in css.query_selector_all(root, selector) {
			result << binding.element_state(element)
		}
		return json2.encode(result)
	}
	return error('Invalid selector action')
}
