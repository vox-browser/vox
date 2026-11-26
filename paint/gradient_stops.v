module main

import layout
import math
import os

const parallel_gradient_stops = os.getenv('VOX_PARALLEL_GRADIENT_STOPS') == '1'
const paint_gradient_stops_diagnostics = os.getenv('VOX_PAINT_GRADIENT_STOPS_DIAGNOSTICS') == '1'
const skip_transparent_background_gradients = (os.getenv_opt('VOX_SKIP_TRANSPARENT_BACKGROUND_GRADIENTS') or {
	'1'
}) == '1'
const transparent_background_gradient_diagnostics = os.getenv('VOX_TRANSPARENT_BACKGROUND_GRADIENT_DIAGNOSTICS') == '1'
const native_gradient_subdivisions = 16
const paint_gradient_source_stop_limit = 4
// Each span can add a start, subdivisions - 1 interior samples, and an end.
const paint_gradient_sample_limit = 2 + (paint_gradient_source_stop_limit - 1) * (native_gradient_subdivisions + 1)
const paint_gradient_float_limit = paint_gradient_sample_limit * 5
const paint_gradient_command_limit = 512

// Every interpolated sample has zero alpha when all resolved stops do.
fn transparent_background_gradient(command &layout.PaintCommand) bool {
	if command.kind != 'fill_gradient' || !command.gradient_background_layer
		|| command.scrollbar_axis != '' || command.checkbox_theme_data != unsafe { nil }
		|| command.outer_shadow || command.blur != 0 || command.image_data == unsafe { nil }
		|| command.image_data.background_blend_mode != .normal
		|| !math.is_finite(native_paint_leaf_opacity(command)) {
		return false
	}
	gradient := command.gradient or { return false }
	if gradient.colors.len == 0 { return false }
	if gradient.stops.len > 0 { return gradient.stops.all(it.color.a == 0) }
	return gradient.colors.all(it.a == 0)
}

struct PaintGradientStops {
mut:
	data [paint_gradient_float_limit]f32
	len  int
}

struct PaintGradientStopsBatch {
	slots         &i32 = unsafe { nil }
	stops         &PaintGradientStops = unsafe { nil }
	command_count int
}

fn reserve_paint_gradient_stops(commands []layout.PaintCommand) PaintGradientStopsBatch {
	if commands.len > paint_screen_geometry_command_limit { return PaintGradientStopsBatch{} }
	mut slots := []i32{}
	mut count := 0
	for index in 0 .. commands.len {
		command := &commands[index]
		if command.kind != 'fill_gradient' || command.scrollbar_axis != ''
			|| command.checkbox_theme_data != unsafe { nil } { continue }
		gradient := command.gradient or { continue }
		stop_count := if gradient.stops.len > 0 { gradient.stops.len } else { gradient.colors.len }
		if gradient.colors.len == 0 || stop_count > paint_gradient_source_stop_limit { continue }
		if count == 0 { slots = []i32{len: commands.len} }
		count++
		slots[index] = i32(count)
		if count == paint_gradient_command_limit { break }
	}
	if count == 0 { return PaintGradientStopsBatch{} }
	// The frame arena owns both buffers until all submitted ranges have joined.
	stops := []PaintGradientStops{len: count}
	return PaintGradientStopsBatch{
		slots: unsafe { &i32(slots.data) }
		stops: unsafe { &PaintGradientStops(stops.data) }
		command_count: commands.len
	}
}

fn (mut prepared PaintGradientStops) prepare(command &layout.PaintCommand) {
	gradient := command.gradient or { return }
	mut sample_storage := [paint_gradient_sample_limit]layout.GradientStop{}
	mut samples := unsafe { array{
		data: &sample_storage[0]
		cap: paint_gradient_sample_limit
		element_size: int(sizeof(layout.GradientStop))
		flags: .nofree | .nogrow | .noshrink
	} }
	mut data := unsafe { array{
		data: &prepared.data[0]
		cap: paint_gradient_float_limit
		element_size: int(sizeof(f32))
		flags: .nofree | .nogrow | .noshrink
	} }
	pack_native_gradient_stops(gradient, native_paint_leaf_opacity(command), mut data, mut samples)
	prepared.len = data.len
}

fn (prepared &PaintGradientStops) packed() []f32 {
	return unsafe { array{
		data: &prepared.data[0]
		len: prepared.len
		cap: prepared.len
		element_size: int(sizeof(f32))
		flags: .nofree | .nogrow | .noshrink
	} }
}

fn (batch &PaintGradientStopsBatch) slot_at(index int) &PaintGradientStops {
	if batch.slots == unsafe { nil } { return unsafe { nil } }
	slot := unsafe { batch.slots[index] }
	return if slot > 0 { unsafe { &batch.stops[slot - 1] } } else { unsafe { nil } }
}

// The caller must wait for the owning range before borrowing its frame storage.
fn (batch &PaintGradientStopsBatch) at(index int) &PaintGradientStops {
	prepared := batch.slot_at(index)
	return if prepared != unsafe { nil } && prepared.len > 0 { prepared } else { unsafe { nil } }
}
