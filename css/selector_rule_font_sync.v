module css

import os

const retain_selector_rule_font_sync = os.getenv('VOX_RETAIN_SELECTOR_RULE_FONT_SYNC') != ''
const selector_rule_font_sync_diagnostics = os.getenv('VOX_SELECTOR_RULE_FONT_SYNC_DIAGNOSTICS') != ''

__global selector_rule_font_sync_reported bool

// Adding or removing selectors does not change the stylesheet's font
// registrations or their order. Media-query changes still synchronize fonts
// in evaluate_media_queries(), before owner invalidation returns. Keep the
// full path for font registrations, imports and other global rule types.
fn (mut sheet CSSStyleSheet) synchronize_fonts_after_selector_rule_change(rule &CSSRule) {
	if !retain_selector_rule_font_sync && !sheet.constructed
		&& conditional_style_rule_tree_has_only_selectors(rule) {
		if owner := sheet.base.owner_node {
			if owner.as_node().is_html_style_element() {
				if selector_rule_font_sync_diagnostics && !selector_rule_font_sync_reported {
					selector_rule_font_sync_reported = true
					eprintln('Vox selector rule fonts: retained unchanged font registrations')
				}
				return
			}
		}
	}
	sheet.synchronize_fonts_after_rule_change()
}
