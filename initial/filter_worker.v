module main

import adblock
import time

// The filter helper has its own process and JavaScriptCore VM. Restoring it
// does not enter the browser's DOM, GUI, or document allocation arena.
fn prepare_initial_navigation_filter_worker() {
	started := time.sys_mono_now()
	if adblock.prepare_default_worker() or { return } {
		debug_timing_checkpoint('startup_filter_worker', started)
	}
}
