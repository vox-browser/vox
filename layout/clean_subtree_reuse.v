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
}

fn reject_clean_subtree(element &dom.Element, reason string, mut builder TreeBuilderState) ?&Node {
	builder.clean_subtree_rejections[u64(voidptr(element))] = true
	if clean_subtree_reuse_diagnostics {
		clean_subtree_reuse_counts[2]++
		if os.getenv('VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS') == 'reasons' {
			eprintln('VOX_CLEAN_SUBTREE_REUSE rejected=${reason} element=${element.local_name()}')
		}
	}
	return none
}

// The boxes of `element` from the previous build, when the invalidation flags
// guarantee that a rebuild would construct the same subtree.
fn reusable_clean_subtree(element &dom.Element, mut builder TreeBuilderState) ?&Node {
	if disable_clean_subtree_reuse || clean_subtree_reuse_suspended || builder.flagged_ancestor_depth > 0 {
		return none
	}
	dom_root := element.as_node()
	if dom_root.needs_layout_tree_update_() || dom_root.child_needs_layout_tree_update_() {
		return none
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
	// The previous parent placed this box directly; an anonymous wrapper there
	// belongs to that parent's construction and is not part of this subtree.
	parent := root.parent() or { return reject_clean_subtree(element, 'detached', mut builder) }
	if parent.is_anonymous() { return reject_clean_subtree(element, 'anonymous-parent', mut builder) }
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
		if !retained_flow_raster_image_is_ordinary(node) { return 'replaced' }
	}
	if node.is_generated_text_node() { return none }
	if node.is_generated_for_pseudo_element() && generated_content_uses_document_state(node) {
		return 'generated-content'
	}
	if node.is_list_item_marker_box() {
		if !retained_flow_marker_box_is_static(node) { return 'marker' }
		return none
	}
	if node.is_list_item_box() && !retained_flow_list_item_box_is_static(node) { return 'list-item' }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return 'continuation' }
	}
	if owner := node.dom_node() {
		if !node.is_anonymous() && !node.is_generated_for_pseudo_element() {
			if element := owner.as_element() {
				if element.is_html_element() && element.local_name() in ['input', 'textarea', 'select',
					'progress', 'meter', 'fieldset', 'legend', 'iframe', 'object', 'embed', 'canvas',
					'video', 'audio', 'marquee'] {
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
	if voidptr(typed.document()) != voidptr(element.document()) || !retained_flow_svg_node_is_ordinary(typed)
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
