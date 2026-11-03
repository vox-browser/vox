module layout

import css
import dom
import os

const retain_flow_style_identities = os.getenv('VOX_RETAIN_FLOW_STYLE_IDENTITIES') != ''
const retained_flow_style_diagnostics = os.getenv('VOX_RETAINED_FLOW_STYLE_DIAGNOSTICS') != ''

__global retained_flow_style_reported_document dom.UniqueNodeID

fn retained_flow_style_matches(node &Node, computed &css.ComputedProperties) bool {
	previous := node.computed_values()
	if voidptr(previous) == voidptr(computed) { return true }
	if retain_flow_style_identities || !previous.has_identical_retained_layout_inputs(computed, node.document()) {
		return false
	}
	return true
}

fn report_retained_flow_style_reuse(root &Node, elements []&dom.Element) {
	if !retained_flow_style_diagnostics || retain_flow_style_identities { return }
	document := root.document()
	identity := document.as_node().unique_id()
	if retained_flow_style_reported_document == identity { return }
	for element in elements {
		computed := css.computed_properties_for_element(element) or { continue }
		mirror := element.as_node().unsafe_layout_node() or { continue }
		if mirror.real_layout_handle() == unsafe { nil } { continue }
		node := unsafe { &Node(mirror.real_layout_handle()) }
		if voidptr(node.computed_values()) == voidptr(computed) { continue }
		retained_flow_style_reported_document = identity
		eprintln('Vox retained flow style: reused subtree after matching replacement inputs; document=${document.url.serialize()}')
		return
	}
}
