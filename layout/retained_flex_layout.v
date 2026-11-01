module layout

import os

const disable_retained_flex_layout = os.getenv('VOX_DISABLE_RETAINED_FLEX_LAYOUT') != ''
const retained_flex_layout_diagnostics = os.getenv('VOX_RETAINED_FLEX_LAYOUT_DIAGNOSTICS') != ''

__global retained_flex_layout_reported bool

fn retained_context_allows_flex(node &Node) bool {
	return !disable_retained_flex_layout && node.display().is_flex_inside()
}

fn report_retained_flex_layout(inputs []RetainedInlineInput) {
	if !retained_flex_layout_diagnostics || retained_flex_layout_reported { return }
	for input in inputs {
		if input.node.display().is_flex_inside() {
			retained_flex_layout_reported = true
			eprintln('Vox retained flex layout: reused unchanged independent geometry')
			return
		}
	}
}
