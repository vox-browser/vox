// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import highresolutiontime
import libjs
import math
import performancetimeline
import platform
import usertiming

fn (host &LibJSPerformanceHost) native_error(mut vm libjs.VM, err IError) IError {
	if mut document_host := host.runtime.libjs_document_host_ { return document_host.dom_error(mut vm, err) }
	return vm.throw_error(if err.msg().starts_with('SyntaxError:') { .syntax_error } else { .type_error }, err.msg())
}

fn (host &LibJSPerformanceHost) clone_detail(mut vm libjs.VM, value libjs.Value) !libjs.Value {
	if value.is_nullish() { return libjs.js_null() }
	if mut document_host := host.runtime.libjs_document_host_ { return document_host.clone_ordinary_value(value) }
	return vm.throw_error(.internal_error, 'Performance detail requires the native value clone adapter')
}

fn (host &LibJSPerformanceHost) entry_detail(mut vm libjs.VM, entry &performancetimeline.PerformanceEntry) !libjs.Value {
	value := host.details[voidptr(entry)] or { return libjs.js_null() }
	return host.clone_detail(mut vm, value)
}

fn performance_measure_number(mut vm libjs.VM, value libjs.Value) !f64 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) { return vm.throw_error(.type_error, 'Performance measure time must be finite') }
	return number
}

fn performance_measure_time(mut vm libjs.VM, value libjs.Value) !usertiming.StringOrTimestamp {
	if value.is_number() { return usertiming.StringOrTimestamp(performance_measure_number(mut vm, value)!) }
	return usertiming.StringOrTimestamp(value.to_primitive_string(mut vm)!.str())
}

fn (mut host LibJSPerformanceHost) measure(mut vm libjs.VM) !libjs.Value {
	if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'Performance.measure requires a name') }
	name := vm.argument(0).to_primitive_string(mut vm)!.str()
	argument := vm.argument(1)
	mut detail := libjs.js_undefined()
	mut start_or_options := ?highresolutiontime.StartOrMeasureOptions(none)
	if argument.is_object() || argument.is_nullish() {
		mut duration := ?f64(none)
		mut start := ?usertiming.StringOrTimestamp(none)
		mut end := ?usertiming.StringOrTimestamp(none)
		if argument.is_object() {
			object := argument.as_object()
			detail = object.get(mut vm, libjs.PropertyName.from_str('detail'))!
			duration_value := object.get(mut vm, libjs.PropertyName.from_str('duration'))!
			if !duration_value.is_undefined() { duration = performance_measure_number(mut vm, duration_value)! }
			end_value := object.get(mut vm, libjs.PropertyName.from_str('end'))!
			if !end_value.is_undefined() { end = performance_measure_time(mut vm, end_value)! }
			start_value := object.get(mut vm, libjs.PropertyName.from_str('start'))!
			if !start_value.is_undefined() { start = performance_measure_time(mut vm, start_value)! }
		}
		start_or_options = highresolutiontime.StartOrMeasureOptions(usertiming.PerformanceMeasureOptions{
			detail: if detail.is_undefined() { none } else { ?string('') }
			duration: duration
			start: start
			end: end
		})
	} else { start_or_options = highresolutiontime.StartOrMeasureOptions(argument.to_primitive_string(mut vm)!.str()) }
	end_mark := if vm.argument(2).is_undefined() { ?string(none) } else { ?string(vm.argument(2).to_primitive_string(mut vm)!.str()) }
	mut native := host.native
	timing := native.resolve_measure_timing(start_or_options, end_mark) or { return host.native_error(mut vm, err) }
	cloned := host.clone_detail(mut vm, detail)!
	entry := host.publish_measure(name, timing)
	host.details[voidptr(entry)] = cloned
	return host.wrap_entry(entry)
}

fn (host &LibJSPerformanceHost) publish_measure(name string, timing highresolutiontime.PerformanceMeasureTiming) &performancetimeline.PerformanceEntry {
	mut allocation := platform.RetainedArenaScope{}
	if settings := host.runtime.scripting_settings_ {
		if document := settings.responsible_document() {
			mut storage := document.native_storage()
			if storage != unsafe { nil } { allocation = storage.enter_nested() }
		}
	}
	defer { allocation.finish() }
	measure := usertiming.PerformanceMeasure.new(name.clone(), timing.start_time, timing.duration, none)
	mut native := host.native
	native.record_entry(measure.entry)
	return measure.entry
}
