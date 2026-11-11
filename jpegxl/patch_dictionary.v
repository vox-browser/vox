// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum PatchBlendMode {
	none
	replace
	add
	multiply
	blend_above
	blend_below
	alpha_weighted_add_above
	alpha_weighted_add_below
}

pub fn (mode PatchBlendMode) uses_alpha() bool {
	return int(mode) >= 4 && int(mode) <= 7
}

pub fn (mode PatchBlendMode) uses_clamp() bool {
	return mode == .multiply || mode.uses_alpha()
}

pub struct PatchBlending {
pub:
	mode          PatchBlendMode
	alpha_channel int
	clamp         bool
}

// Geometry belongs to the stored frame, before its color transform. The owner
// supplies availability independently from zero-sized or absent plane storage.
pub struct PatchReferenceInfo {
pub:
	available                    bool
	saved_before_color_transform bool
	width                        int
	height                       int
}

pub struct PatchReferencePosition {
pub:
	reference int
	x0        int
	y0        int
	width     int
	height    int
}

pub struct PatchPosition {
pub:
	x         int
	y         int
	reference int
}

struct PatchInterval {
	id    int
	start int
	end   int
}

struct PatchTreeNode {
	center int
	starts []PatchInterval
	ends   []PatchInterval
mut:
	left  int = -1
	right int = -1
}

pub struct PatchesDictionary {
	nodes []PatchTreeNode
pub:
	positions        []PatchPosition
	references       []PatchReferencePosition
	blendings        []PatchBlending
	blendings_stride int
}

// Parse the dictionary without finalizing the shared symbol reader. The source
// does not check its ANS/deferred-error state here either. Codec owners retain
// their separate bounded-section checks.
pub fn (mut reader BitReader) read_patches(width int, height int, extra_channels int, references []PatchReferenceInfo) !PatchesDictionary {
	if width <= 0 || height <= 0 || extra_channels < 0 || extra_channels > 256 {
		return error('Invalid JPEG XL patch dimensions')
	}
	pixels := modular_sample_count(width, height)!
	stride := extra_channels + 1
	hist := reader.read_histograms(10, true)!
	mut symbols := SymbolReader.new(hist, mut reader, none)!
	num_refs := int(symbols.read_unsigned(&hist, 0, mut reader)!)
	max_refs := 1024 + pixels / 4
	max_patches := max_refs * 4
	max_blendings := max_patches * 4
	if num_refs > max_refs || num_refs > 1048576 {
		return error('Too many JPEG XL reference patches')
	}
	mut positions := []PatchPosition{}
	mut ref_positions := []PatchReferencePosition{}
	mut blendings := []PatchBlending{}
	mut total := 0
	mut next_size := 1
	for _ in 0 .. num_refs {
		ref := int(symbols.read_unsigned(&hist, 1, mut reader)!)
		if ref >= 4 { return error('Invalid JPEG XL patch reference slot') }
		x0 := int(symbols.read_unsigned(&hist, 3, mut reader)!)
		y0 := int(symbols.read_unsigned(&hist, 3, mut reader)!)
		w := int(symbols.read_unsigned(&hist, 2, mut reader)!) + 1
		h := int(symbols.read_unsigned(&hist, 2, mut reader)!) + 1
		if ref >= references.len || !references[ref].available {
			return error('Missing JPEG XL patch reference')
		}
		source := references[ref]
		if !source.saved_before_color_transform {
			return error('JPEG XL patch requires a reference before color conversion')
		}
		if w > source.width || h > source.height || x0 > source.width - w || y0 > source.height - h {
			return error('JPEG XL patch exceeds its source')
		}
		count := int(symbols.read_unsigned(&hist, 7, mut reader)!) + 1
		if count > max_patches - total || count > 1048576 - total {
			return error('Too many JPEG XL patch positions')
		}
		total += count
		if next_size < total {
			next_size *= 2
			if next_size > max_patches { next_size = max_patches }
		}
		if next_size * stride > max_blendings || total * stride > 4194304 {
			return error('Too many JPEG XL patch blending records')
		}
		for i in 0 .. count {
			mut x := 0
			mut y := 0
			if i == 0 {
				x = int(symbols.read_unsigned(&hist, 4, mut reader)!)
				y = int(symbols.read_unsigned(&hist, 4, mut reader)!)
			} else {
				x = positions.last().x + int(symbols.read_signed(&hist, 6, mut reader)!)
				if x < 0 { return error('Negative JPEG XL patch x offset') }
				y = positions.last().y + int(symbols.read_signed(&hist, 6, mut reader)!)
				if y < 0 { return error('Negative JPEG XL patch y offset') }
			}
			if w > width || h > height || x > width - w || y > height - h {
				return error('JPEG XL patch exceeds its destination')
			}
			for _ in 0 .. stride {
				// The original parser narrows to u8 before checking the enum.
				value := u8(symbols.read_unsigned(&hist, 5, mut reader)!)
				if value > 7 { return error('Invalid JPEG XL patch blend mode') }
				mode := unsafe { PatchBlendMode(value) }
				alpha := if mode.uses_alpha() && stride > 2 {
					int(symbols.read_unsigned(&hist, 8, mut reader)!)
				} else {
					0
				}
				if mode.uses_alpha() && stride > 2 && alpha >= extra_channels {
					return error('Invalid JPEG XL patch alpha channel')
				}
				clamp := if mode.uses_clamp() {
					symbols.read_unsigned(&hist, 9, mut reader)! != 0
				} else {
					false
				}
				blendings << PatchBlending{ mode: mode, alpha_channel: alpha, clamp: clamp }
			}
			positions << PatchPosition{ x: x, y: y, reference: ref_positions.len }
		}
		ref_positions << PatchReferencePosition{ reference: ref, x0: x0, y0: y0, width: w, height: h }
	}
	mut intervals := []PatchInterval{cap: positions.len}
	for i, p in positions {
		intervals << PatchInterval{ id: i, start: p.y, end: p.y + ref_positions[p.reference].height }
	}
	mut nodes := []PatchTreeNode{}
	if intervals.len > 0 { build_patch_tree(intervals, mut nodes) }
	return PatchesDictionary{
		positions:        positions
		references:       ref_positions
		blendings:        blendings
		blendings_stride: stride
		nodes:            nodes
	}
}

// A balanced interval tree avoids the source's per-row counting allocation and
// repeated increments. Only active intervals are collected; IDs are sorted to
// preserve the bitstream's compositing order.
fn build_patch_tree(input []PatchInterval, mut nodes []PatchTreeNode) int {
	mut sorted := input.clone()
	sorted.sort(a.start < b.start)
	center := sorted[sorted.len / 2].start
	mut left := []PatchInterval{}
	mut right := []PatchInterval{}
	mut crossing := []PatchInterval{}
	for interval in sorted {
		if interval.end <= center {
			left << interval
		} else if interval.start > center {
			right << interval
		} else {
			crossing << interval
		}
	}
	mut ends := crossing.clone()
	ends.sort(a.end > b.end)
	index := nodes.len
	nodes << PatchTreeNode{ center: center, starts: crossing, ends: ends }
	if left.len > 0 {
		child := build_patch_tree(left, mut nodes)
		nodes[index].left = child
	}
	if right.len > 0 {
		child := build_patch_tree(right, mut nodes)
		nodes[index].right = child
	}
	return index
}

pub fn (patches PatchesDictionary) patches_for_row(y int) []int {
	mut result := []int{}
	mut index := if patches.nodes.len == 0 || y < 0 { -1 } else { 0 }
	for index >= 0 {
		node := patches.nodes[index]
		if y <= node.center {
			for interval in node.starts {
				if interval.start > y { break }
				result << interval.id
			}
			index = if y == node.center { -1 } else { node.left }
		} else {
			for interval in node.ends {
				if interval.end <= y { break }
				result << interval.id
			}
			index = node.right
		}
	}
	result.sort()
	return result
}
