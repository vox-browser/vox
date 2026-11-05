module main

$if macos {
	fn C.native_disable_ui_intelligence() int
}

// Skip Apple Intelligence content registration before Sokol launches AppKit.
// VOX_ENABLE_UI_INTELLIGENCE=1 preserves the system integration at startup.
fn disable_native_ui_intelligence() {
	$if macos {
		C.native_disable_ui_intelligence()
	}
}
