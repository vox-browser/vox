module adblock

import os

// The private filter realm has a bounded restored rule set and executes no
// author scripts. One marker avoids starting a host-sized GC worker pool for
// that small heap. Concurrent collection and every JIT tier stay enabled.
// Ordinary in-process Engines keep their caller's runtime configuration.
fn configure_filter_worker_javascript_startup() {
	$if macos {
		if os.getenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS') == ''
			&& os.getenv_opt('JSC_numberOfGCMarkers') == none {
			os.setenv('JSC_numberOfGCMarkers', '1', false)
		}
	}
}
