// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

fn test_emulated_date_clock_retains_elapsed_time_and_explicit_constructor_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.set_date_clock_epoch_milliseconds(946684800000.0)!
	mut script := Script.parse('Date.now()>=946684800000&&new Date().getUTCFullYear()===2000&&new Date(123).getTime()===123&&Date().includes(String(new Date().getFullYear()))', vm.realm(), 'date-clock.js', unsafe { nil })!
	assert vm.run(mut script)!.as_bool()
	vm.date_clock_started_ns_ -= 2 * time.second
	assert vm.current_time_milliseconds() >= 946684802000
	vm.set_date_clock_epoch_milliseconds(none)!
	assert vm.date_clock_epoch_milliseconds() == none
}

fn test_date_clock_configuration_rejects_invalid_epochs_without_replacing_the_clock() {
	mut vm := VM.create()
	vm.set_date_clock_epoch_milliseconds(123.0)!
	for invalid in [math.nan(), math.inf(1), 8640000000000001.0, 1.5] {
		mut rejected := false
		vm.set_date_clock_epoch_milliseconds(invalid) or { rejected = true }
		assert rejected
		assert vm.date_clock_epoch_milliseconds()? == 123
	}
}
