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
	root := build_layout_tree(document) or { return none }
	viewport := root.as_viewport() or { return none }
	mut state := LayoutState.new()
	layout_viewport(mut state, viewport, viewport_width, viewport_height)
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

	for child_node in element.as_node().children_as_vector() {
		if child_element := child_node.as_element() {
			if child_box := build_layout_box_for_element(document, child_element, style_computer) {
				box_node.append_child(child_box)
			}
		} else if child_node.is_text() {
			// A DOM text node becomes a Layout::TextNode, unless it collapses to only whitespace.
			if character_data := child_node.as_character_data() {
				text := collapse_whitespace(character_data.data())
				if text.trim_space() != '' {
					mut text_box := unsafe { &Node(TextNode.new(document, child_node, text)) }
					box_node.append_child(text_box)
				}
			}
		}
	}

	return box_node
}
