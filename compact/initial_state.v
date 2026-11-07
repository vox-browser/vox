module main

import css
import browserjs
import dom
import html
import os
import url
import x.json2

enum CompactInitialElementPolicy {
	all_elements
	roots_and_ids
}

fn compact_initial_element_state_needed(element &dom.Element) bool {
	return element.get_attribute_value('id') != ''
		|| element.local_name() in ['html', 'head', 'body']
}

// The standalone snapshot adapter retains its complete metadata. A native
// query-backed realm seeds only roots and named globals; other owners are
// serialized on their first query, with their original stable bridge keys.
$if test {
	fn javascript_initial_state(document &dom.Document, current_url string, scripts []string) map[string]json2.Any {
		return javascript_initial_state_with_policy(document, current_url, scripts, .all_elements)
	}
}

fn javascript_initial_element_state(element &dom.Element, bridge_key string, element_index int,
	parent_key string, current_url string, native_parent bool) map[string]json2.Any {
	id := element.get_attribute_value('id')
	attribute_records, attributes := browserjs.compact_attribute_state(element)
	mut state := {
		'id':               json2.Any(id)
		'bridgeKey':        json2.Any(bridge_key)
		'elementIndex':     json2.Any(element_index)
		// A prefixed element reports its qualified name, as created ones do.
		'tagName':          json2.Any(if element.prefix() != none { element.qualified_name_str() } else { element.local_name() })
		'namespaceURI':     json2.Any(element.namespace_uri() or { '' })
		'attributes':       json2.Any(attributes)
		'attributeRecords': json2.Any(attribute_records)
		'src':              json2.Any(element.get_attribute_value('src'))
		'width':            json2.Any(element.get_attribute_value('width'))
		'height':           json2.Any(element.get_attribute_value('height'))
		'className':        json2.Any(element.get_attribute_value('class'))
		'styleText':        json2.Any(element.get_attribute_value('style'))
		'onclick':          json2.Any(element.get_attribute_value('onclick'))
		'hasChildren':      json2.Any(element.as_node().has_children())
		'disabled':         json2.Any(element.has_attribute('disabled'))
		'parentKey':        json2.Any(parent_key)
	}
	if element.is_html_element() && element.local_name() == 'select' {
		select_element := unsafe { &dom.HTMLSelectElement(element) }
		state['value'] = json2.Any(compact_select_value(select_element))
	}
	if element.is_html_element() && element.local_name() == 'option' {
		state['value'] = json2.Any(html.html_option_element_value(unsafe { &dom.HTMLOptionElement(element) }))
	}
	if element.is_html_element() && element.local_name() == 'video' {
		video := unsafe { &dom.HTMLVideoElement(element) }
		model := html.html_video_element_model_for_dom_element(video)
		if frame := model.current_decoded_image_frame() {
			bitmap := frame.bitmap()
			frame_state := bitmap_javascript_state(bitmap)
			state['readyState'] = json2.Any(2)
			state['videoWidth'] = frame_state['width'] or { json2.Any(0) }
			state['videoHeight'] = frame_state['height'] or { json2.Any(0) }
			state['videoPixels'] = frame_state['pixels'] or { json2.Any('') }
		}
	}
	if element.local_name() == 'img' {
		image := unsafe { &dom.HTMLImageElement(element) }
		source := element.get_attribute_value('src').trim_space()
		resolved_source := resolve_document_reference(source, current_url)
		// The compact host decodes data and local-file images at paint time,
		// outside HTMLImageElement's request object. They are nevertheless
		// synchronously available before this script snapshot is executed.
		host_image_complete := source.starts_with('data:')
			|| (resolved_source.starts_with('file://')
			&& os.is_file(url.percent_decode(resolved_source['file://'.len..]).bytestr()))
		state['complete'] = json2.Any(html.html_image_element_complete(image) || host_image_complete)
	}
	if element.local_name() == 'input' {
		input := unsafe { &dom.HTMLInputElement(element) }
		state['checked'] = json2.Any(input.checked())
		state['indeterminate'] = json2.Any(input.indeterminate())
	}
	if native_parent {
		state['nativeParent'] = json2.Any(true)
		if element.is_html_element() && element.local_name() == 'input' {
			state['value'] = json2.Any(html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).value())
		} else if element.is_html_element() && element.local_name() == 'textarea' {
			state['value'] = json2.Any(html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) }).value())
		}
	}
	return state
}

fn javascript_initial_state_with_policy(document &dom.Document, current_url string, scripts []string, policy CompactInitialElementPolicy) map[string]json2.Any {
	root := unsafe { &dom.Node(document) }
	all_elements := css.query_selector_all(root, '*')
	return javascript_initial_state_for_elements(document, current_url, scripts, policy, all_elements)
}

fn javascript_initial_state_for_elements(document &dom.Document, current_url string, scripts []string,
	policy CompactInitialElementPolicy, all_elements []&dom.Element) map[string]json2.Any {
	mut elements := map[string]json2.Any{}
	mut element_keys := map[voidptr]string{}
	for element_index, element in all_elements {
		element_keys[voidptr(element)] = '__element_${element_index}'
	}
	for element_index, element in all_elements {
		if policy == .roots_and_ids && !compact_initial_element_state_needed(element) { continue
		 }
		bridge_key := '__element_${element_index}'
		parent_key := if parent := element.as_node().parent_element() { element_keys[voidptr(parent)] or {
				''} } else { '' }
		elements[bridge_key] = json2.Any(javascript_initial_element_state(element, bridge_key,
			element_index, parent_key, current_url, policy == .roots_and_ids))
	}

	model := html.NavigableModel.navigable_with_active_document(document)
	return {
		'bodyHTMLDirty':                json2.Any(false)
		'bodyTextDirty':                json2.Any(false)
		'location':                     json2.Any(current_url)
		'navigate':                     json2.Any('')
		'logs':                         json2.Any([]json2.Any{})
		'operations':                   json2.Any([]json2.Any{})
		'elements':                     json2.Any(elements)
		'videoSources':                 json2.Any(javascript_video_source_states(current_url,
			scripts))
		'forceDarkEnabled':             json2.Any(if value := model {
			value.force_dark_enabled()
		} else {
			false
		})
		'forceDarkForegroundThreshold': json2.Any(if value := model {
			int(value.force_dark_foreground_threshold())
		} else {
			150
		})
		'forceDarkBackgroundThreshold': json2.Any(if value := model {
			int(value.force_dark_background_threshold())
		} else {
			205
		})
		'showLineBoxBorders':           json2.Any(false)
	}
}
