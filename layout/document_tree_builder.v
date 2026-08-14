module layout

import dom
import css

// A first slice of Layout::TreeBuilder::build (TreeBuilder.cpp): walk the DOM element tree and build a real
// layout tree of BlockContainer nodes, each carrying its element's computed style (from the real
// StyleComputer). Elements with `display: none` (and their subtrees) are skipped.
//
// DEFERRED to later slices: text nodes -> TextNode layout nodes; anonymous block/inline boxes; picking the
// box type from `display` (inline vs block vs flex/grid/table/replaced) instead of always BlockContainer;
// pseudo-elements; and attaching the layout node back onto the DOM element (needs a dom<->layout bridge).
pub fn build_layout_tree(document &dom.Document) ?&Node {
	root_element := document.document_element() or { return none }
	style_computer := css.css_style_computer_for(document)
	// The layout tree's root is the Viewport (whose DOM node is the Document itself); the root element's box
	// is its child. This is faithful to TreeBuilder recursing from the Document node, where
	// `is<DOM::Document>` allocates a Layout::Viewport with the document style.
	document_style := style_computer.create_document_style()
	mut viewport := unsafe { &Node(Viewport.new(document, document_style)) }
	root_element_box := build_layout_box_for_element(document, root_element, style_computer) or {
		return none
	}
	viewport.append_child(root_element_box)
	return viewport
}

// The result of laying out a document: the root layout box and the LayoutState holding every box's geometry.
pub struct DocumentLayoutResult {
pub:
	root  &Node        = unsafe { nil }
	state &LayoutState = unsafe { nil }
}

fn document_layout_update_callback(target voidptr, document &dom.Document, viewport_width f64, viewport_height f64) voidptr {
	_ = target
	result := run_document_layout(document, viewport_width, viewport_height) or {
		return unsafe { nil }
	}
	result_ptr := &DocumentLayoutResult{
		root:  result.root
		state: result.state
	}
	return voidptr(result_ptr)
}

pub fn install_document_layout_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_layout_update_hook(dom.DocumentLayoutUpdateHook{
		callback: document_layout_update_callback
	})
}

// The UsedValues (geometry) computed for `box`, if any.
pub fn (result &DocumentLayoutResult) used_values_for(box &NodeWithStyle) ?&UsedValues {
	return result.state.try_get(box)
}

// Build `document`'s layout tree and lay it out in normal block flow within a viewport of
// `viewport_width` × `viewport_height` px — the real-engine equivalent of Document::update_layout for block
// content, superseding the from-scratch layout_document. Returns none for a document with no root element.
//
// The layout root is the Viewport (the initial containing block): its content box is pinned to the viewport
// rectangle (definite in both axes), so the root element fills the viewport width and root-level percentage
// heights resolve against the viewport height. Scrollbars and non-block content (inline/flex/grid/table) are
// deferred.
pub fn run_document_layout(document &dom.Document, viewport_width f64, viewport_height f64) ?DocumentLayoutResult {
	install_document_layout_hook(document)
	root := build_layout_tree(document) or { return none }
	viewport := root.as_viewport() or { return none }
	mut state := LayoutState.new()
	layout_viewport(mut state, viewport, viewport_width, viewport_height)
	attach_layout_nodes_with_state(root, state)
	return DocumentLayoutResult{
		root:  root
		state: state
	}
}

fn build_layout_box_for_element(document &dom.Document, element &dom.Element, style_computer &css.StyleComputer) ?&Node {
	abstract_element := dom.AbstractElement.new(element, none)
	computed := style_computer.compute_style(abstract_element)

	// `display: none` produces no box (and neither do its descendants).
	if computed.display().is_none() {
		return none
	}

	// FIXME: choose the box type from the computed display; for now every element is a BlockContainer.
	mut box_node := unsafe { &Node(BlockContainer.new(document, element.as_node(), computed)) }

	// Collect this element's child layout boxes: element children become (block-level) boxes; DOM text
	// children become (inline-level) Layout::TextNodes, unless they collapse to only whitespace.
	mut children := []&Node{}
	for child_node in element.as_node().children_as_vector() {
		if child_element := child_node.as_element() {
			if child_box := build_layout_box_for_element(document, child_element, style_computer) {
				children << child_box
			}
		} else if child_node.is_text() {
			if character_data := child_node.as_character_data() {
				text := collapse_whitespace(character_data.data())
				if text.trim_space() != '' {
					children << unsafe { &Node(TextNode.new(document, child_node, text)) }
				}
			}
		}
	}

	attach_children_maintaining_inline_invariant(mut box_node, children, document, computed)
	return box_node
}

// Whether a layout node is inline-level for the purpose of the block/inline invariant. Text nodes are
// inline-level; element boxes are currently always block-level BlockContainers (box-type-from-display is
// deferred, so inline-outside element boxes aren't produced yet).
fn child_is_inline_level(node &Node) bool {
	return node.is_text_node()
}

// Attach `children` to `parent` while maintaining the CSS invariant that a block container's in-flow
// children are either all block-level or all inline-level (Layout::TreeBuilder's insertion_parent_for_*
// functions). When the children are mixed, each maximal run of inline-level children is wrapped in an
// anonymous block box (NodeWithStyle::create_anonymous_wrapper), so the parent's direct children become all
// block-level. FIXME: out-of-flow children and inline-outside element boxes aren't distinguished yet.
fn attach_children_maintaining_inline_invariant(mut parent Node, children []&Node, document &dom.Document, parent_computed &css.ComputedProperties) {
	if children.len == 0 {
		return
	}

	mut any_block := false
	mut any_inline := false
	for child in children {
		if child_is_inline_level(child) {
			any_inline = true
		} else {
			any_block = true
		}
	}

	// All inline-level (an inline formatting context) or all block-level: attach directly.
	if !any_block || !any_inline {
		parent.set_children_are_inline(any_inline && !any_block)
		for child in children {
			parent.append_child(child)
		}
		return
	}

	// Mixed: block-level children stay direct; each run of inline-level children goes into an anonymous
	// block wrapper (reusing the parent's trailing anonymous inline wrapper when possible).
	parent.set_children_are_inline(false)
	for child in children {
		if child_is_inline_level(child) {
			mut wrapper := last_anonymous_inline_wrapper_or_new(mut parent, document,
				parent_computed)
			wrapper.append_child(child)
		} else {
			parent.append_child(child)
		}
	}
}

// Return `parent`'s last child if it is an anonymous wrapper holding inline content, otherwise create such a
// wrapper, append it, and return it (Layout::TreeBuilder's last_child_creating_anonymous_wrapper_if_needed).
fn last_anonymous_inline_wrapper_or_new(mut parent Node, document &dom.Document, parent_computed &css.ComputedProperties) &Node {
	if last := parent.last_child() {
		if last.is_anonymous() && last.children_are_inline() {
			return last
		}
	}
	wrapper := create_anonymous_block_wrapper(document, parent_computed)
	parent.append_child(wrapper)
	return wrapper
}

// NodeWithStyle::create_anonymous_wrapper — an anonymous block box that carries the parent's style (so its
// inline content resolves font/line-height correctly) and whose children are inline-level. FIXME: C++ clones
// only the parent's inherited values and resets the non-inherited ones to their initial values; the port
// reuses the parent's computed style wholesale.
fn create_anonymous_block_wrapper(document &dom.Document, parent_computed &css.ComputedProperties) &Node {
	mut wrapper := BlockContainer.new(document, none, parent_computed)
	wrapper.anonymous_ = true
	wrapper.children_are_inline_ = true
	return unsafe { &Node(wrapper) }
}
