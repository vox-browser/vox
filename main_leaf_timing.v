module main

import layout
import os
import time
import processmetrics

// Static labels keep enabled command tracing out of the V allocation arena.
// Nested replay subtracts its own leaf scopes from the enclosing leaf.
fn paint_leaf_instruction_stage(kind string) processmetrics.InstructionStage {
	if !processmetrics.load_stages_enabled() { return processmetrics.InstructionStage{} }
	label := match kind {
		'fill_rect', 'fill_rounded_rect', 'fill_ellipse', 'fill_polygon', 'fill_gradient' { 'paint_leaf_fill' }
		'draw_text' { 'paint_leaf_text' }
		'draw_svg_path' { 'paint_leaf_svg' }
		'paint_outer_box_shadow', 'paint_inner_box_shadow' { 'paint_leaf_shadow' }
		'paint_uniform_border', 'paint_partial_rounded_border', 'stroke_rounded_rect' { 'paint_leaf_border' }
		'draw_replaced_image', 'draw_background_image', 'paint_nested_display_list' { 'paint_leaf_image' }
		'draw_canvas', 'draw_video' { 'paint_leaf_media' }
		'begin_css_effect_layer' { 'paint_leaf_effect_begin' }
		'end_css_effect_layer' { 'paint_leaf_effect_end' }
		'begin_css_filter_layer', 'end_css_filter_layer', 'apply_backdrop_filter' { 'paint_leaf_filter' }
		else { if kind.starts_with('begin_') || kind.starts_with('end_') { 'paint_leaf_scope' } else { 'paint_leaf_other' } }
	}
	return processmetrics.begin_instruction_stage(label)
}

// Diagnostic: wall time of each document replay step, charged to the command
// index that began it (grouped handlers charge their first command). One line
// per frame lists the replay total and the slowest commands with their ink.
const leaf_timing_enabled = os.getenv('VOX_LEAF_TIMING_DIAGNOSTICS') != ''
const leaf_timing_report_us = i64(500)
const leaf_timing_top = 12

struct LeafTimingEntry {
	index int
	us    i64
}

struct LeafTiming {
mut:
	enabled bool
	current int = -1
	started u64
	begun   u64
	total   i64
	steps   int
	entries []LeafTimingEntry
}

fn new_leaf_timing() LeafTiming {
	if !leaf_timing_enabled { return LeafTiming{} }
	now := time.sys_mono_now()
	return LeafTiming{
		enabled: true
		started: now
		begun:   now
	}
}

fn (mut timing LeafTiming) mark(index int) {
	if !timing.enabled { return }
	now := time.sys_mono_now()
	if timing.current >= 0 {
		elapsed := i64(now - timing.started) / 1000
		timing.total += elapsed
		timing.steps++
		if elapsed >= leaf_timing_report_us {
			timing.entries << LeafTimingEntry{timing.current, elapsed}
		}
	}
	timing.current = index
	timing.started = now
}

fn (mut timing LeafTiming) finish(commands []layout.PaintCommand, damage &ScrollRasterDamage) {
	if !timing.enabled { return }
	timing.mark(-1)
	frame_us := i64(time.sys_mono_now() - timing.begun) / 1000
	timing.entries.sort(a.us > b.us)
	mut slow := []string{}
	for entry in timing.entries {
		if slow.len >= leaf_timing_top { break }
		if entry.index < 0 || entry.index >= commands.len { continue }
		command := unsafe { &commands[entry.index] }
		ink := layout.scroll_raster_leaf_ink_bounds(command) or {
			layout.LayoutRect{command.x, command.y, command.width, command.height}
		}
		slow << '${command.kind}:${entry.us}:${entry.index}:${int(ink.x)},${int(ink.y)},${int(ink.width)}x${int(ink.height)}'
	}
	eprintln('VOX_LEAF_TIMING reused=${damage.reused} delta=${damage.delta} rects=${damage.rects.len} loop_us=${frame_us} replay_us=${timing.total} steps=${timing.steps} over=${timing.entries.len} slow=${slow.join(' ')}')
}
