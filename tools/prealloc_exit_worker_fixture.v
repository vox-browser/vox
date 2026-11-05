module main

import os
import platform

#include "@DIR/prealloc_exit_worker_fixture.h"

fn C.exit_worker_start(&u8, uint)

fn main() {
	$if !prealloc { panic('This regression requires -prealloc') }
	if os.args.len > 1 && os.args[1] == 'browser' {
		_ = platform.initialize_browser_heap_policy()
	}
	bytes := []u8{len: 65536, init: u8(index % 251)}
	C.exit_worker_start(bytes.data, uint(bytes.len))
	// Return normally: the test must exercise exit handlers, not _exit().
}
