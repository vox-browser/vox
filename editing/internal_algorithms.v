// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/Internal/Algorithms.{h,cpp}: node classification,
// boundary points, and style resolution. The value, structure, and deletion
// algorithms continue in the internal_algorithms_*.v files.
module editing

import css
import dom
import strconv

const editing_html_namespace = 'http://www.w3.org/1999/xhtml'

pub enum SelectionsListState {
	none
	ol
	ul
	mixed
	mixed_ol
	mixed_ul
}

pub enum JustifyAlignment {
	center
	justify
	left
	right
}

pub struct RecordedNodeValue {
pub:
	node                    &dom.Node = unsafe { nil }
	command                 string
	specified_command_value ?string
}

pub type RecordedOverrideValue = bool | string

pub struct RecordedOverride {
pub:
	command string
	value   RecordedOverrideValue
}

// https://w3c.github.io/editing/docs/execCommand/#active-range
pub fn active_range(document &dom.Document) ?&dom.Range {
	// The active range is the range of the selection given by calling getSelection() on the context object. (Thus the
	// active range may be null.)
	selection := document.get_selection() or { return none }
	return selection.range()
}

fn editing_boundary(node &dom.Node, offset int) dom.BoundaryPoint {
	return dom.BoundaryPoint{
		node:   node
		offset: offset
	}
}

fn editing_create_html_element(document &dom.Document, local_name string) &dom.Element {
	return dom.create_element(document, local_name, editing_html_namespace, none, none, false) or {
		panic('creating an HTML ${local_name} element cannot fail')
	}
}

fn editing_html_local_name(node &dom.Node) ?string {
	element := node.as_element() or { return none }
	if !element.is_html_element() {
		return none
	}
	return element.local_name()
}

fn is_html_element_named(node &dom.Node, names []string) bool {
	name := editing_html_local_name(node) or { return false }
	return name in names
}

fn editing_optional_node_is(node ?&dom.Node, predicate fn (&dom.Node) bool) bool {
	value := node or { return false }
	return predicate(value)
}

fn editing_is_br(node &dom.Node) bool {
	return node.is_html_br_element()
}

fn editing_is_ol(node &dom.Node) bool {
	return node.is_html_olist_element()
}

fn editing_is_ul(node &dom.Node) bool {
	return node.is_html_ulist_element()
}

fn editing_is_ol_or_ul(node &dom.Node) bool {
	return node.is_html_olist_element() || node.is_html_ulist_element()
}

fn editing_same_node(a ?&dom.Node, b ?&dom.Node) bool {
	left := a or { return b == none }
	right := b or { return false }
	return voidptr(left) == voidptr(right)
}

fn editing_text_data(node &dom.Node) string {
	character_data := node.as_character_data() or { return node.text_content() or { '' } }
	return character_data.data()
}

// The UTF-16 code unit at index of data, as DOM offsets address character data.
fn editing_code_unit_at(data string, index int) ?u16 {
	if index < 0 {
		return none
	}
	mut position := 0
	for character in data.runes() {
		if u32(character) > 0xffff {
			value := u32(character) - 0x10000
			if index == position {
				return u16(0xd800 + (value >> 10))
			}
			if index == position + 1 {
				return u16(0xdc00 + (value & 0x3ff))
			}
			position += 2
		} else {
			if index == position {
				return u16(character)
			}
			position++
		}
	}
	return none
}

fn editing_nearest_inclusive_ancestor_element(node &dom.Node) ?&dom.Element {
	mut current := ?&dom.Node(node)
	for {
		candidate := current or { return none }
		if element := candidate.as_element() {
			return element
		}
		current = candidate.parent()
	}
	return none
}

// resolved_value(): the resolved value of property on the nearest inclusive
// ancestor Element of node (this allows passing in a Text node), serialized as
// getComputedStyle() serializes it.
pub fn resolved_value(node &dom.Node, property_name string) ?string {
	element := editing_nearest_inclusive_ancestor_element(node) or { return none }
	resolved := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element,
		none))
	value := resolved.get_property_value(property_name)
	if value == '' {
		return none
	}
	return value
}

pub fn resolved_display(node &dom.Node) ?css.Display {
	element := editing_nearest_inclusive_ancestor_element(node) or { return none }
	if !element.as_node().is_connected() {
		return none
	}
	return css.up_to_date_computed_properties_for_element(element).display()
}

pub fn resolved_keyword(node &dom.Node, property_name string) ?string {
	value := resolved_value(node, property_name) or { return none }
	if value.contains(' ') || value.contains('(') {
		return none
	}
	return value.to_lower()
}

// The declaration the element's style attribute sets for property, if any.
pub fn property_in_style_attribute(element &dom.Element, property_name string) ?string {
	inline_style := css.inline_style_for_element(element) or { return none }
	property_id := css.property_id_from_string(property_name) or { return none }
	declaration := inline_style.get_property(property_id) or { return none }
	return inline_style.serialize_a_css_value(declaration)
}

pub fn value_contains_keyword(value string, keyword string) bool {
	for component in value.split(' ') {
		if component.trim_space().to_lower() == keyword {
			return true
		}
	}
	return false
}

fn editing_inline_style_length(element &dom.Element) int {
	inline_style := css.inline_style_for_element(element) or { return 0 }
	return inline_style.length()
}

fn editing_inline_style_value(element &dom.Element, property_name string) string {
	inline_style := css.inline_style_for_element(element) or { return '' }
	return inline_style.get_property_value(property_name)
}

fn editing_inline_style_has_property(element &dom.Element, property_name string) bool {
	return property_in_style_attribute(element, property_name) != none
}

// https://w3c.github.io/editing/docs/execCommand/#block-node-of
pub fn block_node_of_node(input_node &dom.Node) ?&dom.Node {
	// 1. While node is an inline node, set node to its parent.
	mut node := ?&dom.Node(input_node)
	for {
		current := node or { break }
		if !is_inline_node(current) {
			break
		}
		node = current.parent()
	}

	// 2. Return node.
	return node
}

pub fn editing_ignores_content(node &dom.Node) bool {
	// INTEROP: Blink and WebKit distinguish nodes whose descendants participate in editing from atomic content by
	//          querying the DOM node, not its renderer. In Ladybird, HTML void elements are the nodes which cannot
	//          contain an editing boundary. Keeping this independent of layout also makes it safe during mutation.
	element := node.as_element() or { return false }
	return element.is_void_element()
}

pub fn end_boundary_of_node(node &dom.Node) dom.BoundaryPoint {
	// INTEROP: Editing endpoints are inside text, before a trailing placeholder br, and after atomic content. A raw
	//          deepest-last-descendant walk would instead place the selection inside void elements or after the br.
	if node.is_text() {
		return editing_boundary(node, node.length())
	}
	if last_child := node.last_child() {
		if last_child.is_html_br_element() {
			return editing_boundary(node, last_child.index())
		}
		return end_boundary_of_node(last_child)
	}
	if editing_ignores_content(node) && !node.is_html_br_element() {
		if parent := node.parent() {
			return editing_boundary(parent, node.index() + 1)
		}
	}
	return editing_boundary(node, 0)
}

// https://w3c.github.io/editing/docs/execCommand/#canonical-space-sequence
pub fn canonical_space_sequence(length int, non_breaking_start bool, non_breaking_end bool) string {
	mut n := length

	// 1. If n is zero, return the empty string.
	if n <= 0 {
		return ''
	}

	// 2. If n is one and both non-breaking start and non-breaking end are false, return a single
	//    space (U+0020).
	if n == 1 && !non_breaking_start && !non_breaking_end {
		return ' '
	}

	// 3. If n is one, return a single non-breaking space (U+00A0).
	if n == 1 {
		return ' '
	}

	// 4. Let buffer be the empty string.
	mut buffer := ''

	// 5. If non-breaking start is true, let repeated pair be U+00A0 U+0020. Otherwise, let it be
	//    U+0020 U+00A0.
	first_repeated := if non_breaking_start { ' ' } else { ' ' }
	second_repeated := if non_breaking_start { ' ' } else { ' ' }

	// 6. While n is greater than three, append repeated pair to buffer and subtract two from n.
	// AD-HOC: Other browsers seem to fit in as many repeated pairs until the remaining length is <= 2.
	for n > 2 {
		buffer += first_repeated + second_repeated
		n -= 2
	}

	// AD-HOC: Other browsers seem to ignore steps 7 and 8 and deal differently with padding the remainder; the
	//         first remaining position is filled with the first character from repeated pair.
	if n > 0 {
		buffer += first_repeated
		n--
	}

	// AD-HOC: Then, the final position is set depending on the value of non-breaking end.
	if n > 0 {
		buffer += if non_breaking_end { ' ' } else { ' ' }
	}

	// 9. Return buffer.
	return buffer
}

// https://w3c.github.io/editing/docs/execCommand/#formattable-block-name
pub fn formattable_block_name_from_utf16(local_name string) ?string {
	// A formattable block name is "address", "dd", "div", "dt", "h1", "h2", "h3", "h4", "h5", "h6", "p", or "pre".
	if is_formattable_block_name(local_name) {
		return local_name
	}
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#formattable-block-name
pub fn is_formattable_block_name(local_name string) bool {
	return local_name in ['address', 'dd', 'div', 'dt', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p',
		'pre']
}

pub fn is_heading(local_name string) bool {
	return local_name in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
}

// https://w3c.github.io/editing/docs/execCommand/#name-of-an-element-with-inline-contents
pub fn is_name_of_an_element_with_inline_contents(local_name string) bool {
	// A name of an element with inline contents is "a", "abbr", "b", "bdi", "bdo", "cite", "code", "dfn", "em", "h1",
	// "h2", "h3", "h4", "h5", "h6", "i", "kbd", "mark", "p", "pre", "q", "rp", "rt", "ruby", "s", "samp", "small",
	// "span", "strong", "sub", "sup", "u", "var", "acronym", "listing", "strike", "xmp", "big", "blink", "font",
	// "marquee", "nobr", or "tt".
	return local_name in ['a', 'abbr', 'b', 'bdi', 'bdo', 'cite', 'code', 'dfn', 'em', 'h1', 'h2',
		'h3', 'h4', 'h5', 'h6', 'i', 'kbd', 'mark', 'p', 'pre', 'q', 'rp', 'rt', 'ruby', 's', 'samp',
		'small', 'span', 'strong', 'sub', 'sup', 'u', 'var', 'acronym', 'listing', 'strike', 'xmp',
		'big', 'blink', 'font', 'marquee', 'nobr', 'tt']
}

// https://w3c.github.io/editing/docs/execCommand/#prohibited-paragraph-child-name
pub fn is_prohibited_paragraph_child_name(local_name string) bool {
	// A prohibited paragraph child name is "address", "article", "aside", "blockquote", "caption", "center", "col",
	// "colgroup", "dd", "details", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
	// "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr", "li", "listing", "menu", "nav", "ol", "p",
	// "plaintext", "pre", "section", "summary", "table", "tbody", "td", "tfoot", "th", "thead", "tr", "ul", or "xmp".
	return local_name in dom.editing_prohibited_paragraph_child_names
}

// Whether a resolved display qualifies an Element as a block node; see is_block_node() below.
fn is_block_display(display ?css.Display) bool {
	value := display or { return true }
	return !(value.is_inline_outside() && (value.is_flow_inside() || value.is_flow_root_inside()
		|| value.is_table_inside())) && !value.is_none()
}

// https://w3c.github.io/editing/docs/execCommand/#block-node
pub fn is_block_node(node &dom.Node) bool {
	// A block node is either an Element whose "display" property does not have resolved value
	// "inline" or "inline-block" or "inline-table" or "none", or a document, or a DocumentFragment.
	if node.is_document() || node.is_document_fragment() {
		return true
	}
	if !node.is_element() {
		return false
	}
	return is_block_display(resolved_display(node))
}

// https://w3c.github.io/editing/docs/execCommand/#inline-node
pub fn is_inline_node(node &dom.Node) bool {
	// An inline node is a node that is not a block node.
	return !is_block_node(node)
}

// https://w3c.github.io/editing/docs/execCommand/#block-boundary-point
pub fn is_block_boundary_point(boundary_point dom.BoundaryPoint) bool {
	// A boundary point is a block boundary point if it is either a block start point or a block end point.
	return is_block_start_point(boundary_point) || is_block_end_point(boundary_point)
}

// https://w3c.github.io/editing/docs/execCommand/#block-end-point
pub fn is_block_end_point(boundary_point dom.BoundaryPoint) bool {
	// A boundary point (node, offset) is a block end point if either node's parent is null and offset is node's length;
	if boundary_point.node.parent() == none && boundary_point.offset == boundary_point.node.length() {
		return true
	}

	// or node has a child with index offset, and that child is a visible block node.
	// AD-HOC: Test block-ness first. Both conditions are side-effect free, and is_visible_node() resolves style for
	//         every inclusive ancestor, while is_block_node() rejects a non-Element outright.
	offset_child := boundary_point.node.child_at_index(boundary_point.offset) or { return false }
	return is_block_node(offset_child) && is_visible_node(offset_child)
}

// https://w3c.github.io/editing/docs/execCommand/#block-start-point
pub fn is_block_start_point(boundary_point dom.BoundaryPoint) bool {
	// A boundary point (node, offset) is a block start point if either node's parent is null and offset is zero;
	if boundary_point.node.parent() == none && boundary_point.offset == 0 {
		return true
	}

	// or node has a child with index offset − 1, and that child is either a visible block node or a visible br.
	// AD-HOC: Test block-ness first, as in is_block_end_point().
	offset_minus_one_child := boundary_point.node.child_at_index(boundary_point.offset - 1) or {
		return false
	}
	return (is_block_node(offset_minus_one_child) || offset_minus_one_child.is_html_br_element())
		&& is_visible_node(offset_minus_one_child)
}

// https://w3c.github.io/editing/docs/execCommand/#collapsed-block-prop
pub fn is_collapsed_block_prop(node &dom.Node) bool {
	// A collapsed block prop is either a collapsed line break that is not an extraneous line break,
	if is_collapsed_line_break(node) && !is_extraneous_line_break(node) {
		return true
	}

	// or an Element that is an inline node
	if !node.is_element() || !is_inline_node(node) {
		return false
	}

	// and whose children are all either invisible or collapsed block props
	mut has_collapsed_block_prop := false
	for child in node.children_as_vector() {
		child_is_collapsed_block_prop := is_collapsed_block_prop(child)
		if !is_invisible_node(child) && !child_is_collapsed_block_prop {
			return false
		}
		if child_is_collapsed_block_prop {
			has_collapsed_block_prop = true
		}
	}

	// and that has at least one child that is a collapsed block prop.
	return has_collapsed_block_prop
}

// https://w3c.github.io/editing/docs/execCommand/#collapsed-line-break
pub fn is_collapsed_line_break(node &dom.Node) bool {
	// A collapsed line break is a br
	if !node.is_html_br_element() {
		return false
	}

	// that begins a line box which has nothing else in it, and therefore has zero height.
	// AD-HOC: We check this on the DOM level by seeing if the next node is neither a non-empty text node nor a <br>.
	next_sibling := node.next_sibling() or { return true }
	if next_sibling.is_text() {
		return editing_text_data(next_sibling) == ''
	}
	return !next_sibling.is_html_br_element()
}

// https://w3c.github.io/editing/docs/execCommand/#collapsed-whitespace-node
pub fn is_collapsed_whitespace_node(node &dom.Node) bool {
	// 1. If node is not a whitespace node, return false.
	if !is_whitespace_node(node) {
		return false
	}

	// 2. If node's data is the empty string, return true.
	if editing_text_data(node) == '' {
		return true
	}

	// 3. Let ancestor be node's parent.
	// 4. If ancestor is null, return true.
	mut ancestor := node.parent() or { return true }

	// 5. If the "display" property of some ancestor of node has resolved value "none", return true.
	mut some_ancestor := ?&dom.Node(ancestor)
	for {
		current := some_ancestor or { break }
		if display := resolved_display(current) {
			if display.is_none() {
				return true
			}
		}
		some_ancestor = current.parent()
	}

	// 6. While ancestor is not a block node and its parent is not null, set ancestor to its parent.
	for !is_block_node(ancestor) {
		ancestor = ancestor.parent() or { break }
	}

	// 7. Let reference be node.
	mut reference := unsafe { node }

	// 8. While reference is a descendant of ancestor:
	for reference.is_descendant_of(ancestor) {
		// 1. Let reference be the node before it in tree order.
		reference = reference.previous_in_pre_order() or { break }

		// 2. If reference is a block node or a br, return true.
		if is_block_node(reference) || reference.is_html_br_element() {
			return true
		}

		// 3. If reference is a Text node that is not a whitespace node, or is an img, break from
		//    this loop.
		if (reference.is_text() && !is_whitespace_node(reference)) || reference.is_html_image_element() {
			break
		}
	}

	// 9. Let reference be node.
	reference = node

	// 10. While reference is a descendant of ancestor:
	for reference.is_descendant_of(ancestor) {
		// 1. Let reference be the node after it in tree order, or null if there is no such node.
		// NOTE: Both steps below and the loop condition require a reference, so break if it's null.
		reference = reference.next_in_pre_order(none) or { break }

		// 2. If reference is a block node or a br, return true.
		if is_block_node(reference) || reference.is_html_br_element() {
			return true
		}

		// 3. If reference is a Text node that is not a whitespace node, or is an img, break from
		//    this loop.
		if (reference.is_text() && !is_whitespace_node(reference)) || reference.is_html_image_element() {
			break
		}
	}

	// 11. Return false.
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#effectively-contained
pub fn is_effectively_contained_in_range(node &dom.Node, range_ &dom.Range) bool {
	// A node node is effectively contained in a range range if range is not collapsed, and at least one of the
	// following holds:
	if range_.collapsed() {
		return false
	}

	// * node is contained in range.
	if range_.contains_node(node) {
		return true
	}

	// * node is range's start node, it is a Text node, and its length is different from range's start offset.
	if voidptr(node) == voidptr(range_.start_container()) && node.is_text()
		&& node.length() != range_.start_offset() {
		return true
	}

	// * node is range's end node, it is a Text node, and range's end offset is not 0.
	if voidptr(node) == voidptr(range_.end_container()) && node.is_text() && range_.end_offset() != 0 {
		return true
	}

	// * node has at least one child; and all its children are effectively contained in range;
	if !node.has_children() {
		return false
	}
	for child in node.children_as_vector() {
		if !is_effectively_contained_in_range(child, range_) {
			return false
		}
	}

	// and either range's start node is not a descendant of node or is not a Text node or range's start offset is zero;
	start_node := range_.start_container()
	if start_node.is_descendant_of(node) && start_node.is_text() && range_.start_offset() != 0 {
		return false
	}

	// and either range's end node is not a descendant of node or is not a Text node or range's end offset is its end
	// node's length.
	end_node := range_.end_container()
	if end_node.is_descendant_of(node) && end_node.is_text() && range_.end_offset() != end_node.length() {
		return false
	}

	return true
}

// for_each_node_effectively_contained_in_range(), returning the nodes in tree order.
pub fn nodes_effectively_contained_in_range(range_ ?&dom.Range) []&dom.Node {
	active := range_ or { return [] }

	// A node can still be "effectively contained" in range even if it's not actually contained within the range; so we
	// need to traverse the highest effectively contained ancestor of the common ancestor container.
	// See: https://w3c.github.io/editing/docs/execCommand/#effectively-contained
	mut traversal_root := active.common_ancestor_container()
	for {
		parent := traversal_root.parent() or { break }
		if !is_effectively_contained_in_range(parent, active) {
			break
		}
		traversal_root = parent
	}

	// NOTE: We cannot skip children when a descendant is not effectively contained within a range, since its
	//       children might still be.
	mut result := []&dom.Node{}
	mut current := ?&dom.Node(traversal_root)
	for {
		node := current or { break }
		if is_effectively_contained_in_range(node, active) {
			result << node
		}
		current = node.next_in_pre_order(traversal_root)
	}
	return result
}

pub fn first_formattable_node_effectively_contained(range_ ?&dom.Range) ?&dom.Node {
	for node in nodes_effectively_contained_in_range(range_) {
		if is_formattable_node(node) {
			return node
		}
	}
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#element-with-inline-contents
pub fn is_element_with_inline_contents(node &dom.Node) bool {
	// An element with inline contents is an HTML element whose local name is a name of an element with inline contents.
	name := editing_html_local_name(node) or { return false }
	return is_name_of_an_element_with_inline_contents(name)
}

// https://w3c.github.io/editing/docs/execCommand/#extraneous-line-break
pub fn is_extraneous_line_break(node &dom.Node) bool {
	// An extraneous line break is a br
	if !node.is_html_br_element() {
		return false
	}

	// ...except that a br that is the sole child of an li is not extraneous.
	parent := node.parent() or { return false }
	if parent.is_html_li_element() && parent.child_count() == 1 {
		return false
	}

	// ...that has no visual effect, in that removing it from the DOM would not change layout,

	// AD-HOC: If node's parent is a block node, and node either has no next sibling or its next sibling is a block
	//         node, and its previous sibling is a visible inline node but not a <br>, node is extraneous.
	if previous_sibling := node.previous_sibling() {
		next_is_absent_or_block := if next_sibling := node.next_sibling() {
			is_block_node(next_sibling)
		} else {
			true
		}
		if is_block_node(parent) && next_is_absent_or_block && is_visible_node(previous_sibling)
			&& is_inline_node(previous_sibling) && !previous_sibling.is_html_br_element() {
			return true
		}
	}

	// FIXME: implement more cases that would cause removing a <br> not to have any effect on the layout.

	return false
}

// https://w3c.github.io/editing/docs/execCommand/#formattable-node
pub fn is_formattable_node(node &dom.Node) bool {
	// A formattable node is an editable visible node that is either a Text node, an img, or a br.
	return node.is_editable() && is_visible_node(node)
		&& (node.is_text() || node.is_html_image_element() || node.is_html_br_element())
}

// https://w3c.github.io/editing/docs/execCommand/#in-the-same-editing-host
pub fn is_in_same_editing_host(node_a &dom.Node, node_b &dom.Node) bool {
	// Two nodes are in the same editing host if the editing host of the first is non-null and the
	// same as the editing host of the second.
	editing_host_a := node_a.editing_host() or { return false }
	editing_host_b := node_b.editing_host() or { return false }
	return voidptr(editing_host_a) == voidptr(editing_host_b)
}

// https://w3c.github.io/editing/docs/execCommand/#indentation-element
pub fn is_indentation_element(node &dom.Node) bool {
	// An indentation element is either a blockquote,
	element := node.as_element() or { return false }
	if element.local_name() == 'blockquote' {
		return true
	}

	// or a div that has a style attribute that sets "margin" or some subproperty of it.
	return node.is_html_div_element() && element.has_attribute('style')
		&& (editing_inline_style_value(element, 'margin') != ''
		|| editing_inline_style_value(element, 'margin-top') != ''
		|| editing_inline_style_value(element, 'margin-right') != ''
		|| editing_inline_style_value(element, 'margin-bottom') != ''
		|| editing_inline_style_value(element, 'margin-left') != '')
}

// https://w3c.github.io/editing/docs/execCommand/#invisible
pub fn is_invisible_node(node &dom.Node) bool {
	// Something is invisible if it is a node that is not visible.
	return !is_visible_node(node)
}

fn editing_has_no_attributes_except(element &dom.Element, exclusions []string) bool {
	for name in element.get_attribute_names() {
		if name !in exclusions {
			return false
		}
	}
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#modifiable-element
pub fn is_modifiable_element(node &dom.Node) bool {
	// NOTE: All conditions below expect an HTML element.
	name := editing_html_local_name(node) or { return false }
	element := node.as_element() or { return false }

	// A modifiable element is a b, em, i, s, span, strike, strong, sub, sup, or u element with no attributes except
	// possibly style;
	if name in ['b', 'em', 'i', 's', 'span', 'strike', 'strong', 'sub', 'sup', 'u'] {
		return editing_has_no_attributes_except(element, ['style'])
	}

	// or a font element with no attributes except possibly style, color, face, and/or size;
	if name == 'font' {
		return editing_has_no_attributes_except(element, ['style', 'color', 'face', 'size'])
	}

	// or an a element with no attributes except possibly style and/or href.
	return node.is_html_anchor_element() && editing_has_no_attributes_except(element, ['style', 'href'])
}

// https://w3c.github.io/editing/docs/execCommand/#non-list-single-line-container
pub fn is_non_list_single_line_container(node &dom.Node) bool {
	// A non-list single-line container is an HTML element with local name "address", "div", "h1", "h2", "h3", "h4",
	// "h5", "h6", "listing", "p", "pre", or "xmp".
	name := editing_html_local_name(node) or { return false }
	return is_heading(name) || name in ['address', 'div', 'listing', 'p', 'pre', 'xmp']
}

// https://w3c.github.io/editing/docs/execCommand/#prohibited-paragraph-child
pub fn is_prohibited_paragraph_child(node &dom.Node) bool {
	// A prohibited paragraph child is an HTML element whose local name is a prohibited paragraph child name.
	name := editing_html_local_name(node) or { return false }
	return is_prohibited_paragraph_child_name(name)
}

// https://w3c.github.io/editing/docs/execCommand/#removeformat-candidate
pub fn is_remove_format_candidate(node &dom.Node) bool {
	// A removeFormat candidate is an editable HTML element with local name "abbr", "acronym", "b", "bdi", "bdo", "big",
	// "blink", "cite", "code", "dfn", "em", "font", "i", "ins", "kbd", "mark", "nobr", "q", "s", "samp", "small",
	// "span", "strike", "strong", "sub", "sup", "tt", "u", or "var".
	if !node.is_editable() {
		return false
	}
	name := editing_html_local_name(node) or { return false }
	return name in ['abbr', 'acronym', 'b', 'bdi', 'bdo', 'big', 'blink', 'cite', 'code', 'dfn',
		'em', 'font', 'i', 'ins', 'kbd', 'mark', 'nobr', 'q', 's', 'samp', 'small', 'span', 'strike',
		'strong', 'sub', 'sup', 'tt', 'u', 'var']
}

const simple_indentation_style_properties = ['border', 'border-bottom', 'border-left', 'border-right',
	'border-top', 'margin', 'margin-bottom', 'margin-left', 'margin-right', 'margin-top', 'padding',
	'padding-bottom', 'padding-left', 'padding-right', 'padding-top']

// https://w3c.github.io/editing/docs/execCommand/#simple-indentation-element
pub fn is_simple_indentation_element(node &dom.Node) bool {
	// A simple indentation element is an indentation element
	if !is_indentation_element(node) {
		return false
	}
	element := node.as_element() or { return false }

	// that has no attributes except possibly
	for name in element.get_attribute_names() {
		// * a style attribute that sets no properties other than "margin", "border", "padding", or subproperties of
		//   those;
		if name == 'style' {
			inline_style := css.inline_style_for_element(element) or { continue }
			for index in 0 .. inline_style.length() {
				property_name := inline_style.item(index)
				if property_name !in simple_indentation_style_properties {
					// The style attribute stores expanded longhands; a margin, border, or padding longhand is
					// a subproperty of the listed shorthands.
					if !(property_name.starts_with('margin-') || property_name.starts_with('padding-')
						|| property_name.starts_with('border-')) {
						return false
					}
				}
			}
		}

		// * and/or a dir attribute.
		else if name != 'dir' {
			return false
		}
	}
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#simple-modifiable-element
pub fn is_simple_modifiable_element(node &dom.Node) bool {
	// A simple modifiable element is an HTML element for which at least one of the following holds:
	name := editing_html_local_name(node) or { return false }
	element := node.as_element() or { return false }
	inline_style_length := editing_inline_style_length(element)

	// * It is an a, b, em, font, i, s, span, strike, strong, sub, sup, or u element with no attributes.
	// * It is an a, b, em, font, i, s, span, strike, strong, sub, sup, or u element with exactly one attribute, which
	//   is style, which sets no CSS properties (including invalid or unrecognized properties).
	attribute_count := element.attribute_list_size()
	if name in ['a', 'b', 'em', 'font', 'i', 's', 'span', 'strike', 'strong', 'sub', 'sup', 'u'] {
		if attribute_count == 0 {
			return true
		}
		if attribute_count == 1 && element.has_attribute('style') && inline_style_length == 0 {
			return true
		}
	}

	// NOTE: All conditions below require exactly one attribute on the element
	if attribute_count != 1 {
		return false
	}

	// * It is an a element with exactly one attribute, which is href.
	if node.is_html_anchor_element() && element.get_attribute('href') != none {
		return true
	}

	// * It is a font element with exactly one attribute, which is either color, face, or size.
	if name == 'font' {
		if element.has_attribute('color') || element.has_attribute('face') || element.has_attribute('size') {
			return true
		}
	}

	// NOTE: All conditions below require exactly one attribute which is style, that sets one CSS property.
	if !element.has_attribute('style') || inline_style_length != 1 {
		return false
	}

	// * It is a b or strong element with exactly one attribute, which is style, and the style attribute sets exactly
	//   one CSS property (including invalid or unrecognized properties), which is "font-weight".
	if name in ['b', 'strong'] && editing_inline_style_has_property(element, 'font-weight') {
		return true
	}

	// * It is an i or em element with exactly one attribute, which is style, and the style attribute sets exactly one
	//   CSS property (including invalid or unrecognized properties), which is "font-style".
	if name in ['i', 'em'] && editing_inline_style_has_property(element, 'font-style') {
		return true
	}

	// * It is an a, font, or span element with exactly one attribute, which is style, and the style attribute sets
	//   exactly one CSS property (including invalid or unrecognized properties), and that property is not
	//   "text-decoration".
	has_text_decoration := editing_inline_style_value(element, 'text-decoration') != ''
	if name in ['a', 'font', 'span'] && !has_text_decoration {
		return true
	}

	// * It is an a, font, s, span, strike, or u element with exactly one attribute, which is style, and the style
	//   attribute sets exactly one CSS property (including invalid or unrecognized properties), which is
	//   "text-decoration", which is set to "line-through" or "underline" or "overline" or "none".
	if name in ['a', 'font', 's', 'span', 'strike', 'u'] && has_text_decoration {
		text_decoration := editing_inline_style_value(element, 'text-decoration')
		if text_decoration in ['line-through', 'underline', 'overline', 'none'] {
			return true
		}
	}

	return false
}

// https://w3c.github.io/editing/docs/execCommand/#single-line-container
pub fn is_single_line_container(node &dom.Node) bool {
	// A single-line container is either a non-list single-line container, or an HTML element with local name "li",
	// "dt", or "dd".
	if is_non_list_single_line_container(node) {
		return true
	}
	return is_html_element_named(node, ['li', 'dt', 'dd'])
}

// https://w3c.github.io/editing/docs/execCommand/#visible
pub fn is_visible_node(node &dom.Node) bool {
	// excluding any node with an inclusive ancestor Element whose "display" property has resolved
	// value "none".
	// NB: Only Elements have a display of their own; on any other node, resolved_display() answers
	//     with the nearest inclusive ancestor Element's display. So, walking the ancestor Elements
	//     covers every node in between. The display of node itself also feeds the block-node check
	//     below. So, it's resolved once here — rather than a second time there.
	mut node_display := ?css.Display(none)
	mut ancestor := ?&dom.Node(node)
	for {
		current := ancestor or { break }
		if current.is_element() {
			display := resolved_display(current)
			if voidptr(current) == voidptr(node) {
				node_display = display
			}
			if value := display {
				if value.is_none() {
					return false
				}
			}
		}
		ancestor = current.parent()
	}

	// Something is visible if it is a node that either is a block node,
	node_is_block := if node.is_element() { is_block_display(node_display) } else { is_block_node(node) }
	if node_is_block {
		return true
	}

	// or a Text node that is not a collapsed whitespace node,
	if node.is_text() && !is_collapsed_whitespace_node(node) {
		return true
	}

	// or an img,
	if node.is_html_image_element() {
		return true
	}

	// or a br that is not an extraneous line break,
	if node.is_html_br_element() && !is_extraneous_line_break(node) {
		return true
	}

	// or any node with a visible descendant;
	// NOTE: We call into is_visible_node() recursively, so check children instead of descendants.
	for child in node.children_as_vector() {
		if is_visible_node(child) {
			return true
		}
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#whitespace-node
pub fn is_whitespace_node(node &dom.Node) bool {
	// NOTE: All constraints below check that node is a Text node
	if !node.is_text() {
		return false
	}

	// A whitespace node is either a Text node whose data is the empty string;
	data := editing_text_data(node)
	if data == '' {
		return true
	}

	// NOTE: All constraints below require a parent Element with a resolved value for "white-space-collapse"
	parent := node.parent() or { return false }
	if !parent.is_element() {
		return false
	}
	white_space_collapse := resolved_keyword(parent, 'white-space-collapse') or { return false }

	// or a Text node whose data consists only of one or more tabs (0x0009), line feeds (0x000A),
	// carriage returns (0x000D), and/or spaces (0x0020), and whose parent is an Element whose
	// resolved value for "white-space" is "normal" or "nowrap";
	// AD-HOC: We use the equivalent "white-space-collapse" longhand property instead of "white-space" shorthand
	if data.runes().all(it in [`\t`, `\n`, `\r`, ` `]) && white_space_collapse == 'collapse' {
		return true
	}

	// or a Text node whose data consists only of one or more tabs (0x0009), carriage returns
	// (0x000D), and/or spaces (0x0020), and whose parent is an Element whose resolved value for
	// "white-space" is "pre-line".
	// AD-HOC: We use the equivalent "white-space-collapse" longhand property instead of "white-space" shorthand
	if data.runes().all(it in [`\t`, `\r`, ` `]) && white_space_collapse == 'preserve-breaks' {
		return true
	}

	return false
}

pub fn has_visible_children(node &dom.Node) bool {
	for child in node.children_as_vector() {
		if is_visible_node(child) {
			return true
		}
	}
	return false
}

// A child or parent argument of the allowed-child algorithm: a node, or a local name.
pub struct AllowedChildOperand {
	node ?&dom.Node
	name ?string
}

pub fn allowed_child_node(node &dom.Node) AllowedChildOperand {
	return AllowedChildOperand{
		node: node
	}
}

pub fn allowed_child_name(name string) AllowedChildOperand {
	return AllowedChildOperand{
		name: name
	}
}

// https://w3c.github.io/editing/docs/execCommand/#allowed-child
pub fn is_allowed_child_of_node(child_operand AllowedChildOperand, parent_operand AllowedChildOperand) bool {
	mut child_node := child_operand.node
	mut child_name := child_operand.name
	mut parent_node := parent_operand.node
	mut parent_name := parent_operand.name

	parent_element_name := if name := parent_name {
		?string(name)
	} else if node := parent_node {
		if element := node.as_element() { ?string(element.local_name()) } else { none }
	} else {
		none
	}
	if parent_local_name := parent_element_name {
		// 1. If parent is "colgroup", "table", "tbody", "tfoot", "thead", "tr", or an HTML element with local name equal to
		//    one of those, and child is a Text node whose data does not consist solely of space characters, return false.
		parent_is_table_like := parent_local_name in ['colgroup', 'table', 'tbody', 'tfoot', 'thead',
			'tr']
		if parent_is_table_like {
			if node := child_node {
				if node.is_text() && !editing_text_data(node).bytes().all(it in [` `, `\t`, `\n`, `\f`, `\r`]) {
					return false
				}
			}
		}

		// 2. If parent is "script", "style", "plaintext", or "xmp", or an HTML element with local name equal to one of
		//    those, and child is not a Text node, return false.
		child_is_text := if node := child_node { node.is_text() } else { false }
		if !child_is_text && parent_local_name in ['script', 'style', 'plaintext', 'xmp'] {
			return false
		}
	}

	// 3. If child is a document, DocumentFragment, or DocumentType, return false.
	if node := child_node {
		if node.is_document() || node.is_document_fragment() || node.is_document_type() {
			return false
		}

		// 4. If child is an HTML element, set child to the local name of child.
		if name := editing_html_local_name(node) {
			child_name = name
		}
	}

	// 5. If child is not a string, return true.
	child_local_name := child_name or { return true }

	// 6. If parent is an HTML element:
	if node := parent_node {
		if html_parent_name := editing_html_local_name(node) {
			// 1. If child is "a", and parent or some ancestor of parent is an a, return false.
			if child_local_name == 'a' {
				mut ancestor := ?&dom.Node(node)
				for {
					current := ancestor or { break }
					if current.is_html_anchor_element() {
						return false
					}
					ancestor = current.parent()
				}
			}

			// 2. If child is a prohibited paragraph child name and parent or some ancestor of parent is an element with
			//    inline contents, return false.
			if is_prohibited_paragraph_child_name(child_local_name) {
				mut ancestor := ?&dom.Node(node)
				for {
					current := ancestor or { break }
					if is_element_with_inline_contents(current) {
						return false
					}
					ancestor = current.parent()
				}
			}

			// 3. If child is "h1", "h2", "h3", "h4", "h5", or "h6", and parent or some ancestor of parent is an HTML
			//    element with local name "h1", "h2", "h3", "h4", "h5", or "h6", return false.
			if is_heading(child_local_name) {
				mut ancestor := ?&dom.Node(node)
				for {
					current := ancestor or { break }
					if name := editing_html_local_name(current) {
						if is_heading(name) {
							return false
						}
					}
					ancestor = current.parent()
				}
			}

			// 4. Let parent be the local name of parent.
			parent_name = html_parent_name
			parent_node = none
		}
	}

	// 7. If parent is an Element or DocumentFragment, return true.
	if node := parent_node {
		if node.is_element() || node.is_document_fragment() {
			return true
		}
	}

	// 8. If parent is not a string, return false.
	parent_local_name := parent_name or { return false }

	// 9. If parent is on the left-hand side of an entry on the following list, then return true if child is listed on
	//    the right-hand side of that entry, and false otherwise.

	// * colgroup: col
	if parent_local_name == 'colgroup' {
		return child_local_name == 'col'
	}

	// * table: caption, col, colgroup, tbody, td, tfoot, th, thead, tr
	if parent_local_name == 'table' {
		return child_local_name in ['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead',
			'tr']
	}

	// * tbody, tfoot, thead: td, th, tr
	if parent_local_name in ['tbody', 'tfoot', 'thead'] {
		return child_local_name in ['td', 'th', 'tr']
	}

	// * tr: td, th
	if parent_local_name == 'tr' {
		return child_local_name in ['td', 'th']
	}

	// * dl: dt, dd
	if parent_local_name == 'dl' {
		return child_local_name in ['dt', 'dd']
	}

	// * dir, ol, ul: dir, li, ol, ul
	if parent_local_name in ['dir', 'ol', 'ul'] {
		return child_local_name in ['dir', 'li', 'ol', 'ul']
	}

	// * hgroup: h1, h2, h3, h4, h5, h6
	if parent_local_name == 'hgroup' {
		return is_heading(child_local_name)
	}

	// 10. If child is "body", "caption", "col", "colgroup", "frame", "frameset", "head", "html", "tbody", "td",
	//     "tfoot", "th", "thead", or "tr", return false.
	if child_local_name in ['body', 'caption', 'col', 'colgroup', 'frame', 'frameset', 'head', 'html',
		'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return false
	}

	// 11. If child is "dd" or "dt" and parent is not "dl", return false.
	if child_local_name in ['dd', 'dt'] && parent_local_name != 'dl' {
		return false
	}

	// 12. If child is "li" and parent is not "ol" or "ul", return false.
	if child_local_name == 'li' && parent_local_name != 'ol' && parent_local_name != 'ul' {
		return false
	}

	// 13. If parent is on the left-hand side of an entry on the following list and child is listed on the right-hand
	//     side of that entry, return false.

	// * a: a
	if parent_local_name == 'a' && child_local_name == 'a' {
		return false
	}

	// * dd, dt: dd, dt
	if parent_local_name in ['dd', 'dt'] && child_local_name in ['dd', 'dt'] {
		return false
	}

	// * h1, h2, h3, h4, h5, h6: h1, h2, h3, h4, h5, h6
	if is_heading(parent_local_name) && is_heading(child_local_name) {
		return false
	}

	// * li: li
	if parent_local_name == 'li' && child_local_name == 'li' {
		return false
	}

	// * nobr: nobr
	if parent_local_name == 'nobr' && child_local_name == 'nobr' {
		return false
	}

	// * All names of an element with inline contents: all prohibited paragraph child names
	if is_name_of_an_element_with_inline_contents(parent_local_name)
		&& is_prohibited_paragraph_child_name(child_local_name) {
		return false
	}

	// * td, th: caption, col, colgroup, tbody, td, tfoot, th, thead, tr
	if parent_local_name in ['td', 'th'] && child_local_name in ['caption', 'col', 'colgroup', 'tbody',
		'td', 'tfoot', 'th', 'thead', 'tr'] {
		return false
	}

	// 14. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#follows-a-line-break
pub fn follows_a_line_break(input_node &dom.Node) bool {
	// 1. Let offset be zero.
	mut node := unsafe { input_node }
	mut offset := 0

	// 2. While (node, offset) is not a block boundary point:
	for !is_block_boundary_point(editing_boundary(node, offset)) {
		// 1. If node has a visible child with index offset minus one, return false.
		if offset_minus_one_child := node.child_at_index(offset - 1) {
			if is_visible_node(offset_minus_one_child) {
				return false
			}
		}

		// 2. If offset is zero or node has no children, set offset to node's index, then set node
		//    to its parent.
		if offset == 0 || node.child_count() == 0 {
			offset = node.index()
			node = node.parent() or { return true }
		}

		// 3. Otherwise, set node to its child with index offset minus one, then set offset to
		//    node's length.
		else {
			node = node.child_at_index(offset - 1) or { return true }
			offset = node.length()
		}
	}

	// 3. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#precedes-a-line-break
pub fn precedes_a_line_break(input_node &dom.Node) bool {
	// 1. Let offset be node's length.
	mut node := unsafe { input_node }
	mut offset := node.length()

	// 2. While (node, offset) is not a block boundary point:
	for !is_block_boundary_point(editing_boundary(node, offset)) {
		// 1. If node has a visible child with index offset, return false.
		if offset_child := node.child_at_index(offset) {
			if is_visible_node(offset_child) {
				return false
			}
		}

		// 2. If offset is node's length or node has no children, set offset to one plus node's
		//    index, then set node to its parent.
		if offset == node.length() || node.child_count() == 0 {
			offset = node.index() + 1
			node = node.parent() or { return true }
		}

		// 3. Otherwise, set node to its child with index offset and set offset to zero.
		else {
			node = node.child_at_index(offset) or { return true }
			offset = 0
		}
	}

	// 3. Return true;
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#next-equivalent-point
pub fn next_equivalent_point(boundary_point dom.BoundaryPoint) ?dom.BoundaryPoint {
	// 1. If node's length is zero, return null.
	node := boundary_point.node
	node_length := node.length()
	if node_length == 0 {
		return none
	}

	// 3. If offset is node's length, and node's parent is not null, and node is an inline node, return (node's parent,
	//    1 + node's index).
	if boundary_point.offset == node_length && is_inline_node(node) {
		if parent := node.parent() {
			return editing_boundary(parent, node.index() + 1)
		}
	}

	// 5. If node has a child with index offset, and that child's length is not zero, and that child is an inline node,
	//    return (that child, 0).
	if child_at_offset := node.child_at_index(boundary_point.offset) {
		if child_at_offset.length() != 0 && is_inline_node(child_at_offset) {
			return editing_boundary(child_at_offset, 0)
		}
	}

	// 7. Return null.
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#previous-equivalent-point
pub fn previous_equivalent_point(boundary_point dom.BoundaryPoint) ?dom.BoundaryPoint {
	// 1. If node's length is zero, return null.
	node := boundary_point.node
	node_length := node.length()
	if node_length == 0 {
		return none
	}

	// 2. If offset is 0, and node's parent is not null, and node is an inline node, return (node's parent, node's
	//    index).
	if boundary_point.offset == 0 && is_inline_node(node) {
		if parent := node.parent() {
			return editing_boundary(parent, node.index())
		}
	}

	// 3. If node has a child with index offset − 1, and that child's length is not zero, and that child is an inline
	//    node, return (that child, that child's length).
	if child_at_offset := node.child_at_index(boundary_point.offset - 1) {
		if child_at_offset.length() != 0 && is_inline_node(child_at_offset) {
			return editing_boundary(child_at_offset, child_at_offset.length())
		}
	}

	// 4. Return null.
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#first-equivalent-point
pub fn first_equivalent_point(boundary_point dom.BoundaryPoint) dom.BoundaryPoint {
	// 1. While (node, offset)'s previous equivalent point is not null, set (node, offset) to its previous equivalent
	//    point.
	mut point := boundary_point
	for {
		point = previous_equivalent_point(point) or { break }
	}

	// 2. Return (node, offset).
	return point
}

// https://w3c.github.io/editing/docs/execCommand/#last-equivalent-point
pub fn last_equivalent_point(boundary_point dom.BoundaryPoint) dom.BoundaryPoint {
	// 1. While (node, offset)'s next equivalent point is not null, set (node, offset) to its next equivalent point.
	mut point := boundary_point
	for {
		point = next_equivalent_point(point) or { break }
	}

	// 2. Return (node, offset).
	return point
}

pub fn justify_alignment_to_string(alignment JustifyAlignment) string {
	return match alignment {
		.center { 'center' }
		.justify { 'justify' }
		.left { 'left' }
		.right { 'right' }
	}
}

pub fn named_font_sizes() []string {
	return ['x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'xxx-large']
}

fn editing_absolute_size_from_keyword(keyword string) ?css.AbsoluteSize {
	return match keyword {
		'xx-small' { css.AbsoluteSize.xx_small }
		'x-small' { css.AbsoluteSize.x_small }
		'small' { css.AbsoluteSize.small }
		'medium' { css.AbsoluteSize.medium }
		'large' { css.AbsoluteSize.large }
		'x-large' { css.AbsoluteSize.x_large }
		'xx-large' { css.AbsoluteSize.xx_large }
		'xxx-large' { css.AbsoluteSize.xxx_large }
		else { none }
	}
}

pub fn font_size_to_pixel_size(font_size string) css.CSSPixels {
	// If the font size ends in 'px', interpret the preceding as a number and return it.
	if font_size.ends_with('px') {
		if number := strconv.atof64(font_size[..font_size.len - 2]) {
			return css.CSSPixels.nearest_value_for(number)
		}
	}

	// Try to map the font size directly to a keyword (e.g. medium or x-large)
	mut keyword := ?string(none)
	if editing_absolute_size_from_keyword(font_size.to_lower()) != none {
		keyword = font_size.to_lower()
	}

	// If that failed, try to interpret it as a legacy font size (e.g. 1 through 7)
	if keyword == none {
		keyword = css.parse_legacy_font_size(font_size)
	}

	// If that also failed, give up
	pixel_size := css.StyleComputer.default_user_font_size()
	resolved_keyword_ := keyword or { return pixel_size }

	// Convert the keyword to an absolute-size
	// If that failed - give up
	absolute_size := editing_absolute_size_from_keyword(resolved_keyword_) or { return pixel_size }

	// Return scaled pixel size
	return css.StyleComputer.absolute_size_mapping(absolute_size, pixel_size)
}

// https://w3c.github.io/editing/docs/execCommand/#legacy-font-size-for
pub fn legacy_font_size(pixel_size int) string {
	// 1. Let returned size be 1.
	mut returned_size := 1

	// 2. While returned size is less than 7:
	for returned_size < 7 {
		// 1. Let lower bound be the resolved value of "font-size" in pixels of a font element whose size attribute is
		//    set to returned size.
		lower_bound := font_size_to_pixel_size(returned_size.str()).to_double()

		// 2. Let upper bound be the resolved value of "font-size" in pixels of a font element whose size attribute is
		//    set to one plus returned size.
		upper_bound := font_size_to_pixel_size((returned_size + 1).str()).to_double()

		// 3. Let average be the average of upper bound and lower bound.
		average := (lower_bound + upper_bound) / 2

		// 4. If pixel size is less than average, return the one-code unit string consisting of the digit returned size.
		if f64(pixel_size) < average {
			return returned_size.str()
		}

		// 5. Add one to returned size.
		returned_size++
	}

	// 3. Return "7".
	return '7'
}
