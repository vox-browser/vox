module main

import dom
import os

// Frozen captures can retain the earlier inline-SVG layout fallback while
// preserving document DPR, native capture density and current default behavior.
// The policy must be identical in both measured arms and earns no engine credit.
const retain_css_layout_for_svg = os.getenv('VOX_RETAIN_CSS_LAYOUT_FOR_SVG') != ''
const archived_svg_layout_diagnostics = os.getenv('VOX_ARCHIVED_SVG_LAYOUT_DIAGNOSTICS') != ''

__global archived_svg_layout_reported bool

fn report_archived_svg_layout(document &dom.Document) {
	if !archived_svg_layout_diagnostics || archived_svg_layout_reported { return }
	archived_svg_layout_reported = true
	eprintln('Vox archived SVG layout: retained CSS-coordinate fallback; document=${document.url.serialize()}')
}
