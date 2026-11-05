module main

import os

// Frozen comparisons retain the original tile sampling for every draw sharing
// a tile with these border arcs. Choosing analytic coverage for the border can
// also change image samples inside that tile, even far from the border itself.
// This is an explicit historical rendering policy, never an optimization arm.
const retain_degenerate_border_msaa = os.getenv('VOX_RETAIN_DEGENERATE_BORDER_MSAA') == '1'
const archived_border_msaa_diagnostics = os.getenv('VOX_ARCHIVED_BORDER_MSAA_DIAGNOSTICS') == '1'

__global archived_border_msaa_reported bool

fn report_archived_border_msaa() {
	if archived_border_msaa_diagnostics && !archived_border_msaa_reported {
		archived_border_msaa_reported = true
		eprintln('Vox archived border policy: retained degenerate-arc tile MSAA')
	}
}
