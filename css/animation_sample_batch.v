module css

import dom
import os
import sync.stdatomic

const retain_short_animation_sample_batch = os.getenv('VOX_RETAIN_SHORT_ANIMATION_SAMPLE_BATCH') != ''
const animation_sample_batch_diagnostics = os.getenv('VOX_ANIMATION_SAMPLE_BATCH_DIAGNOSTICS') != ''

// This caps only the expanded rotation threshold. A larger original threshold
// remains unchanged, and an individual update can cross either threshold.
const animation_sample_expanded_threshold_cap = i64(16 * 1024 * 1024)
const animation_sample_expanded_updates = i64(64)

__global animation_sample_batch_reported stdatomic.AtomicVal[bool]

fn expanded_animation_sample_arena_limit(original i64, update_bytes i64) i64 {
	if original >= animation_sample_expanded_threshold_cap || update_bytes <= 0 {
		return original
	}
	// Test the quotient first, including for arbitrary signed test inputs, so
	// multiplying cannot overflow. The ordinary limit is always a lower bound.
	expanded := if update_bytes >= animation_sample_expanded_threshold_cap / animation_sample_expanded_updates {
		animation_sample_expanded_threshold_cap
	} else {
		update_bytes * animation_sample_expanded_updates
	}
	return if expanded > original { expanded } else { original }
}

fn report_animation_sample_batch_extension(document &dom.Document, used i64, original i64, expanded i64) {
	if used >= original && used < expanded
		&& animation_sample_batch_reported.compare_and_swap(false, true) {
		eprintln('Vox animation sample batch: deferred rotation; used=${used}; original=${original}; expanded=${expanded}; document=${document.url.serialize()}')
	}
}
