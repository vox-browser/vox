module css

import dom
import os

const retain_dirty_stylesheet_traversal = os.getenv('VOX_RETAIN_DIRTY_STYLESHEET_TRAVERSAL') != ''
const dirty_stylesheet_traversal_diagnostics = os.getenv('VOX_DIRTY_STYLESHEET_TRAVERSAL_DIAGNOSTICS') != ''

__global dirty_stylesheet_reported_document dom.UniqueNodeID

// A whole-subtree invalidation already forces a fresh cascade for every
// descendant. Primary and pseudo-element anchors only mark their subjects.
// Trailing universal combinators can instead mark siblings or table columns
// outside this subtree, so keep their complete traversal.
fn style_sheet_invalidation_subtree_is_covered(node &dom.Node, result &StyleSheetInvalidationSet) bool {
	if retain_dirty_stylesheet_traversal || !node.entire_subtree_needs_style_update()
		|| result.trailing_universal_rules.len != 0 {
		return false
	}
	if dirty_stylesheet_traversal_diagnostics {
		document := node.document()
		identity := document.as_node().unique_id()
		if dirty_stylesheet_reported_document != identity {
			dirty_stylesheet_reported_document = identity
			eprintln('Vox stylesheet invalidation: skipped already dirty subtree; document=${document.url.serialize()}')
		}
	}
	return true
}
