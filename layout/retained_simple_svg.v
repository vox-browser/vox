module layout

import css
import dom
import os

const disable_retained_simple_svg = os.getenv('VOX_DISABLE_RETAINED_SIMPLE_SVG') != ''
const retained_simple_svg_diagnostics = os.getenv('VOX_RETAINED_SIMPLE_SVG_DIAGNOSTICS') != ''

__global retained_simple_svg_reported bool

struct RetainedSVGAttribute {
	name string
	local_name string
	namespace_uri ?string
	prefix ?string
	value string
}

struct RetainedSVGElement {
	element &dom.Element
	attributes []RetainedSVGAttribute
	children []u64
}

@[heap]
struct RetainedSimpleSVGInput {
	elements []RetainedSVGElement
}

struct RetainedSVGInputBudget {
mut:
	bytes int = 65536
}

fn collect_simple_svg_dom_inputs(element &dom.Element, mut result []RetainedSVGElement, mut budget RetainedSVGInputBudget) bool {
	// These shapes have no external geometry, text shaping, resource instances
	// or animation elements. SVG paths/transforms already live in UsedValues.
	if !element.is_svg_element() || element.local_name() !in ['svg', 'g', 'path',
		'rect', 'circle', 'ellipse', 'line', 'polyline', 'polygon'] || result.len >= 128
		|| element.attribute_list_size() > 256 || element.as_node().children.len > 256 {
		return false
	}
	mut attributes := []RetainedSVGAttribute{cap: element.attribute_list_size()}
	if list := element.attribute_list() {
		for index in 0 .. list.length() {
			attribute := list.item(index) or { return false }
			bytes := attribute.name().len + attribute.value().len
			if bytes > budget.bytes { return false }
			budget.bytes -= bytes
			if attribute.local_name() == 'href' || attribute.value().contains('url(') {
				return false
			}
			// Attribute strings are immutable and owned by the document; a
			// mutation installs a new string. Comparing against the strings
			// themselves avoids copying long path data on every layout pass.
			attributes << RetainedSVGAttribute{
				name: attribute.name()
				local_name: attribute.local_name()
				namespace_uri: attribute.namespace_uri()
				prefix: attribute.prefix__
				value: attribute.value()
			}
		}
	}
	mut children := []u64{cap: element.as_node().children.len}
	for child in element.as_node().children { children << u64(child.unique_id()) }
	result << RetainedSVGElement{ element: element, attributes: attributes, children: children }
	for child in element.as_node().children {
		if value := child.as_element() {
			if !collect_simple_svg_dom_inputs(value, mut result, mut budget) { return false }
		} else if !child.is_text() || (child.text_content() or { '' }).trim_space() != '' {
			return false
		}
	}
	return true
}

fn retained_simple_svg_input(node &Node) ?&RetainedSimpleSVGInput {
	if disable_retained_simple_svg || !node.is_svg_svg_box()
		|| node.document().is_svg_image_document() { return none }
	owner := node.dom_node() or { return none }
	element := owner.as_element() or { return none }
	mut allocations := retain_geometry_allocations()
	defer { allocations.finish() }
	mut elements := []RetainedSVGElement{}
	mut budget := RetainedSVGInputBudget{}
	if !collect_simple_svg_dom_inputs(element, mut elements, mut budget) { return none }
	return &RetainedSimpleSVGInput{ elements: elements }
}

fn retained_simple_svg_input_is_current(input &RetainedSimpleSVGInput) bool {
	for saved in input.elements {
		element := saved.element
		if element.attribute_list_size() != saved.attributes.len
			|| element.as_node().children.len != saved.children.len { return false }
		if list := element.attribute_list() {
			for index, previous in saved.attributes {
				current := list.item(index) or { return false }
				if current.name() != previous.name || current.local_name() != previous.local_name
					|| current.namespace_uri() != previous.namespace_uri
					|| current.prefix__ != previous.prefix || current.value() != previous.value {
					return false
				}
			}
		}
		for index, child in element.as_node().children {
			if u64(child.unique_id()) != saved.children[index] { return false }
		}
	}
	return true
}

fn retained_simple_svg_style_is_closed(node &Node) bool {
	for property_id in [css.PropertyID.fill, .stroke, .filter, .clip_path, .mask_image] {
		if value := node.computed_values().property(property_id, .yes) {
			if value.css_text.contains('url(') { return false }
		}
	}
	return true
}

fn report_retained_simple_svg(inputs []RetainedInlineInput) {
	if !retained_simple_svg_diagnostics || retained_simple_svg_reported { return }
	if inputs.any(it.simple_svg != none) {
		retained_simple_svg_reported = true
		eprintln('Vox retained simple SVG: reused unchanged SVG geometry inside independent context')
	}
}
