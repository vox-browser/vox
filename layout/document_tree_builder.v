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
	return build_layout_box_for_element(document, root_element, style_computer)
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
		child_element := child_node.as_element() or { continue }
		if child_box := build_layout_box_for_element(document, child_element, style_computer) {
			box_node.append_child(child_box)
		}
	}

	return box_node
}
