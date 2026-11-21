module dom

import os

const retain_hidden_insertion_tree_updates = os.getenv('VOX_RETAIN_HIDDEN_INSERTION_TREE_UPDATES') != ''

// An element computed as display: none, without a box, renders no boxes for
// any descendant, so an insertion below it cannot change the layout tree.
// Scripts keep inserting <link>, <script> and <meta> elements into <head>,
// and each insertion used to make the next layout rebuild the document's
// layout tree (about 200 million instructions on the archived
// github.com/vlang/v page). A later display change of the element marks its
// own tree update. VOX_RETAIN_HIDDEN_INSERTION_TREE_UPDATES=1 marks it anyway.
fn (n &Node) insertion_cannot_create_boxes() bool {
	if retain_hidden_insertion_tree_updates || n.unsafe_layout_node() != none { return false }
	element := n.as_element() or { return false }
	properties := element.el_computed_properties() or { return false }
	return properties.display().is_none()
}
