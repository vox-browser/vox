module layout

import os

// An in-place tree update detaches the boxes it replaces and records the
// parent of each child list it changed as a layout invalidation origin
// (in_place_tree_update.v). An origin noted before its box was replaced, as
// for a style change that also rebuilt the box, then lies outside the current
// tree: its parent already stands for it. Such origins found no relayout root
// and sent the pass down the complete path, and on hydrating pages they also
// filled the origin limit (66 of 69 origins on the archived github.com/vlang/v
// page were detached).
//
// Drop detached origins before looking for roots, and apply the limit on
// separate changes to the remaining ones. Noting allows more origins, since
// only the attached ones reach the root search.
const retain_detached_layout_origins = os.getenv('VOX_RETAIN_DETACHED_LAYOUT_ORIGINS') != ''
const incremental_layout_max_noted_origins = 512

fn noted_layout_origin_limit() int {
	return if retain_detached_layout_origins {
		incremental_layout_max_origins
	} else {
		incremental_layout_max_noted_origins
	}
}

fn attached_layout_origins(origins []&Node, root &Node) []&Node {
	if retain_detached_layout_origins { return origins }
	return origins.filter(voidptr(it.root()) == voidptr(root))
}
