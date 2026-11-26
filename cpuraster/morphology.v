module cpuraster

import math

const morphology_max_radius = 256
// The ring must hold the entire largest window (513 samples).
const morphology_queue_mask = 1023

// SkImageFilters::Erode/Dilate: the per-channel minimum or maximum over a
// (2rx+1) x (2ry+1) window with transparent black outside the layer.
fn general_morphology(image BlurImage, rx int, ry int, dilate bool) BlurImage {
	horizontal := morphology_pass(image, rx, false, dilate)
	return morphology_pass(horizontal, ry, true, dilate)
}

fn morphology_pass(image BlurImage, radius int, vertical bool, dilate bool) BlurImage {
	if radius <= 0 {
		return image
	}
	length := if vertical { image.height } else { image.width }
	lines := if vertical { image.width } else { image.height }
	row_bytes := image.width * 4
	output := []u8{len: image.pixels.len}
	scan := MorphologyScan{
		source:        image.pixels
		output:        output
		length:        length
		line_stride:   if vertical { 4 } else { row_bytes }
		sample_stride: if vertical { row_bytes } else { 4 }
		radius:        math.min(radius, morphology_max_radius)
		dilate:        dilate
	}
	run_raster_scans(&scan, lines, length, scan_morphology)
	return BlurImage{output, image.width, image.height}
}

struct MorphologyScan {
	source        []u8
	output        []u8
	length        int
	line_stride   int
	sample_stride int
	radius        int
	dilate        bool
}

fn scan_morphology(context voidptr, first i32, end i32) {
	scan := unsafe { &MorphologyScan(context) }
	mut output := unsafe { scan.output }
	// Outside samples cannot raise a maximum. For a minimum they force zero,
	// so leave the border of the zero-initialized output alone.
	border := if scan.dilate { 0 } else { scan.radius }
	mut positions := [morphology_queue_mask + 1]int{}
	mut values := [morphology_queue_mask + 1]u8{}
	for line in int(first) .. int(end) {
		for channel in 0 .. 4 {
			base := line * scan.line_stride + channel
			mut head, mut tail, mut next := 0, 0, 0
			for center in border .. scan.length - border {
				for head < tail && positions[head & morphology_queue_mask] < center - scan.radius {
					head++
				}
				last := math.min(center + scan.radius, scan.length - 1)
				for next <= last {
					value := scan.source[base + next * scan.sample_stride]
					// A newer, at least as extreme sample outlives the old one.
					for head < tail {
						old := values[(tail - 1) & morphology_queue_mask]
						if (scan.dilate && old > value) || (!scan.dilate && old < value) {
							break
						}
						tail--
					}
					positions[tail & morphology_queue_mask] = next
					values[tail & morphology_queue_mask] = value
					tail++
					next++
				}
				output[base + center * scan.sample_stride] = values[head & morphology_queue_mask]
			}
		}
	}
}
