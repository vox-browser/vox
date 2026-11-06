// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os
import platform
import processmetrics
import json2

#include "host_callback_diagnostics.h"

fn C.vox_host_callback_registration_stack(&voidptr, i32) i32
fn C.vox_host_callback_image_base() uint
fn C.vox_host_callback_report(&char)

const host_callback_diagnostics_enabled = os.getenv('VOX_DIAGNOSTIC_HOST_CALLBACKS') != ''
const host_callback_sample_stride = u64(64)

@[heap]
struct HostCallbackDiagnostic {
	name       string
	site       [12]voidptr
	site_count int
mut:
	calls                  u64
	sample_attempts        u64
	samples                u64
	inclusive_instructions u64
	minimum_instructions   u64
	maximum_instructions   u64
}

fn new_host_callback_diagnostic(name string) &HostCallbackDiagnostic {
	if !host_callback_diagnostics_enabled { return unsafe { nil } }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut site := [12]voidptr{init: unsafe { nil }}
	count := C.vox_host_callback_registration_stack(&site[0], 12)
	return &HostCallbackDiagnostic{ name: name.clone(), site: site, site_count: int(count) }
}

fn begin_host_callback_diagnostic(diagnostic &HostCallbackDiagnostic) processmetrics.InstructionSnapshot {
	if diagnostic == unsafe { nil } { return processmetrics.InstructionSnapshot{} }
	mut state := unsafe { &HostCallbackDiagnostic(diagnostic) }
	state.calls++
	if (state.calls - 1) % host_callback_sample_stride != 0 {
		return processmetrics.InstructionSnapshot{}
	}
	state.sample_attempts++
	return processmetrics.instruction_snapshot()
}

fn finish_host_callback_diagnostic(diagnostic &HostCallbackDiagnostic, start processmetrics.InstructionSnapshot) {
	if diagnostic == unsafe { nil } || !start.available { return }
	if count := processmetrics.instruction_snapshot().since(start) {
		mut state := unsafe { &HostCallbackDiagnostic(diagnostic) }
		state.samples++
		state.inclusive_instructions += count
		if state.samples == 1 || count < state.minimum_instructions {
			state.minimum_instructions = count
		}
		if count > state.maximum_instructions { state.maximum_instructions = count }
	}
}

fn report_host_callback_diagnostic(runtime &Runtime, boundary string, kind string, index int, diagnostic &HostCallbackDiagnostic) {
	if diagnostic == unsafe { nil } || diagnostic.calls == 0 { return }
	// Reporting occurs after the last invocation and before records are dropped.
	// These are inclusive systematic samples, including concurrent process work
	// and the counter observer. Nested samples overlap; never sum or scale them
	// into an additive page budget or use them for optimization acceptance.
	work := platform.begin_thread_scratch('host callback diagnostic report')
	defer { work.finish() }
	mut site := []uint{cap: diagnostic.site_count}
	for i in 0 .. diagnostic.site_count { site << uint(diagnostic.site[i]) }
	// Generic struct encoders cache reflection metadata. Keep this report on
	// primitive encoders so no cached descriptor can point into retired scratch.
	encoded := '{"pid":${os.getpid()},"runtime":${uint(voidptr(runtime))},"boundary":${json2.encode(boundary)},"kind":${json2.encode(kind)},"name":${json2.encode(diagnostic.name)},"index":${index},"calls":${diagnostic.calls},"sample_stride":${host_callback_sample_stride},"sample_attempts":${diagnostic.sample_attempts},"samples":${diagnostic.samples},"inclusive_sample_instructions":${diagnostic.inclusive_instructions},"minimum_sample_instructions":${diagnostic.minimum_instructions},"maximum_sample_instructions":${diagnostic.maximum_instructions},"image_base":${C.vox_host_callback_image_base()},"registration_stack":${json2.encode(site)}}'
	C.vox_host_callback_report(encoded.str)
}

// Some native application exits bypass realm cleanup. An explicit observer
// boundary can publish counters without closing the realm or resetting them.
pub fn (runtime &Runtime) report_host_callback_diagnostics(boundary string) {
	if !host_callback_diagnostics_enabled { return }
	for index, record in runtime.host_functions_ {
		report_host_callback_diagnostic(runtime, boundary, 'text', index, record.diagnostic)
	}
	for index, record in runtime.value_host_functions_ {
		report_host_callback_diagnostic(runtime, boundary, 'value', index, record.diagnostic)
	}
}
