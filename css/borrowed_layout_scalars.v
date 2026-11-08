module css

import os

const disable_borrowed_layout_scalars = os.getenv('VOX_DISABLE_BORROWED_LAYOUT_SCALARS') != ''
const borrowed_layout_scalar_diagnostics = os.getenv('VOX_BORROWED_LAYOUT_SCALAR_DIAGNOSTICS') != ''
__global borrowed_layout_scalars_reported bool

fn report_borrowed_layout_scalar() {
	if borrowed_layout_scalar_diagnostics && !borrowed_layout_scalars_reported {
		borrowed_layout_scalars_reported = true
		eprintln('Vox layout scalar: read concrete retained payload without copying StyleValue')
	}
}
