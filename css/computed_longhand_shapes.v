module css

import os

const disable_longhand_shape_reuse = os.getenv('VOX_DISABLE_LONGHAND_SHAPE_REUSE') != ''
const longhand_shape_reuse_diagnostics = os.getenv('VOX_LONGHAND_SHAPE_REUSE_DIAGNOSTICS') != ''
__global longhand_shape_reuse_reported bool

// These units use the viewport already captured in ComputedLonghandReuseKey.
// Font/container-relative units retain their ordinary computation path.
fn longhand_shape_length_is_viewport(length Length) bool {
	return !disable_longhand_shape_reuse && length.unit_ in [.vw, .vh, .vmin, .vmax]
}

fn longhand_radius_component_is_simple(value &StyleValue) bool {
	return match value {
		LengthStyleValue { value.length_.is_absolute() || longhand_shape_length_is_viewport(value.length_) }
		PercentageStyleValue { true }
		else { false }
	}
}

struct LonghandGridPlacementInput {
	kind ComputedLonghandReuseValueKind
	has_number bool
	number i64
	name ?string
}

// Grid line/span integers and names are not resolved against a grid until
// layout. Calculated placement numbers retain the ordinary computation path.
fn longhand_grid_placement_input(value &GridTrackPlacementStyleValue) ?LonghandGridPlacementInput {
	if value.grid_track_placement_.len != 1 { return none }
	placement := value.grid_track_placement_[0].value_
	return match placement {
		GridTrackPlacementAuto { LonghandGridPlacementInput{kind: .grid_auto} }
		GridTrackPlacementAreaOrLine {
			if number := placement.line_number {
				if number !is IntegerStyleValue { return none }
				LonghandGridPlacementInput{kind: .grid_line, has_number: true, number: (number as IntegerStyleValue).value_, name: placement.name}
			} else {
				LonghandGridPlacementInput{kind: .grid_line, name: placement.name}
			}
		}
		GridTrackPlacementSpan {
			if placement.value !is IntegerStyleValue { return none }
			LonghandGridPlacementInput{kind: .grid_span, has_number: true, number: (placement.value as IntegerStyleValue).value_, name: placement.name}
		}
	}
}

fn longhand_shape_is_simple(value &StyleValue) bool {
	if disable_longhand_shape_reuse { return false }
	return match value {
		GridAutoFlowStyleValue { true }
		GridTrackPlacementStyleValue { longhand_grid_placement_input(value) != none }
		BorderRadiusStyleValue {
			value.horizontal_radius.len == 1 && value.vertical_radius.len == 1
				&& longhand_radius_component_is_simple(&value.horizontal_radius[0])
				&& longhand_radius_component_is_simple(&value.vertical_radius[0])
		}
		else { false }
	}
}

fn longhand_shape_snapshot(value &StyleValue) ?ComputedLonghandReuseValue {
	if !longhand_shape_is_simple(value) { return none }
	return match value {
		GridAutoFlowStyleValue {
			ComputedLonghandReuseValue{kind: .grid_auto_flow, integer: (if value.row_ { i64(1) } else { i64(0) }) + (if value.dense_ { i64(2) } else { i64(0) })}
		}
		GridTrackPlacementStyleValue {
			input := longhand_grid_placement_input(value)?
			ComputedLonghandReuseValue{kind: input.kind, integer: input.number, number: if input.has_number { 1 } else { 0 }, has_name: input.name != none, text: input.name or { '' }}
		}
		BorderRadiusStyleValue {
			ComputedLonghandReuseValue{kind: .border_radius, integer: if value.is_elliptical_ { 1 } else { 0 }, children: [computed_longhand_reuse_typed_snapshot(&value.horizontal_radius[0]), computed_longhand_reuse_typed_snapshot(&value.vertical_radius[0])]}
		}
		else { none }
	}
}

fn longhand_shape_snapshot_matches(snapshot &ComputedLonghandReuseValue, value &StyleValue) bool {
	if !longhand_shape_is_simple(value) { return false }
	if value is BorderRadiusStyleValue {
		return snapshot.kind == .border_radius && snapshot.integer == (if value.is_elliptical_ { 1 } else { 0 })
			&& snapshot.children.len == 2
			&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[0], &value.horizontal_radius[0])
			&& computed_longhand_reuse_typed_snapshot_matches(&snapshot.children[1], &value.vertical_radius[0])
	}
	current := longhand_shape_snapshot(value) or { return false }
	return snapshot.kind == current.kind && snapshot.integer == current.integer
		&& snapshot.number == current.number && snapshot.has_name == current.has_name
		&& snapshot.text == current.text
}

fn longhand_shape_hash(value &StyleValue) ?u64 {
	if !longhand_shape_is_simple(value) { return none }
	if value is BorderRadiusStyleValue {
		mut hash := u64(0xa471d2) ^ if value.is_elliptical_ { u64(1) } else { u64(0) }
		hash = (hash ^ computed_longhand_reuse_typed_hash(&value.horizontal_radius[0])?) * u64(0x100000001b3)
		return (hash ^ computed_longhand_reuse_typed_hash(&value.vertical_radius[0])?) * u64(0x100000001b3)
	}
	input := longhand_shape_snapshot(value)?
	mut hash := (u64(0xa471d3) ^ u64(input.kind)) * u64(0x100000001b3)
	hash = (hash ^ u64(input.integer) ^ computed_longhand_reuse_number_hash(input.number)) * u64(0x100000001b3)
	hash = (hash ^ if input.has_name { u64(1) } else { u64(0) }) * u64(0x100000001b3)
	return (hash ^ u64(input.text.hash())) * u64(0x100000001b3)
}

fn report_longhand_shape_restore(inputs []ComputedLonghandReuseInput) {
	if !longhand_shape_reuse_diagnostics || longhand_shape_reuse_reported || disable_longhand_shape_reuse { return }
	for input in inputs {
		if input.snapshot.kind in [.grid_auto_flow, .grid_auto, .grid_line, .grid_span, .border_radius]
			|| (input.snapshot.kind == .length && input.snapshot.length_unit in [.vw, .vh, .vmin, .vmax]) {
			longhand_shape_reuse_reported = true
			eprintln('Vox longhand shape reuse: restored viewport, grid or radius input')
			return
		}
	}
}
