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

fn restore_environment(name string, value ?string) {
	if previous := value { os.setenv(name, previous, true) } else { os.unsetenv(name) }
}

fn test_filter_worker_mini_vm_startup_keeps_caller_owned_heap_options() {
	$if !macos { return }
	previous_mode := os.getenv_opt('JSC_forceMiniVMMode')
	previous_growth := os.getenv_opt('JSC_miniVMHeapGrowthFactor')
	defer {
		restore_environment('JSC_forceMiniVMMode', previous_mode)
		restore_environment('JSC_miniVMHeapGrowthFactor', previous_growth)
	}
	os.unsetenv('JSC_forceMiniVMMode')
	os.unsetenv('JSC_miniVMHeapGrowthFactor')
	configure_filter_worker_javascript_startup()
	assert os.getenv_opt('JSC_forceMiniVMMode')? == 'true'
	assert os.getenv_opt('JSC_miniVMHeapGrowthFactor')? == '2'
	// Either caller option leaves the whole mini-VM configuration to the caller.
	os.setenv('JSC_forceMiniVMMode', 'false', true)
	os.unsetenv('JSC_miniVMHeapGrowthFactor')
	configure_filter_worker_javascript_startup()
	assert os.getenv_opt('JSC_forceMiniVMMode')? == 'false'
	assert os.getenv_opt('JSC_miniVMHeapGrowthFactor') == none
	os.unsetenv('JSC_forceMiniVMMode')
	os.setenv('JSC_miniVMHeapGrowthFactor', '1.2', true)
	configure_filter_worker_javascript_startup()
	assert os.getenv_opt('JSC_forceMiniVMMode') == none
	assert os.getenv_opt('JSC_miniVMHeapGrowthFactor')? == '1.2'
}
