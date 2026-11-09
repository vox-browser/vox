module main

import dom
import platform
import trustedtypes
import x.json2

// Only the private, strict Trusted Types closure calls this native transport.
// Its type tag comes from the value's WeakMap brand, not from author JSON.
fn (mut binding CompactElementQueryBinding) set_trusted_attribute(key string, namespace ?string, name string, input trustedtypes.TrustedTypeOrString, namespaced bool, encoded_state string) !string {
	mut allocation := platform.RetainedArenaScope{}
	mut storage := binding.document.native_storage()
	if storage != unsafe { nil } { allocation = storage.enter_nested() }
	defer { allocation.finish() }
	owned_key := key.clone()
	state := if encoded_state == '' {
		json2.Any(json2.Null{})
	} else {
		json2.decode[json2.Any](compact_replay_json_text(encoded_state))!
	}
	mut node := binding.equality_node(owned_key, state)!
	mut element := node.as_element() or { return error('TypeError: Illegal Element receiver') }
	mut target_allocation := platform.RetainedArenaScope{}
	mut target_storage := element.document().native_storage()
	if target_storage != unsafe { nil } { target_allocation = target_storage.enter_nested() }
	defer { target_allocation.finish() }
	owned_namespace := if value := namespace { ?string(value.clone()) } else { none }
	owned_name := name.clone()
	owned_input := match input {
		string { trustedtypes.TrustedTypeOrString(input.clone()) }
		trustedtypes.TrustedHTML {
			trustedtypes.TrustedTypeOrString(trustedtypes.TrustedHTML{ data: input.data.clone() })
		}
		trustedtypes.TrustedScript {
			trustedtypes.TrustedTypeOrString(trustedtypes.TrustedScript{ data: input.data.clone() })
		}
		trustedtypes.TrustedScriptURL {
			trustedtypes.TrustedTypeOrString(trustedtypes.TrustedScriptURL{ data: input.data.clone() })
		}
	}
	mut hook_name := owned_name
	mut hook_namespace := ?string(none)
	if namespaced {
		extracted := dom.validate_and_extract(owned_namespace, owned_name, .attribute)!
		hook_name = extracted.local_name
		hook_namespace = extracted.namespace_
	} else {
		if element.is_html_element() && element.document().is_html_document() {
			hook_name = owned_name.bytes().map(if it >= `A` && it <= `Z` { it + u8(32) } else { it }).bytestr()
		}
		if attribute := element.get_attribute_node(hook_name) {
			hook_namespace = attribute.namespace_uri()
			hook_name = attribute.local_name()
		}
	}
	change := compact_native_attribute_change(element, hook_name, hook_namespace)
	if namespaced {
		element.set_attribute_ns_for_bindings(owned_namespace, owned_name, owned_input)!
	} else {
		element.set_attribute_for_bindings(owned_name, owned_input)!
	}
	change.finish(element)
	return compact_replay_json_result(json2.encode({
		'refresh': binding.element_attribute_refresh(element)
	}))
}
