module layout

import dom
import html

fn test_committed_inline_paintables_match_fresh_geometry_for_nested_empty_and_fragmented_inlines() {
	mut document := html.parse_document('<!doctype html><style>p{width:100px}#vertical{writing-mode:vertical-rl;height:100px}</style><p><a id="empty"></a><span id="nested"><b>nested words that wrap over several lines</b></span><span id="direct">direct words that wrap over several lines</span></p><p id="vertical"><span>vertical <b>nested text</b></span><a></a></p>')
	defer { document.finalize() }
	for width in [320, 180] {
		_ = layout_document_typed_in_viewport(document, f64(width), 200)
		result := document_layout_result(document)?
		result.root.for_each_in_inclusive_subtree(fn [result] (node &Node) dom.TraversalDecision {
			mirror := node.dom_layout_node_
			if mirror != unsafe { nil } {
				assert mirror.paintables_.len == layout_debug_paintable_count(node, result.state)
				assert layout_debug_paintable_count_with_inline_geometry(node, result.state,
					mirror.has_geometry_) == layout_debug_paintable_count(node, result.state)
			}
			return .@continue
		})
		assert document.get_element_by_id('empty')?.as_node().layout_node()?.paintables_.len == 1
		assert document.get_element_by_id('direct')?.as_node().layout_node()?.paintables_.len > 1
	}
}
