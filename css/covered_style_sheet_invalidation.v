module css

import dom
import os

const retain_covered_style_sheet_walk = os.getenv('VOX_RETAIN_COVERED_STYLE_SHEET_WALK') != ''
const covered_style_sheet_diagnostics = os.getenv('VOX_COVERED_STYLE_SHEET_DIAGNOSTICS') != ''

__global covered_style_sheet_reported bool

fn style_sheet_primary_invalidation_is_covered(root &dom.Node, result &StyleSheetInvalidationSet) bool {
	if retain_covered_style_sheet_walk || !root.is_document()
		|| !root.document().needs_full_style_update()
		|| result.pseudo_element_rules.len != 0 || result.trailing_universal_rules.len != 0 {
		return false
	}
	// A pending full cascade covers every connected element. An in-progress
	// cascade may already have visited some of them, so keep the ordinary walk
	// while its computed-property publication batch is active.
	bridge := root.document().style_computer
	if bridge == unsafe { nil } || bridge.css_handle == unsafe { nil } { return false }
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	if computer.computed_property_page_batch_depth_ != 0 { return false }
	return true
}

fn report_covered_style_sheet_invalidation() {
	if covered_style_sheet_diagnostics && !covered_style_sheet_reported {
		covered_style_sheet_reported = true
		eprintln('Vox stylesheet invalidation: pending full cascade covers primary walk (render requested)')
	}
}
