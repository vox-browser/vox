module layout

import css
import os

const disable_live_pending_layout_reuse = os.getenv('VOX_DISABLE_LIVE_PENDING_LAYOUT_REUSE') != ''
const live_pending_layout_diagnostics = os.getenv('VOX_LIVE_PENDING_LAYOUT_DIAGNOSTICS') != ''

__global live_pending_layout_reported bool

fn retained_pending_layout_cascade_is_current(input RetainedInlineInput,
	previous &css.FontCascadeList, current &css.FontCascadeList,
	style &css.ComputedValues, computer &css.FontComputer) bool {
	return !disable_live_pending_layout_reuse && current.pending_faces.len > 0
		&& voidptr(previous) == voidptr(current)
		&& style.cached_font_inputs_are_unchanged_since(computer, input.font_generation)
}

fn report_live_pending_layout_reuse() {
	if live_pending_layout_diagnostics && !live_pending_layout_reported {
		live_pending_layout_reported = true
		eprintln('Vox pending layout reuse: retained original live cascade geometry')
	}
}
