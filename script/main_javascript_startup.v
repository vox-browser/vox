module main

import os

// Short host/bootstrap functions often finish before baseline compilation pays
// for itself. Keep every JIT tier enabled, but give the macOS runtime a longer
// initial warm-up. Explicit engine options continue to belong to the caller.
fn configure_browser_javascript_startup() {
	$if macos {
		if os.getenv_opt('JSC_thresholdForJITAfterWarmUp') == none {
			os.setenv('JSC_thresholdForJITAfterWarmUp', '10000', false)
		}
	}
}
