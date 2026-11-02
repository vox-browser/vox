module layout

import css
import os

const disable_retained_formatting_trees = os.getenv('VOX_DISABLE_RETAINED_FORMATTING_TREES') != ''
const retained_formatting_tree_diagnostics = os.getenv('VOX_RETAINED_FORMATTING_TREE_DIAGNOSTICS') != ''

__global retained_formatting_tree_reported bool

fn retained_tree_display_is_supported(display css.Display) bool {
	if display.is_flow_inside() || display.is_flow_root_inside() {
		return true
	}
	return !disable_retained_formatting_trees && !display.is_inline_outside()
		&& (display.is_flex_inside() || display.is_grid_inside())
}

fn retained_tree_is_block_formatting_container(node &Node) bool {
	return !disable_retained_formatting_trees && node.is_box()
		&& !node.display().is_inline_outside()
		&& (node.display().is_flex_inside() || node.display().is_grid_inside())
}

fn report_retained_formatting_tree(node &Node) {
	if retained_formatting_tree_diagnostics && !retained_formatting_tree_reported
		&& (node.display().is_flex_inside() || node.display().is_grid_inside()) {
		retained_formatting_tree_reported = true
		eprintln('Vox retained formatting tree: reused unchanged block grid or flex subtree; document=${node.document().url.serialize()}')
	}
}
