module platform

import os

// Font metrics and paint snapping form one archived rendering policy. The
// default keeps presenting-device metrics; frozen comparisons explicitly opt
// into the original logical grid without changing document DPR or fonts.
const retain_logical_inline_font_grid = os.getenv('VOX_RETAIN_LOGICAL_PAINT_SNAPPING') != ''
const archived_inline_font_grid_diagnostics = os.getenv('VOX_LOGICAL_PAINT_POLICY_DIAGNOSTICS') != ''

__global archived_inline_font_grid_reported bool

fn report_archived_inline_font_grid() {
	if !archived_inline_font_grid_diagnostics || archived_inline_font_grid_reported { return }
	archived_inline_font_grid_reported = true
	eprintln('Vox archived paint policy: retained logical inline font grid')
}
