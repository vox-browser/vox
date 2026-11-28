module libjs

import platform
import time

$if test {
	__global builtin_profile_enabled bool
	__global builtin_profile_samples map[voidptr]BuiltinProfileSample

	pub struct BuiltinProfileSample {
	pub mut:
		name string
		calls u64
		inclusive_ns u64
		retained_bytes u64
	}

	struct BuiltinProfileProbe {
		active bool
		key voidptr
		started u64
		allocated i64
	}

	// Diagnostic only: inclusive native-builtin wall time and current-arena
	// growth. Nested samples overlap; they cannot be summed or used for gates.
	pub fn profile_builtin_calls_for_testing(enabled bool) []BuiltinProfileSample {
		mut result := []BuiltinProfileSample{}
		for _, sample in builtin_profile_samples { result << sample }
		builtin_profile_samples = map[voidptr]BuiltinProfileSample{}
		builtin_profile_enabled = enabled
		return result
	}

	@[inline]
	fn begin_builtin_profile(function &NativeFunction) BuiltinProfileProbe {
		if !builtin_profile_enabled { return BuiltinProfileProbe{} }
		key := voidptr(function)
		if key !in builtin_profile_samples {
			builtin_profile_samples[key] = BuiltinProfileSample{name: function.name.str()}
		}
		allocated := platform.thread_arena_usage().used
		return BuiltinProfileProbe{active: true, key: key, allocated: allocated, started: time.sys_mono_now()}
	}

	@[inline]
	fn finish_builtin_profile(probe BuiltinProfileProbe) {
		if !probe.active { return }
		elapsed := time.sys_mono_now() - probe.started
		growth := platform.thread_arena_usage().used - probe.allocated
		mut sample := builtin_profile_samples[probe.key] or { return }
		sample.calls++
		sample.inclusive_ns += elapsed
		if growth > 0 { sample.retained_bytes += u64(growth) }
		builtin_profile_samples[probe.key] = sample
	}

	fn invoke_profiled_builtin(function &NativeFunction, mut vm VM, behaviour NativeFunctionPointer) !Value {
		probe := begin_builtin_profile(function)
		defer { finish_builtin_profile(probe) }
		return behaviour(mut vm)
	}
}
