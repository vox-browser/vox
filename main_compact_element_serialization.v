module main

import dom
import html
import platform
import strings
import x.json2

// Collection replies can hydrate thousands of wrappers at startup. Only the
// bridge keys, native models and final JSON string outlive serialization. Do
// not retain a complete graph of temporary maps for every collection member.
fn (mut binding CompactElementQueryBinding) encode_element_states(elements []&dom.Element) string {
	$if prealloc {
		if binding.document.native_storage() != unsafe { nil } {
			mut output := strings.new_builder(elements.len * 32 + 2)
			output.write_u8(`[`)
			for index, element in elements {
				if index > 0 { output.write_u8(`,`) }
				// These writes can grow retained identity maps. Keep them outside
				// the per-element workspace, as well as lazy control-model creation.
				key := binding.element_key(element)
				materialized := binding.materialized[key]
				if !materialized {
					binding.materialized[key] = true
					prepare_compact_element_serialization(element)
				}
				work := platform.begin_thread_scratch('compact collection element')
				state := if materialized {
					json2.Any({
						'bridgeKey': json2.Any(key)
					})
				} else {
					binding.initial_element_state(element, key)
				}
				encoded := json2.encode(state)
				work.leave()
				output.write_string(encoded)
				work.finish()
			}
			output.write_u8(`]`)
			return output.str()
		}
	}
	mut states := []json2.Any{cap: elements.len}
	for element in elements { states << binding.element_state(element) }
	return json2.encode(states)
}

fn prepare_compact_element_serialization(element &dom.Element) {
	if !element.is_html_element() { return }
	if element.local_name() == 'input' {
		_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	} else if element.local_name() == 'textarea' {
		_ = html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	} else if element.local_name() == 'video' {
		_ = html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	}
}
