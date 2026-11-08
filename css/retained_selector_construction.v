module css

import os
import platform

const disable_retained_selector_construction = os.getenv('VOX_DISABLE_RETAINED_SELECTOR_CONSTRUCTION') != ''
const retained_selector_construction_diagnostics = os.getenv('VOX_RETAINED_SELECTOR_CONSTRUCTION_DIAGNOSTICS') != ''
__global retained_selector_construction_reported bool

// A short selector has bounded construction storage. In a document's native
// owner, build its immutable graph there once instead of constructing a second
// graph and copying every name, compound and nested selector out of scratch.
// Large inputs and callers without a retiring document owner keep the existing
// workspace publication path.
fn can_construct_selector_in_retained_owner(text string) bool {
	$if prealloc {
		return !disable_retained_selector_construction && text.len <= 256
			&& platform.current_retained_arena() != unsafe { nil }
			&& platform.arena_entered() && !platform.transient_arena_entered()
	}
	return false
}

fn report_retained_selector_construction() {
	if retained_selector_construction_diagnostics && !retained_selector_construction_reported {
		retained_selector_construction_reported = true
		eprintln('Vox selector construction: built bounded graph in document owner')
	}
}
