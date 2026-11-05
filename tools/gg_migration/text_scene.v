// Runs the text scene scripts of skia_text_oracle.mm with gg.canvas'
// RasterSurface and compares every byte with NAME.expected.bgra.
//
// Usage: text-scene SCRIPT DIRECTORY [-v]
module main

import gg.canvas
import os
import strconv

struct Scene {
mut:
	name        string
	width       int
	height      int
	transparent bool = true
	background  u32
	font_path   string
	font_size   f32 = 16
	font_weight int = 400
	smoothing   int = 16
	matrix      [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
	color       [4]u8  = [u8(0), 0, 0, 255]!
	origin      canvas.Point
	glyphs      []u16
	positions   []f64
}

fn f(s string) f32 {
	return f32(strconv.atof64(s) or { 0 })
}

fn typeface_for(mut cache map[string]&canvas.Typeface, path string) !&canvas.Typeface {
	if t := cache[path] {
		return t
	}
	t := canvas.Typeface.from_file(path)!
	cache[path] = t
	return t
}

// render mirrors draw_retained_glyph_run's font setup and drawTextBlob call.
fn render(mut cache map[string]&canvas.Typeface, scene Scene) ![]u32 {
	typeface := typeface_for(mut cache, scene.font_path)!
	sm := scene.smoothing
	mut font := canvas.Font{
		typeface: typeface
		size:     if scene.font_size > 0 { scene.font_size } else { 0 }
		subpixel: true
	}
	if sm & 16 != 0 && sm & 128 == 0 && scene.font_weight >= 600 {
		return error('synthetic bold depends on the face weight (not ported)')
	}
	if sm & 64 != 0 {
		return error('synthetic slant depends on the face style (not ported)')
	}
	if sm & 16 != 0 {
		font.embedded_bitmaps = false
		font.linear_metrics = true
		font.edging = .subpixel_antialias
	}
	match sm & 15 {
		1 {
			font.edging = .alias
		}
		2 {
			font.edging = .antialias
			font.hinting = .none
		}
		3 {
			font.edging = .subpixel_antialias
		}
		else {}
	}
	chromium := sm & 16 != 0
	mut positions := []canvas.Point{cap: scene.glyphs.len}
	ox := if chromium { scene.origin.x } else { f32(0) }
	oy := if chromium { scene.origin.y } else { f32(0) }
	for i in 0 .. scene.glyphs.len {
		positions << canvas.Point{f32(scene.positions[2 * i]) + ox, f32(scene.positions[2 * i + 1]) + oy}
	}
	blob_origin := if chromium { canvas.Point{} } else { scene.origin }
	mut surface := canvas.new_raster_surface(
		width:  scene.width
		height: scene.height
		props:  if chromium {
			canvas.SurfaceProps{
				text_contrast: 0
				text_gamma:    if sm & 15 == 2 { f32(1) } else { f32(0) }
			}
		} else {
			canvas.SurfaceProps{}
		}
	)!
	if !scene.transparent {
		surface.clear(scene.background)
	}
	m := scene.matrix
	surface.set_matrix(canvas.Matrix.values([m[0], m[2], m[4], m[1], m[3], m[5], 0, 0, 1]!))
	c := scene.color
	paint := canvas.Paint.rgba8(c[0], c[1], c[2], c[3])
	surface.draw_glyphs(font, scene.glyphs, positions, blob_origin, paint)!
	return surface.pixels
}

fn main() {
	if os.args.len < 3 {
		eprintln('usage: text-scene SCRIPT DIRECTORY [-v]')
		exit(2)
	}
	verbose := '-v' in os.args
	dir := os.args[2]
	mut cache := map[string]&canvas.Typeface{}
	mut scene := Scene{}
	mut total, mut exact, mut unsupported, mut failed := 0, 0, 0, 0
	for line in os.read_lines(os.args[1])! {
		w := line.fields()
		if w.len == 0 || w[0].starts_with('#') {
			continue
		}
		match w[0] {
			'text' {
				scene = Scene{
					name:   w[1]
					width:  w[2].int()
					height: w[3].int()
				}
			}
			'background' {
				if w[1] == 'transparent' {
					scene.transparent = true
				} else {
					scene.transparent = false
					scene.background = u32(w[4].int()) << 24 | u32(w[3].int()) << 16 | u32(w[2].int()) << 8 | u32(w[1].int())
				}
			}
			'font' {
				scene.font_path = w[1]
				scene.font_size = f(w[2])
				scene.font_weight = w[3].int()
				scene.smoothing = w[4].int()
			}
			'matrix' {
				for i in 0 .. 6 {
					scene.matrix[i] = f(w[1 + i])
				}
			}
			'color' {
				for i in 0 .. 4 {
					scene.color[i] = u8(w[1 + i].int())
				}
			}
			'origin' {
				scene.origin = canvas.Point{f(w[1]), f(w[2])}
			}
			'glyph' {
				scene.glyphs << u16(w[1].int())
				scene.positions << strconv.atof64(w[2])!
				scene.positions << strconv.atof64(w[3])!
			}
			'end' {
				total++
				pixels := render(mut cache, scene) or {
					unsupported++
					if verbose {
						println('${scene.name}: unsupported: ${err}')
					}
					continue
				}
				expected := os.read_bytes(os.join_path(dir, '${scene.name}.expected.bgra')) or {
					failed++
					println('${scene.name}: missing expected pixels')
					continue
				}
				mut diffs := 0
				mut first := -1
				for i, p in pixels {
					e := u32(expected[4 * i]) | u32(expected[4 * i + 1]) << 8 | u32(expected[4 * i + 2]) << 16 | u32(expected[4 * i + 3]) << 24
					if e != p {
						if first < 0 {
							first = i
						}
						diffs++
					}
				}
				if diffs == 0 {
					exact++
				} else {
					failed++
					fi := first
					e := u32(expected[4 * fi]) | u32(expected[4 * fi + 1]) << 8 | u32(expected[4 * fi + 2]) << 16 | u32(expected[4 * fi + 3]) << 24
					println('${scene.name}: ${diffs} pixels differ; first (${fi % scene.width}, ${fi / scene.width}) expected ${e:08x} got ${pixels[fi]:08x}')
					mut actual := []u8{len: pixels.len * 4}
					for i, p in pixels {
						actual[4 * i] = u8(p)
						actual[4 * i + 1] = u8(p >> 8)
						actual[4 * i + 2] = u8(p >> 16)
						actual[4 * i + 3] = u8(p >> 24)
					}
					os.write_file_array(os.join_path(dir, '${scene.name}.actual.bgra'), actual) or {}
				}
			}
			else {}
		}
	}
	println('${total} scenes: ${exact} exact, ${failed} different, ${unsupported} unsupported')
	if failed > 0 {
		exit(1)
	}
}
