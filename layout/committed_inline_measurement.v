module layout

import os

const disable_committed_inline_measurement_reuse = os.getenv('VOX_DISABLE_COMMITTED_INLINE_MEASUREMENT_REUSE') != ''
const committed_inline_measurement_diagnostics = os.getenv('VOX_COMMITTED_INLINE_MEASUREMENT_DIAGNOSTICS') != ''

__global committed_inline_measurement_reported bool

fn report_committed_inline_measurement_reuse() {
	if committed_inline_measurement_diagnostics && !committed_inline_measurement_reported {
		committed_inline_measurement_reported = true
		eprintln('Vox inline measurement: promoted measured text into committed geometry')
	}
}
