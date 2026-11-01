module css

import os

const disable_leaf_substitution_skip = os.getenv('VOX_DISABLE_LEAF_SUBSTITUTION_SKIP') != ''
const leaf_substitution_diagnostics = os.getenv('VOX_LEAF_SUBSTITUTION_DIAGNOSTICS') != ''

__global leaf_substitution_skip_reported bool

fn report_leaf_substitution_skip() {
	if leaf_substitution_diagnostics && !leaf_substitution_skip_reported {
		leaf_substitution_skip_reported = true
		eprintln('Vox substitution validation: leaf tokens need no argument workspace')
	}
}
