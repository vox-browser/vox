module layout

import os

const disable_retained_block_rejection_cache = os.getenv('VOX_DISABLE_RETAINED_BLOCK_REJECTION_CACHE') != ''
const retained_block_rejection_diagnostics = os.getenv('VOX_RETAINED_BLOCK_REJECTION_DIAGNOSTICS') != ''

__global retained_block_rejection_reported bool

// A failed probe only selects the complete layout algorithm. Remembering that
// decision cannot restore stale geometry, even if an image becomes available
// during this pass. A new LayoutState rechecks every candidate on the next pass.
fn remember_rejected_block_input(mut rejected map[u64]bool, key u64) {
	if disable_retained_block_rejection_cache { return }
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	rejected[key] = true
}

fn report_retained_block_rejection() {
	if retained_block_rejection_diagnostics && !retained_block_rejection_reported {
		retained_block_rejection_reported = true
		eprintln('Vox retained block eligibility: reused complete-layout decision')
	}
}
