module css

import os
import sync.stdatomic

const retain_numeric_dimension_iteration = os.getenv('VOX_RETAIN_NUMERIC_DIMENSION_ITERATION') != ''
const numeric_dimension_diagnostics = os.getenv('VOX_NUMERIC_DIMENSION_DIAGNOSTICS') != ''

__global numeric_dimension_reported stdatomic.AtomicVal[bool]

fn report_numeric_dimension_direct() {
	if numeric_dimension_diagnostics && numeric_dimension_reported.compare_and_swap(false, true) {
		eprintln('Vox numeric dimension: evaluated exponents directly')
	}
}
