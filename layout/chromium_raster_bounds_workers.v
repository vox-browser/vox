module layout

import cpuraster
import os

const parallel_raster_chunk_bounds = os.getenv('VOX_PARALLEL_RASTER_CHUNK_BOUNDS') == '1'
const raster_chunk_bounds_diagnostics = os.getenv('VOX_RASTER_CHUNK_BOUNDS_DIAGNOSTICS') == '1'
const record_raster_chunk_bounds = os.getenv('VOX_RECORD_RASTER_CHUNK_BOUNDS') == '1'
const raster_chunk_bounds_min_commands = 256
const raster_chunk_bounds_max_commands = 4096

struct RecordedRasterBound {
	extent LayoutRect
	ready  bool
}

// Slots belong to the same scene as the projected commands. Clip intersection
// still uses the root-scroll policy chosen by the layer planner.
struct RecordedRasterBounds {
	paint_order voidptr
	revision u64
mut:
	slots []RecordedRasterBound
}

fn (bounds &RecordedRasterBounds) slot_data() &RecordedRasterBound {
	return unsafe { if bounds.slots.len > 0 { &RecordedRasterBound(bounds.slots.data) } else { nil } }
}

fn recorded_chromium_raster_bounds(result &DocumentLayoutResult, commands []PaintCommand) []RecordedRasterBound {
	if record_raster_chunk_bounds && !result.needs_repaint {
		if recording := display_list_recording(result.display_list) {
			bounds := &recording.raster_bounds
			if recording.commands.data == commands.data && bounds.slots.len == commands.len
				&& bounds.paint_order == result.paint_order.data
				&& bounds.revision == result.document.paint_content_revision() {
				return bounds.slots
			}
		}
	}
	return []
}

struct ChromiumRasterBoundsWork {
	commands      []PaintCommand
	paint_order   []PaintOrderEntry
	root_scroll_y f64
mut:
	bounds &LayoutRect = unsafe { nil }
}

fn calculate_chromium_raster_bounds_range(context voidptr, first i32, end i32) {
	work := unsafe { &ChromiumRasterBoundsWork(context) }
	for index in int(first) .. int(end) {
		command := unsafe { &work.commands[index] }
		box_index := command.paint_box_index
		if command.visual_layer_data != none || box_index < 0 || box_index >= work.paint_order.len {
			continue
		}
		box := work.paint_order[box_index].box
		unsafe {
			work.bounds[index] = chromium_raster_chunk_bounds_with_root_scroll(box, command,
				work.root_scroll_y)
		}
	}
}

fn (mut scratch ChromiumRasterPlanScratch) start_command_bounds(mut work ChromiumRasterBoundsWork,
	has_recorded_bounds bool) (voidptr, int) {
	$if macos {
		count := work.commands.len
		if !has_recorded_bounds && parallel_raster_chunk_bounds && count >= raster_chunk_bounds_min_commands
			&& count <= raster_chunk_bounds_max_commands {
			if scratch.command_bounds.len == 0 {
				scratch.command_bounds = []LayoutRect{len: raster_chunk_bounds_max_commands}
			}
			work.bounds = unsafe { &LayoutRect(scratch.command_bounds.data) }
			// The caller joins before releasing the borrowed commands and
			// boxes. Each worker writes only its own bounds slots.
			return cpuraster.start_background_raster_ranges(work, count, 2,
				calculate_chromium_raster_bounds_range)
		}
	}
	return unsafe { nil }, 0
}
