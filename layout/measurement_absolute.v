module layout

import css
import os

const retain_absolute_measurement_layout = os.getenv('VOX_RETAIN_ABSOLUTE_MEASUREMENT_LAYOUT') != ''
const absolute_measurement_diagnostics = os.getenv('VOX_ABSOLUTE_MEASUREMENT_DIAGNOSTICS') != ''

__global absolute_measurement_reported bool

// Ordinary absolute descendants do not participate in grid/flex sizing. The
// within-pass snapshot owns their static-position records; final absolute
// sizing/positioning still runs. Do not extend persistent caches, admit an
// absolute root, or include specialized element/anchor behavior here.
fn measurement_absolute_descendant_is_reusable(node &Node) bool {
	if retain_absolute_measurement_layout || node.computed_values().position() != .absolute
		|| node.is_replaced_box() || node.is_svg_box() { return false }
	owner := node.dom_node() or { return false }
	element := owner.as_element() or { return false }
	if !element.is_html_element() || element.local_name() !in ['div', 'span', 'p',
		'section', 'article', 'aside', 'header', 'footer', 'nav', 'main', 'a', 'label'] {
		return false
	}
	computed := node.computed_values()
	if computed.position_anchor() != none { return false }
	for property in [css.PropertyID.top, .right, .bottom, .left] {
		if value := unsafe { &css.ComputedProperties(computed) }.typed_property_value(property) {
			if value is css.AnchorStyleValue || value is css.CalculatedStyleValue { return false }
		}
	}
	return true
}

fn measurement_absolute_dependencies_are_internal(root &Node, node &Node) bool {
	containing := node.containing_block() or { return false }
	static_containing := node.static_position_containing_block() or { return false }
	return root.is_inclusive_ancestor_of(unsafe { &Node(containing) })
		&& unsafe { &Node(containing) }.is_inclusive_ancestor_of(node)
		&& root.is_inclusive_ancestor_of(unsafe { &Node(static_containing) })
		&& unsafe { &Node(static_containing) }.is_inclusive_ancestor_of(node)
}

fn report_absolute_measurement_reuse(inputs []RetainedInlineInput) {
	if !absolute_measurement_diagnostics || absolute_measurement_reported { return }
	for input in inputs {
		if measurement_absolute_descendant_is_reusable(input.node) {
			absolute_measurement_reported = true
			eprintln('Vox absolute measurement: reused owned static positions before final absolute layout')
			return
		}
	}
}
