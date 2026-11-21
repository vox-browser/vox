module main

import browserjs
import os
import platform

// Same-binary control: getAttribute and hasAttribute use the JSON element
// query transport, as before.
const retain_attribute_json_reads = os.getenv('VOX_RETAIN_ATTRIBUTE_JSON_READS') != ''

fn install_compact_attribute_value_query(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if retain_attribute_json_reads { return }
	runtime.install_attribute_value_query(fn [binding] (key string, name string) !browserjs.AttributeValueReply {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return owner.attribute_value(key, name)
	})!
}

// An attribute read of a registered element of this document. Others take
// the JSON transport, which also resolves created and foreign receivers.
fn (mut binding CompactElementQueryBinding) attribute_value(key string, name string) !browserjs.AttributeValueReply {
	node := binding.nodes[key] or {
		element := binding.elements[key] or { return browserjs.AttributeValueReply{} }
		element.as_node()
	}
	element := node.as_element() or { return browserjs.AttributeValueReply{} }
	if voidptr(element.document()) != voidptr(binding.document) { return browserjs.AttributeValueReply{} }
	mut scope := platform.RetainedArenaScope{}
	storage := binding.document.native_storage()
	if storage != unsafe { nil } { scope = storage.enter_nested() }
	defer { scope.finish() }
	mut messages := []string{}
	settle_compact_dom_reactions(binding.document, binding.runtime, mut messages)!
	if messages.len != 0 { return error(messages.join('\n')) }
	value := element.get_attribute(name) or { return browserjs.AttributeValueReply{handled: true} }
	return browserjs.AttributeValueReply{handled: true, present: true, value: value}
}
