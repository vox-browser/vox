module css

import dom
import os

const retain_hidden_style_tree_updates = os.getenv('VOX_RETAIN_HIDDEN_STYLE_TREE_UPDATES') != ''

// No box before and none after: an element without a layout node whose new
// style is display: none (scripts, links, metadata, hidden templates), or whose
// parent renders no boxes, leaves the layout tree as it was. A new element's
// first style counts as a complete change, so each <link> or <script> a page
// inserted into <head> used to make the next layout rebuild the document's
// layout tree (about 200 million instructions on the archived
// github.com/vlang/v page). VOX_RETAIN_HIDDEN_STYLE_TREE_UPDATES=1 marks the
// parent anyway.
fn style_change_cannot_change_layout_tree(node &dom.Node, is_display_none bool) bool {
	if retain_hidden_style_tree_updates || node.unsafe_layout_node() != none { return false }
	if is_display_none { return true }
	parent := node.parent_or_shadow_host_element() or { return false }
	if parent.as_node().unsafe_layout_node() != none { return false }
	properties := parent.el_computed_properties() or { return false }
	return properties.display().is_none()
}
