module libjs

import time

$if test {
	__global regexp_profile_enabled bool
	__global regexp_profile_samples map[string]RegExpProfileSample

	pub struct RegExpProfileSample {
	pub mut:
		pattern string
		flags string
		calls u64
		matches u64
		input_units u64
		engine_ns u64
	}

	// Diagnostic engine-only wall time. This excludes JS result construction,
	// lastIndex conversion and the generic RegExpExec/callback machinery.
	pub fn profile_regexp_patterns_for_testing(enabled bool) []RegExpProfileSample {
		mut result := []RegExpProfileSample{}
		for _, sample in regexp_profile_samples { result << sample }
		regexp_profile_samples = map[string]RegExpProfileSample{}
		regexp_profile_enabled = enabled
		return result
	}

	fn (mut regex RegExpObject) profiled_engine_exec(text &PrimitiveString, start uint, mut slots []i32) RegexVmResult {
		pattern := regex.pattern.str()
		flags := regex.flags_text.str()
		key := '${flags.len}:${flags}${pattern}'
		started := time.sys_mono_now()
		status := regex.engine.exec(RegexUtf16Input{units: text.utf16.data}, start, mut slots)
		elapsed := time.sys_mono_now() - started
		mut sample := regexp_profile_samples[key] or { RegExpProfileSample{pattern: pattern, flags: flags} }
		sample.calls++
		if status == .match { sample.matches++ }
		sample.input_units += u64(text.utf16.len())
		sample.engine_ns += elapsed
		regexp_profile_samples[key] = sample
		return status
	}
}

@[inline]
fn (mut regex RegExpObject) execute_engine(text &PrimitiveString, start uint, mut slots []i32) RegexVmResult {
	$if test {
		if regexp_profile_enabled { return regex.profiled_engine_exec(text, start, mut slots) }
	}
	return regex.engine.exec(RegexUtf16Input{units: text.utf16.data}, start, mut slots)
}
