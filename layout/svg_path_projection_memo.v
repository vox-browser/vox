module layout

import math
import os
import painting
import platform
import svg

// Same-binary control: serialize, bound and flatten every SVG path again in
// each paint projection.
const disable_svg_path_projection_memo = os.getenv('VOX_DISABLE_SVG_PATH_PROJECTION_MEMO') != ''

// Persistent entries are never evicted, so the memo stops admitting paths
// once it holds this many coordinates.
const svg_path_projection_memo_coordinate_limit = 1 << 20

// What the paint projection derives from an SVG box's path alone. Every
// complete projection rebuilt it for each icon on the page, although the
// path, fill rule and precision rarely change between layout passes.
struct SVGPathProjectionResult {
	serialized  string
	path_bounds ?svg.Rect
	packed      []f32
	bounds      ?painting.Rect
}

struct SVGPathProjectionMemoEntry {
	kinds      []u8
	data       []f64
	even_odd   bool
	single     bool
	result     SVGPathProjectionResult
}

struct SVGPathProjectionMemo {
mut:
	entries     map[u64]&SVGPathProjectionMemoEntry
	coordinates int
}

__global svg_path_projection_memo_ = SVGPathProjectionMemo{}

fn svg_path_instruction_kind(instruction svg.PathInstruction) u8 {
	return u8(int(instruction.type_)) | if instruction.absolute { u8(0x80) } else { u8(0) }
}

fn svg_path_projection_key(path svg.Path, even_odd bool, single bool) u64 {
	mut h := u64(0xcbf29ce484222325)
	h = (h ^ u64(even_odd)) * 0x100000001b3
	h = (h ^ u64(single)) * 0x100000001b3
	for instruction in path.instructions {
		h = (h ^ u64(svg_path_instruction_kind(instruction))) * 0x100000001b3
		h = (h ^ u64(instruction.data.len)) * 0x100000001b3
		for value in instruction.data {
			h = (h ^ math.f64_bits(value)) * 0x100000001b3
		}
	}
	return h
}

// Entries keep their complete input so a hash collision can never return
// another path's geometry.
fn (entry &SVGPathProjectionMemoEntry) matches(path svg.Path, even_odd bool, single bool) bool {
	if entry.even_odd != even_odd || entry.single != single
		|| entry.kinds.len != path.instructions.len {
		return false
	}
	mut offset := 0
	for index, instruction in path.instructions {
		if entry.kinds[index] != svg_path_instruction_kind(instruction) { return false }
		if offset + instruction.data.len + 1 > entry.data.len
			|| entry.data[offset] != f64(instruction.data.len) {
			return false
		}
		offset++
		for value in instruction.data {
			if math.f64_bits(entry.data[offset]) != math.f64_bits(value) { return false }
			offset++
		}
	}
	return offset == entry.data.len
}

fn compute_svg_path_projection(path svg.Path, even_odd bool, single bool) SVGPathProjectionResult {
	rule := if even_odd { painting.WindingRule.even_odd } else { painting.WindingRule.nonzero }
	projection := svg_paint_path_projection(path, rule, true, single)
	return SVGPathProjectionResult{
		serialized:  path.serialize()
		path_bounds: svg_path_bounds(path)
		packed:      projection.packed_segments
		bounds:      projection.bounds
	}
}

// The returned packed segments belong to the caller's allocation scope, like
// a freshly computed projection; the serialized string is immutable and may
// be shared with the memo.
fn svg_path_projection(path svg.Path, even_odd bool, single bool) SVGPathProjectionResult {
	if disable_svg_path_projection_memo {
		return compute_svg_path_projection(path, even_odd, single)
	}
	key := svg_path_projection_key(path, even_odd, single)
	mut memo := unsafe { &svg_path_projection_memo_ }
	if entry := memo.entries[key] {
		if entry.matches(path, even_odd, single) {
			return SVGPathProjectionResult{
				...entry.result
				packed: entry.result.packed.clone()
			}
		}
	}
	result := compute_svg_path_projection(path, even_odd, single)
	mut coordinates := 0
	for instruction in path.instructions { coordinates += instruction.data.len + 1 }
	if key in memo.entries || memo.coordinates + coordinates > svg_path_projection_memo_coordinate_limit {
		return result
	}
	persistent := platform.enter_persistent()
	mut kinds := []u8{cap: path.instructions.len}
	mut data := []f64{cap: coordinates}
	for instruction in path.instructions {
		kinds << svg_path_instruction_kind(instruction)
		data << f64(instruction.data.len)
		for value in instruction.data { data << value }
	}
	memo.entries[key] = &SVGPathProjectionMemoEntry{
		kinds:    kinds
		data:     data
		even_odd: even_odd
		single:   single
		result:   SVGPathProjectionResult{
			...result
			serialized: result.serialized.clone()
			packed:     result.packed.clone()
		}
	}
	memo.coordinates += coordinates
	platform.leave_persistent(persistent)
	return result
}
