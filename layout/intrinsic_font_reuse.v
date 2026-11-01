module layout

import css
import os

const disable_intrinsic_font_reuse = os.getenv('VOX_DISABLE_INTRINSIC_FONT_REUSE') != ''
const intrinsic_font_reuse_diagnostics = os.getenv('VOX_INTRINSIC_FONT_REUSE_DIAGNOSTICS') != ''

__global intrinsic_font_reuse_reported bool

fn report_intrinsic_font_reuse() {
	if intrinsic_font_reuse_diagnostics && !intrinsic_font_reuse_reported {
		intrinsic_font_reuse_reported = true
		eprintln('Vox intrinsic font reuse: retained unchanged subtree')
	}
}

fn intrinsic_subtree_fonts_are_unchanged_since(node &Node, computer &css.FontComputer, generation u64) bool {
	// Table fixup and hoisted positioned boxes can refer outside their parent
	// chain. Those probes keep the ordinary font-epoch invalidation path.
	if containing := node.containing_block() {
		if !unsafe { &Node(containing) }.is_inclusive_ancestor_of(node) { return false }
	}
	if !node.computed_values().cached_font_inputs_are_unchanged_since(computer, generation) {
		return false
	}
	for child in node.children() {
		if !intrinsic_subtree_fonts_are_unchanged_since(child, computer, generation) { return false }
	}
	return true
}

fn intrinsic_fonts_are_unchanged_since(node &Node, generation u64) bool {
	computer := css.css_style_computer_for(node.document()).font_computer()
	if !intrinsic_subtree_fonts_are_unchanged_since(node, computer, generation) { return false }
	// Ancestor fonts also supply relative metric bases, including root `rlh`
	// units. Ordinary style/tree changes already reset the intrinsic cache.
	mut ancestor := node.parent()
	for ancestor != none {
		parent := ancestor or { return false }
		if !parent.computed_values().cached_font_inputs_are_unchanged_since(computer, generation) {
			return false
		}
		ancestor = parent.parent()
	}
	return true
}
