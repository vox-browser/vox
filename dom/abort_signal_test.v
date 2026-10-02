module dom

import time
import platform

fn test_abort_signal_timeout_aborts_without_a_synthetic_window() {
	if !platform.native_timer_scheduling_available() { return }
	signal := AbortSignal.timeout(1)!
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !signal.aborted() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
	assert signal.aborted()
	assert signal.reason().to_string_value() == 'TimeoutError: Signal timed out'
}
