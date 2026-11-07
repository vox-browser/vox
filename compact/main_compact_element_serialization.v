module main

import dom
import browserjs.querywire
import html
import platform
import strings
import x.json2

// Collection replies can hydrate thousands of wrappers at startup. Bridge keys
// and native models keep their document ownership; response bytes need only
// survive the host's string copy. Do not retain per-member JSON graphs.
fn (mut binding CompactElementQueryBinding) encode_element_states(elements []&dom.Element) string {
	return binding.encode_element_states_with_envelope(elements, '', '')
}

fn (mut binding CompactElementQueryBinding) encode_element_states_with_envelope(elements []&dom.Element,
	prefix string, suffix string) string {
	$if prealloc {
		if binding.document.native_storage() != unsafe { nil } {
			mut reply := platform.ThreadScratchScope{}
			if binding.temporary_reply_enabled {
				reply = platform.begin_thread_scratch('compact collection reply')
				binding.reply_workspace = reply
			}
			defer { reply.leave() }
			mut output := strings.new_builder(elements.len * 32 + 2)
			output.write_string(prefix)
			output.write_u8(`[`)
			for index, element in elements {
				if index > 0 { output.write_u8(`,`) }
				// These writes can grow retained identity maps. Keep them outside
				// the per-element workspace, as well as lazy control-model creation.
				mut retained := platform.enter_retained_allocations()
				key := binding.element_key(element)
				materialized := binding.materialized[key]
				if !materialized {
					binding.materialized[key] = true
					prepare_compact_element_serialization(element)
				}
				retained.finish()
				work := platform.begin_thread_scratch('compact collection element')
				encoded := if materialized {
					querywire.encode_identity_reply(key)
				} else {
					json2.encode(binding.initial_element_state(element, key))
				}
				work.leave()
				output.write_string(encoded)
				work.finish()
			}
			output.write_u8(`]`)
			output.write_string(suffix)
			return output.str()
		}
	}
	mut states := []json2.Any{cap: elements.len}
	for element in elements { states << binding.element_state(element) }
	return prefix + json2.encode(states) + suffix
}

fn prepare_compact_element_serialization(element &dom.Element) {
	if !element.is_html_element() { return }
	if element.local_name() == 'input' {
		_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	} else if element.local_name() == 'textarea' {
		_ = html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
	} else if element.local_name() == 'video' {
		_ = html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	} else if element.local_name() == 'img' {
		_ = html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	}
}
