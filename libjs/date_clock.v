// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

// Host clock emulation changes the Date origin, retaining real elapsed time.
// It neither rewrites author sources nor advances performance/timer clocks.
pub fn (mut vm VM) set_date_clock_epoch_milliseconds(epoch ?f64) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Date clock configuration requires an idle VM')
	}
	if value := epoch {
		if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 8640000000000000 || math.trunc(value) != value {
			return error('Date clock epoch must be an integer millisecond in the Date range')
		}
	}
	vm.date_clock_epoch_ms_ = epoch
	vm.date_clock_started_ns_ = time.sys_mono_now()
}

pub fn (vm &VM) date_clock_epoch_milliseconds() ?f64 {
	return vm.date_clock_epoch_ms_
}

pub fn (vm &VM) current_time_milliseconds() f64 {
	if epoch := vm.date_clock_epoch_ms_ {
		return epoch + math.floor(f64(time.sys_mono_now() - vm.date_clock_started_ns_) / 1000000)
	}
	return f64(time.utc().unix_milli())
}
