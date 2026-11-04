module adblock

import os

// The private filter realm has a bounded restored rule set and executes no
// author scripts. One marker avoids starting a host-sized GC worker pool for
// that small heap. Mini-VM mode skips the table of every ICU time zone that
// creating a JIT-enabled VM otherwise builds eagerly (about 25M instructions);
// Intl still builds it on first use. Its heap grows by the small-heap factor
// instead of the denser mini default, so collections stay as frequent as
// before. Concurrent collection and every JIT tier stay enabled.
// Ordinary in-process Engines keep their caller's runtime configuration.
fn configure_filter_worker_javascript_startup() {
	$if macos {
		if os.getenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS') == ''
			&& os.getenv_opt('JSC_numberOfGCMarkers') == none {
			os.setenv('JSC_numberOfGCMarkers', '1', false)
		}
		if os.getenv_opt('JSC_forceMiniVMMode') == none
			&& os.getenv_opt('JSC_miniVMHeapGrowthFactor') == none {
			os.setenv('JSC_forceMiniVMMode', 'true', false)
			os.setenv('JSC_miniVMHeapGrowthFactor', '2', false)
		}
	}
}
