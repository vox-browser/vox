module adblock

import platform

fn test_default_engine_initialization_releases_v_temporaries_and_keeps_native_filters() {
	C.vox_adblock_lock()
	defer { C.vox_adblock_unlock() }
	// Warm embedded-file metadata before measuring the repeatable work.
	first := create_context(none)!
	C.JSGlobalContextRelease(first)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 3 {
		context := create_context(none)!
		result := evaluate_context(context, 'voxAdblockCheck({url:"https://securepubads.g.doubleclick.net/tag/js/gpt.js",source_url:"https://www.theverge.com/",request_type:"script"})')!
		assert result.contains('"blocked":true')
		assert evaluate_context(context, '"Unicode λ 🌍:"+(6*7)')! == 'Unicode λ 🌍:42'
		C.JSGlobalContextRelease(context)
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024 * 1024
	}
}
