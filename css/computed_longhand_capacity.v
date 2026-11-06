module css

import os

const retain_small_longhand_cache = os.getenv('VOX_RETAIN_SMALL_LONGHAND_CACHE') != ''
const longhand_capacity_diagnostics = os.getenv('VOX_LONGHAND_CAPACITY_DIAGNOSTICS') != ''
const computed_longhand_cache_limit = if retain_small_longhand_cache { 256 } else { 1024 }

__global longhand_capacity_reuse_reported bool

fn report_longhand_capacity_reuse(extended_admission bool) {
	if extended_admission && longhand_capacity_diagnostics && !longhand_capacity_reuse_reported {
		longhand_capacity_reuse_reported = true
		eprintln('Vox longhand capacity: reused a style admitted beyond the original limit')
	}
}
