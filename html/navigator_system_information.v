// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Shannon Booth <shannon@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorConcurrentHardware.cpp and NavigatorDeviceMemory.cpp.
module html

import runtime

pub struct NavigatorConcurrentHardwareMixin {}

pub struct NavigatorDeviceMemoryMixin {}

// https://html.spec.whatwg.org/multipage/workers.html#dom-navigator-hardwareconcurrency
pub fn navigator_hardware_concurrency() u64 {
	return u64(runtime.nr_cpus())
}

pub fn (_ &NavigatorConcurrentHardwareMixin) hardware_concurrency() u64 {
	return u64(runtime.nr_cpus())
}

// https://www.w3.org/TR/device-memory/#computing-device-memory-value
pub fn compute_device_memory_value(physical_memory_bytes u64) f64 {
	memory_in_mib := physical_memory_bytes / (1024 * 1024)
	mut required_bits := u32(0)
	mut remaining := memory_in_mib
	for remaining > 0 {
		required_bits++
		remaining >>= 1
	}
	lower_memory_in_mib := u64(1) << (required_bits - 1)
	upper_memory_in_mib := u64(1) << required_bits
	rounded_memory_in_mib := if upper_memory_in_mib - memory_in_mib <= memory_in_mib - lower_memory_in_mib {
		upper_memory_in_mib
	} else {
		lower_memory_in_mib
	}
	memory_in_gib := f64(rounded_memory_in_mib) / 1024.0
	return if memory_in_gib < 1.0 {
		1.0
	} else if memory_in_gib > 4.0 {
		4.0
	} else {
		memory_in_gib
	}
}

pub fn navigator_device_memory() !f64 {
	return compute_device_memory_value(u64(runtime.total_memory()!))
}

pub fn (_ &NavigatorDeviceMemoryMixin) device_memory() !f64 {
	return compute_device_memory_value(u64(runtime.total_memory()!))
}
