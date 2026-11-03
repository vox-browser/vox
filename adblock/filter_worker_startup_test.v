module adblock

import os

fn test_filter_worker_gc_startup_keeps_caller_owned_runtime_options() {
	$if !macos { return }
	previous := os.getenv_opt('JSC_numberOfGCMarkers')
	previous_control := os.getenv_opt('VOX_RETAIN_FILTER_WORKER_GC_MARKERS')
	defer {
		if value := previous { os.setenv('JSC_numberOfGCMarkers',value,true) }
		else { os.unsetenv('JSC_numberOfGCMarkers') }
		if value := previous_control { os.setenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS',value,true) }
		else { os.unsetenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS') }
	}
	os.unsetenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS')
	for override in ['2','8',''] {
		os.setenv('JSC_numberOfGCMarkers',override,true)
		configure_filter_worker_javascript_startup()
		assert os.getenv_opt('JSC_numberOfGCMarkers')? == override
	}
	os.unsetenv('JSC_numberOfGCMarkers')
	os.setenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS','1',true)
	configure_filter_worker_javascript_startup()
	assert os.getenv_opt('JSC_numberOfGCMarkers') == none
	os.unsetenv('VOX_RETAIN_FILTER_WORKER_GC_MARKERS')
	configure_filter_worker_javascript_startup()
	assert os.getenv('JSC_numberOfGCMarkers') == '1'
}
