module platform

fn C.hb_shape_list_shapers() &&char

fn test_browser_shapers_keep_opentype_and_coretext_without_graphite_vm() {
	shapers := C.hb_shape_list_shapers()
	mut names := []string{}
	for index := 0; unsafe { shapers[index] } != unsafe { nil }; index++ {
		names << unsafe { cstring_to_vstring(shapers[index]) }
	}
	assert names == ['ot', 'coretext', 'fallback']
}
