module main

$if macos {
	#include "@VMODROOT/native/include/native_capture_retry_test_darwin.h"
}

fn C.native_test_capture_retry_idle_coalescing_and_cancellation() int

fn test_capture_readiness_retries_wait_for_idle_coalesce_and_cancel_when_ready() {
	$if macos {
		assert C.native_test_capture_retry_idle_coalescing_and_cancellation() == 255
	}
}
