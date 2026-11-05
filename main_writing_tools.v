module main

$if macos {
	fn C.native_disable_writing_tools() int
}

// Vox does not offer macOS Writing Tools. Opt out before Sokol creates and
// finishes launching the shared application, so AppKit never loads them.
fn disable_native_writing_tools() {
	$if macos {
		C.native_disable_writing_tools()
	}
}
