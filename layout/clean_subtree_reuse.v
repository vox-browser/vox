module layout

import css
import dom
import os

// Clean subtree reuse. Node.set_needs_layout_tree_update() flags a DOM node
// whose whole box subtree must be rebuilt and marks every flat-tree ancestor
// as having such a descendant. A node without either flag whose ancestors
// carry only the descendant mark therefore still owns the boxes the previous
// build produced for it, exactly as when no tree rebuild runs at all.
// TreeBuilder upstream keeps those boxes. Keep them here as well, instead of
// constructing an equal subtree whose new node identities discard every
// retained shaping, measurement and committed-geometry record.
//
// retained_flow_subtrees.v separately salvages validated ordinary subtrees
// below a flagged ancestor, where the flags promise nothing.
//
// Box kinds whose content is produced by the builder from state outside the
// subtree (counters, quotes, referenced SVG resources) or by a control's
// internal model keep the complete builder path.
const disable_clean_subtree_reuse = os.getenv('VOX_DISABLE_CLEAN_SUBTREE_REUSE') != ''
// Same-binary controls: build everything below a flagged ancestor again, and
// keep an SVG only when the validated salvage would.
const disable_below_flagged_reuse = os.getenv('VOX_DISABLE_BELOW_FLAGGED_REUSE') != ''
const retain_salvage_svg_checks = os.getenv('VOX_RETAIN_SALVAGE_SVG_CHECKS') != ''
const clean_subtree_reuse_diagnostics = os.getenv('VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS') != ''

__global clean_subtree_reuse_counts [3]u64
// Tests of the validated salvage (retained_flow_subtrees.v) suspend this path
// so that their unflagged branches reach it.
__global clean_subtree_reuse_suspended bool

// Kept subtree roots, their boxes, and rejected candidates in this process.
pub fn clean_subtree_reuse_statistics() (u64, u64, u64) {
	return clean_subtree_reuse_counts[0], clean_subtree_reuse_counts[1], clean_subtree_reuse_counts[2]
}

fn report_clean_subtree_reuse() {
	if !clean_subtree_reuse_diagnostics { return }
	eprintln('VOX_CLEAN_SUBTREE_REUSE roots=${clean_subtree_reuse_counts[0]} boxes=${clean_subtree_reuse_counts[1]} rejected=${clean_subtree_reuse_counts[2]}')
	c := rebuilt_element_counts
	eprintln('VOX_REBUILT_ELEMENTS unboxed=${c[0]} flagged=${c[1]} flagged_descendant=${c[2]} child_of_flagged=${c[3]} below_flagged=${c[4]} clean=${c[5]}')
}

// VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS: why each element that did not keep
// its boxes was built again. `below_flagged` elements have no flag in their
// own subtree and an unflagged parent, under a flagged ancestor further up.
__global rebuilt_element_counts [6]u64

fn note_rebuilt_element(element &dom.Element, builder &TreeBuilderState) {
	node := element.as_node()
	mirror := node.unsafe_layout_node() or {
		rebuilt_element_counts[0]++
		return
	}
	if mirror.real_layout_handle() == unsafe { nil } {
		rebuilt_element_counts[0]++
	} else if node.needs_layout_tree_update_() {
		rebuilt_element_counts[1]++
	} else if node.child_needs_layout_tree_update_() {
		rebuilt_element_counts[2]++
	} else if builder.flagged_ancestor_depth > 0 {
		parent_flagged := if parent := node.parent_or_shadow_host() { parent.needs_layout_tree_update_() } else { false }
		rebuilt_element_counts[if parent_flagged { 3 } else { 4 }]++
	} else {
		rebuilt_element_counts[5]++
	}
}

fn reject_clean_subtree(element &dom.Element, reason string, mut builder TreeBuilderState) ?&Node {
	builder.clean_subtree_rejections[u64(voidptr(element))] = true
	if clean_subtree_reuse_diagnostics {
		clean_subtree_reuse_counts[2]++
		if os.getenv('VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS') == 'reasons' {
			eprintln('VOX_CLEAN_SUBTREE_REUSE rejected=${reason} element=${element.local_name()} detail=${clean_subtree_rejection_detail(element, reason)}')
		}
	}
	return none
}

// VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS=reasons: the first condition that
// keeps an SVG, replaced or restyled subtree on the complete builder.
fn clean_subtree_rejection_detail(element &dom.Element, reason string) string {
	mirror := element.as_node().unsafe_layout_node() or { return 'unboxed' }
	if mirror.real_layout_handle() == unsafe { nil } { return 'unboxed' }
	root := unsafe { &Node(mirror.real_layout_handle()) }
	match reason {
		'svg' { return clean_subtree_svg_detail(root) }
		'replaced' { return clean_subtree_replaced_detail(root) }
		'style' {
			computed := css.computed_properties_for_element(element) or { return 'unstyled' }
			return if root.display() != computed.display() { 'display' } else { 'inputs class=${element.get_attribute_value('class').limit(48)}' }
		}
		else { return '' }
	}
}

fn clean_subtree_svg_detail(node &Node) string {
	if node.is_svg_svg_box() {
		owner := node.dom_node() or { return 'anonymous-svg' }
		element := owner.as_element() or { return 'anonymous-svg' }
		return clean_subtree_svg_element_detail(element)
	}
	if node.is_svg_box() { return 'bare-svg-box' }
	for child in node.children() {
		detail := clean_subtree_svg_detail(child)
		if detail != '' { return detail }
	}
	return ''
}

fn clean_subtree_svg_element_detail(element &dom.Element) string {
	name := element.local_name()
	if !element.is_svg_element() { return 'foreign:${name}' }
	if name !in ['svg', 'g', 'path', 'rect', 'circle', 'ellipse', 'line', 'polyline', 'polygon'] {
		return 'element:${name}'
	}
	if list := element.attribute_list() {
		for index in 0 .. list.length() {
			attribute := list.item(index) or { return 'attribute' }
			if attribute.local_name() == 'href' { return 'href' }
			if attribute.value().contains('url(') { return 'url:${attribute.local_name()}' }
		}
	}
	dom_node := element.as_node()
	if dom_node.needs_layout_tree_update_() || dom_node.child_needs_layout_tree_update_() { return 'flagged:${name}' }
	computed := css.computed_properties_for_element(element) or { return 'unstyled:${name}' }
	if computed.display().is_none() { return 'display-none:${name}' }
	if computed.content_visibility() != .visible { return 'content-visibility' }
	layout_node := dom_node.unsafe_layout_node() or { return 'unboxed:${name}' }
	if layout_node.real_layout_handle() == unsafe { nil } { return 'unboxed:${name}' }
	typed := unsafe { &Node(layout_node.real_layout_handle()) }
	if !retained_flow_svg_node_is_ordinary(typed) {
		return if typed.document().is_svg_image_document() {
			'image-document'
		} else if typed.is_floating() {
			'floating'
		} else if typed.is_in_ua_internal_shadow_tree() {
			'ua-shadow'
		} else if !retained_layout_position_is_unshifted(typed) {
			'shifted:${name}'
		} else if !retained_simple_svg_style_is_closed(typed) {
			'open-style:${name}'
		} else {
			clean_subtree_svg_ordinary_detail(typed, element)
		}
	}
	if !retained_flow_style_matches(typed, computed) { return 'restyled:${name}' }
	if typed.display() != computed.display() { return 'display:${name}' }
	for child in dom_node.children {
		if value := child.as_element() {
			detail := clean_subtree_svg_element_detail(value)
			if detail != '' { return detail }
		} else if !child.is_text() {
			return 'child-node:${name}'
		} else if (child.text_content() or { '' }).trim_space() != '' {
			return 'text:${name}'
		}
	}
	return ''
}

fn clean_subtree_replaced_detail(node &Node) string {
	if node.is_replaced_box() && !retained_flow_raster_image_is_ordinary(node) {
		if node.has_children() { return 'children' }
		box := node.as_image_box() or { return 'not-image:${layout_debug_tag(node)}' }
		if box.uses_content_replacement() { return 'content-replacement' }
		if box.svg_image_document() != none { return 'svg-image' }
		owner := node.dom_node() or { return 'anonymous' }
		if !owner.is_html_image_element() { return 'not-img:${layout_debug_tag(node)}' }
		element := owner.as_element() or { return 'anonymous' }
		if available_html_svg_image_document(element) != none { return 'svg-image-available' }
		return 'unavailable-image'
	}
	for child in node.children() {
		detail := clean_subtree_replaced_detail(child)
		if detail != '' { return detail }
	}
	return ''
}

// The boxes of `element` from the previous build, when the invalidation flags
// guarantee that a rebuild would construct the same subtree.
fn reusable_clean_subtree(element &dom.Element, mut builder TreeBuilderState) ?&Node {
	if disable_clean_subtree_reuse || clean_subtree_reuse_suspended { return none }
	dom_root := element.as_node()
	if dom_root.needs_layout_tree_update_() || dom_root.child_needs_layout_tree_update_() {
		return none
	}
	if builder.flagged_ancestor_depth > 0 {
		// Below a flagged ancestor. A flag raised for a removed child or for a
		// style that needs another box speaks of that node's box and its list of
		// children; which child caused it is not recorded, so each direct child
		// is built again. Deeper nodes with an unflagged parent are as clean as
		// below unflagged ancestors. Any other reason covers the whole subtree.
		if disable_below_flagged_reuse || builder.covering_flag_depth > 0 || builder.flagged_parent {
			return none
		}
		if parent := dom_root.parent_or_shadow_host() {
			if parent.needs_layout_tree_update_() { return none }
		}
	}
	if builder.clean_subtree_rejections[u64(voidptr(element))] { return none }
	if !element.is_html_element() || element.rendered_in_top_layer() {
		return reject_clean_subtree(element, 'element', mut builder)
	}
	// Slotted content and SVG references instantiate boxes away from the DOM
	// position that owns their invalidation flags.
	mut ancestor := dom_root.parent_or_shadow_host()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_shadow_root() { return reject_clean_subtree(element, 'shadow-tree', mut builder) }
		if parent_element := current.as_element() {
			if !parent_element.is_html_element() {
				return reject_clean_subtree(element, 'foreign-ancestor', mut builder)
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	computed := css.computed_properties_for_element(element) or {
		return reject_clean_subtree(element, 'unstyled', mut builder)
	}
	// Unboxed elements keep the ordinary path, which consumes their children.
	if computed.display().is_none() || computed.display().is_contents() { return none }
	if computed.content_visibility() != .visible {
		return reject_clean_subtree(element, 'content-visibility', mut builder)
	}
	mirror := dom_root.unsafe_layout_node() or {
		return reject_clean_subtree(element, 'unboxed', mut builder)
	}
	if mirror.real_layout_handle() == unsafe { nil } || mirror.continuation_next() != none {
		return reject_clean_subtree(element, 'continuation', mut builder)
	}
	root := unsafe { &Node(mirror.real_layout_handle()) }
	if root.is_anonymous() || voidptr(root.document()) != voidptr(element.document())
		|| root.as_node_with_style() == none {
		return reject_clean_subtree(element, 'box', mut builder)
	}
	// A box left over from an older tree (its element was detached or not
	// rendered meanwhile) describes content the flags no longer speak of.
	if root.tree_root_ != builder.previous_tree_root || builder.previous_tree_root == unsafe { nil } {
		return reject_clean_subtree(element, 'older-tree', mut builder)
	}
	// The previous parent placed this box directly; an anonymous wrapper there
	// belongs to that parent's construction and is not part of this subtree.
	mut parent := root.parent() or { return reject_clean_subtree(element, 'detached', mut builder) }
	if parent.is_anonymous() {
		if !clean_subtree_wrapper_is_rebuilt_by_parent(parent) {
			return reject_clean_subtree(element, 'anonymous-parent', mut builder)
		}
		parent = parent.parent() or { return reject_clean_subtree(element, 'detached', mut builder) }
	}
	parent_dom := parent.dom_node() or { return reject_clean_subtree(element, 'parent', mut builder) }
	dom_parent := dom_root.parent() or { return reject_clean_subtree(element, 'parent', mut builder) }
	if voidptr(parent_dom) != voidptr(dom_parent) {
		return reject_clean_subtree(element, 'parent', mut builder)
	}
	// A display change is reported on the parent that owns the insertion.
	if !retained_flow_style_matches(root, computed) || root.display() != computed.display() {
		return reject_clean_subtree(element, 'style', mut builder)
	}
	mut boxes := 0
	if reason := clean_subtree_blocker(root, mut boxes) {
		return reject_clean_subtree(element, reason, mut builder)
	}
	mut elements := []&dom.Element{}
	if !collect_clean_subtree_elements(element, mut elements) {
		return reject_clean_subtree(element, 'dom', mut builder)
	}
	// Block-level generated boxes of inline elements are hoisted out of their
	// inline ancestors, possibly into the previous parent's child list.
	if root.is_inline_node() {
		for candidate in elements {
			if retained_flow_element_has_generated_pseudo_style(candidate) {
				return reject_clean_subtree(element, 'hoisted-pseudo', mut builder)
			}
		}
	}
	resolve_retained_flow_counters(RetainedFlowSubtree{
		root:     root
		elements: elements
	}, mut builder)
	clean_subtree_reuse_counts[0]++
	clean_subtree_reuse_counts[1] += u64(boxes)
	return root
}

// Same-binary control: a box that the previous build placed in an anonymous
// wrapper keeps the complete builder.
const retain_wrapped_subtree_rebuilds = os.getenv('VOX_RETAIN_WRAPPED_SUBTREE_REBUILDS') != ''

// An anonymous block that wraps an inline run beside block siblings belongs
// to the construction of its parent's box, which wraps the kept inline-level
// boxes again when it is rebuilt. Other wrappers (generated, table, button and
// fieldset fixups) keep the complete builder.
fn clean_subtree_wrapper_is_rebuilt_by_parent(wrapper &Node) bool {
	if retain_wrapped_subtree_rebuilds || !wrapper.is_anonymous() || !wrapper.children_are_inline()
		|| wrapper.is_generated_for_pseudo_element() || wrapper.is_table_wrapper()
		|| wrapper.as_block_container() == none {
		return false
	}
	parent := wrapper.parent() or { return false }
	return !parent.is_anonymous() && parent.dom_node() != none
}

// The first box in `node`'s subtree that the builder derives from state the
// invalidation flags of this subtree do not cover.
fn clean_subtree_blocker(node &Node, mut boxes &int) ?string {
	unsafe {
		*boxes = *boxes + 1
	}
	if node.is_text_node() {
		text := node.as_text_node() or { return 'text' }
		if text.first_letter_ != none || text.source_range_length_ != none { return 'first-letter' }
		return none
	}
	if is_svg_resource_box(node) { return 'svg-resource' }
	if node.is_svg_svg_box() {
		// An SVG viewport snapshots its natural metrics when constructed, and
		// referenced resources, text and animations are instantiated by the
		// builder. Keep only the closed shape trees the validated salvage keeps.
		owner := node.dom_node() or { return 'svg' }
		element := owner.as_element() or { return 'svg' }
		mut svg_elements := 0
		if disable_retained_flow_svg_trees || !clean_subtree_svg_is_closed(element, mut svg_elements) {
			return 'svg'
		}
		return none
	}
	if node.is_svg_box() { return 'svg' }
	if node.is_replaced_box() {
		// The image provider can change kind or availability without a style
		// change; alternative text, SVG documents and CSS replacements keep
		// the complete builder.
		if !retained_flow_raster_image_is_ordinary(node) && !retained_svg_image_box_is_current(node) {
			return 'replaced'
		}
	}
	if node.is_generated_text_node() { return none }
	if node.is_generated_for_pseudo_element() && generated_content_uses_document_state(node) {
		return 'generated-content'
	}
	if node.is_list_item_marker_box() {
		if !retained_flow_marker_box_is_built_alike(node) {
			return if clean_subtree_reuse_diagnostics {
				'marker:${retained_flow_marker_rejection(node)}'
			} else {
				'marker'
			}
		}
		refresh_kept_marker_style(node)
		return none
	}
	if node.is_list_item_box() && !retained_flow_list_item_box_is_built_alike(node) { return 'list-item' }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return 'continuation' }
	}
	if owner := node.dom_node() {
		if !node.is_anonymous() && !node.is_generated_for_pseudo_element() {
			if element := owner.as_element() {
				if element.is_html_element() && element.local_name() in ['input', 'textarea', 'select',
					'progress', 'meter', 'fieldset', 'legend', 'iframe', 'object', 'embed', 'canvas',
					'video', 'audio', 'marquee'] && !input_tree_is_current(element) {
					return 'control'
				}
				if element.rendered_in_top_layer() { return 'top-layer' }
			}
		}
	}
	for child in node.children() {
		if reason := clean_subtree_blocker(child, mut boxes) { return reason }
	}
	return none
}

// The subtree's elements in the order the builder resolves their counters:
// the flat tree, without the descendants of unboxed elements.
fn collect_clean_subtree_elements(element &dom.Element, mut elements []&dom.Element) bool {
	node := element.as_node()
	if node.needs_layout_tree_update_() || node.child_needs_layout_tree_update_() { return false }
	computed := css.computed_properties_for_element(element) or { return false }
	if computed.display().is_none() { return true }
	elements << element
	if computed.content_visibility() == .hidden { return true }
	for child in layout_tree_child_candidates(element) {
		if child_element := child.as_element() {
			if child_element.rendered_in_top_layer() { continue }
			if !collect_clean_subtree_elements(child_element, mut elements) { return false }
		}
	}
	return true
}

// retained_simple_svg.v's closed shape tree and retained_flow_svg_trees.v's
// node validation, without recording the attribute snapshot those keep for
// later passes: the invalidation flags already cover this subtree.
fn clean_subtree_svg_is_closed(element &dom.Element, mut count &int) bool {
	unsafe {
		*count = *count + 1
	}
	if !element.is_svg_element() || element.local_name() !in ['svg', 'g', 'path', 'rect', 'circle',
		'ellipse', 'line', 'polyline', 'polygon'] || *count > 128
		|| element.attribute_list_size() > 256 || element.as_node().children.len > 256 {
		return false
	}
	if list := element.attribute_list() {
		for index in 0 .. list.length() {
			attribute := list.item(index) or { return false }
			if attribute.local_name() == 'href' || attribute.value().contains('url(') { return false }
		}
	}
	dom_node := element.as_node()
	if dom_node.needs_layout_tree_update_() || dom_node.child_needs_layout_tree_update_() { return false }
	computed := css.computed_properties_for_element(element) or { return false }
	if computed.display().is_none() || computed.content_visibility() != .visible { return false }
	layout_node := dom_node.unsafe_layout_node() or { return false }
	if layout_node.real_layout_handle() == unsafe { nil } || layout_node.continuation_next() != none {
		return false
	}
	typed := unsafe { &Node(layout_node.real_layout_handle()) }
	if voidptr(typed.document()) != voidptr(element.document()) || !clean_subtree_svg_node_is_current(typed, element)
		|| !retained_flow_style_matches(typed, computed) || typed.display() != computed.display() {
		return false
	}
	for child in dom_node.children {
		if value := child.as_element() {
			if !clean_subtree_svg_is_closed(value, mut count) { return false }
		} else if !child.is_text() || (child.text_content() or { '' }).trim_space() != '' {
			return false
		}
	}
	return true
}

// Whether a generated box's `content` is produced from counters, the quote
// depth, an attribute or an image rather than authored strings alone.
// Counters and quote depth come from the document order outside the box.
fn generated_content_uses_document_state(node &Node) bool {
	value := node.computed_values().property(.content, .yes) or { return false }
	text := value.css_text
	return text.contains('counter') || text.contains('quote') || text.contains('url(')
		|| text.contains('image') || text.contains('gradient') || text.contains('attr(')
}

// The later conditions of retained_flow_svg_node_is_ordinary().
fn clean_subtree_svg_ordinary_detail(node &Node, element &dom.Element) string {
	name := element.local_name()
	owner := node.dom_node() or { return 'no-owner:${name}' }
	mirror := owner.unsafe_layout_node() or { return 'no-mirror:${name}' }
	if mirror.real_layout_handle() != voidptr(node) { return 'mirror:${name}' }
	mut parent := node.parent()
	mut parent_matches := false
	for parent != none {
		candidate := parent or { break }
		if dom_parent := candidate.dom_node() {
			actual := owner.parent() or { return 'detached:${name}' }
			parent_matches = voidptr(dom_parent) == voidptr(actual)
			if !parent_matches {
				return 'parent:${name} box-parent=${layout_debug_tag(candidate)} generated=${candidate.is_generated_for_pseudo_element()}'
			}
			break
		}
		if !candidate.is_anonymous() { return 'unowned-parent:${name}' }
		parent = candidate.parent()
	}
	if !parent_matches { return 'no-parent:${name}' }
	style := node.computed_values()
	if style.has_animated_properties() { return 'animated:${name}' }
	if style.content_visibility() != .visible { return 'content-visibility:${name}' }
	if !style.display().is_flow_inside() && !style.display().is_flow_root_inside() {
		return 'display-inside:${name}=${style.display().to_string()}'
	}
	if node.is_svg_svg_box() {
		box := node.as_box() or { return 'no-box:${name}' }
		natural := negotiate_svg_natural_metrics(element)
		if box.natural_size_ != natural { return 'natural-size:${name}' }
		if box.auto_content_box_size_ != natural { return 'auto-size:${name}' }
	}
	return 'not-ordinary:${name}'
}

// What an SVG box takes from its element when constructed that no
// invalidation flag covers: its binding to that element and, for a viewport,
// the natural metrics it snapshots. Paints that reference other elements are
// instantiated by the builder. The salvage's conditions on position, display
// and animation concern geometry it carries over, which this path does not.
fn clean_subtree_svg_node_is_current(node &Node, element &dom.Element) bool {
	if retain_salvage_svg_checks { return retained_flow_svg_node_is_ordinary(node) }
	if disable_retained_flow_svg_trees || (!node.is_svg_box() && !node.is_svg_svg_box())
		|| node.document().is_svg_image_document() || node.is_in_ua_internal_shadow_tree()
		|| !retained_simple_svg_style_is_closed(node) {
		return false
	}
	owner := node.dom_node() or { return false }
	if voidptr(owner) != voidptr(element.as_node()) { return false }
	mirror := owner.unsafe_layout_node() or { return false }
	if mirror.real_layout_handle() != voidptr(node) { return false }
	if node.is_svg_svg_box() {
		box := node.as_box() or { return false }
		natural := negotiate_svg_natural_metrics(element)
		if box.natural_size_ != natural || box.auto_content_box_size_ != natural { return false }
	}
	return true
}
