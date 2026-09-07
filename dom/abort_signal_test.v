module dom

import time

fn test_abort_signal_timeout_aborts_without_a_synthetic_window() {
	signal := AbortSignal.timeout(1)!

	time.sleep(20 * time.millisecond)

	assert signal.aborted()
	assert signal.reason().to_string_value() == 'TimeoutError: Signal timed out'
}
