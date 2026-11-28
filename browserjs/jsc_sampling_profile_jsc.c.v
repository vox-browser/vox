module browserjs

import os

#include "@DIR/jsc_sampling_profile.h"

fn C.JSContextGroupEnableSamplingProfiler(group voidptr) bool
fn C.JSContextGroupTakeSamplesFromSamplingProfiler(group voidptr) voidptr

// VOX_JSC_SAMPLING_PROFILE=PATH: enable JavaScriptCore's sampling profiler for
// each context group and, when a capture writes its audit, write the samples
// taken so far (JSON stack traces with function names, source URLs, lines and
// tiers) to PATH.PID.N.json. Diagnostics only: sampling slows execution.
const jsc_sampling_profile_path = os.getenv('VOX_JSC_SAMPLING_PROFILE')

__global jsc_sampling_profile_writes int

// The system framework exports the SPI; JavaScriptCoreGTK and the V8 backend
// need not, so only macOS JavaScriptCore builds reference it.
fn enable_jsc_sampling_profile(context voidptr) {
	if jsc_sampling_profile_path == '' || context == unsafe { nil } { return }
	$if darwin {
		$if !vox_v8 ? {
			if !C.JSContextGroupEnableSamplingProfiler(C.JSContextGetGroup(context)) {
				eprintln('VOX_JSC_SAMPLING_PROFILE unavailable')
			}
		}
	}
}

fn (runtime &Runtime) write_jsc_sampling_profile(boundary string) {
	if jsc_sampling_profile_path == '' || runtime.context == unsafe { nil } { return }
	$if darwin {
		$if !vox_v8 ? {
			group := C.JSContextGetGroup(runtime.context)
			samples := C.JSContextGroupTakeSamplesFromSamplingProfiler(group)
			if samples == unsafe { nil } { return }
			defer { C.JSStringRelease(samples) }
			capacity := C.JSStringGetMaximumUTF8CStringSize(samples)
			if capacity == 0 { return }
			mut buffer := []u8{len: int(capacity)}
			written := unsafe { C.JSStringGetUTF8CString(samples, &char(buffer.data), capacity) }
			if written == 0 { return }
			jsc_sampling_profile_writes++
			path := '${jsc_sampling_profile_path}.${os.getpid()}.${jsc_sampling_profile_writes}.json'
			os.write_file(path, unsafe { tos(buffer.data, int(written) - 1) }) or {
				eprintln('VOX_JSC_SAMPLING_PROFILE ${err.msg()}')
				return
			}
			eprintln('VOX_JSC_SAMPLING_PROFILE boundary=${boundary} path=${path} bytes=${written - 1}')
		}
	}
}
