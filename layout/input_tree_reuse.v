module layout

import css
import dom
import hash.fnv1a
import html
import os
import platform

// Clean subtree reuse rejects form controls because the builder constructs
// their internal boxes (build_input_internal_layout_children) from state no
// invalidation flag covers. For the text-like input types those boxes come
// from the type, value and placeholder attributes and from the input's
// computed style, whose object a restyle replaces. Record those inputs when
// the boxes are built; while they are unchanged, a rebuild would construct the
// same boxes and the kept ones serve.

// Same-binary control: any input keeps the complete builder.
const retain_input_tree_rebuilds = os.getenv('VOX_RETAIN_INPUT_TREE_REBUILDS') != ''

// Inputs whose internal boxes were last built, by element, with the
// signature of what they were built from.
__global input_tree_signatures map[u64]u64

fn input_tree_signature(element &dom.Element) ?u64 {
	if !element.is_html_element() || element.local_name() != 'input' || element.shadow_root() != none {
		return none
	}
	type_ := element.get_attribute_value('type').trim_space().to_lower()
	state := html.html_input_element_parse_type_attribute(type_)
	if state !in [.text, .search, .telephone, .url, .email, .password] { return none }
	computed := css.computed_properties_for_element(element) or { return none }
	mut signature := fnv1a.sum64_string(type_)
	for name in ['value', 'placeholder'] {
		present := element.has_attribute(name)
		signature = (signature ^ u64(if present { 1 } else { 2 })) * 0x100000001b3
		signature = (signature ^ fnv1a.sum64_string(element.get_attribute_value(name))) * 0x100000001b3
	}
	signature = (signature ^ u64(voidptr(computed))) * 0x100000001b3
	signature = (signature ^ u64(int(element.document().font_rendering_policy()))) * 0x100000001b3
	return signature
}

// Called as the builder constructs `element`'s internal boxes.
fn note_input_tree_signature(element &dom.Element) {
	if retain_input_tree_rebuilds { return }
	key := u64(voidptr(element))
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if signature := input_tree_signature(element) {
		input_tree_signatures[key] = signature
	} else {
		input_tree_signatures.delete(key)
	}
}

// Whether a rebuild would construct `element`'s internal boxes from the same
// inputs as the existing ones.
fn input_tree_is_current(element &dom.Element) bool {
	if retain_input_tree_rebuilds { return false }
	recorded := input_tree_signatures[u64(voidptr(element))] or { return false }
	signature := input_tree_signature(element) or { return false }
	return signature == recorded
}
