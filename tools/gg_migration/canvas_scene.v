// Executes gg.canvas scene scripts (see skia_oracle.mm) and compares every
// rendered byte with the reference pixels of the Skia Graphite oracle.
module main

import gg.canvas
import os
import strconv

$if trace ? {
	#flag @DIR/../../Build/gg-oracle/metal_trace.o
	#flag -lc++ -framework Foundation -framework Metal
}

fn C.vox_metal_trace_install(directory &char)
fn C.vox_metal_trace_begin(directory &char, name &char)
fn C.vox_metal_trace_end()

struct SceneState {
mut:
	name       string
	width      int
	height     int
	samples    int
	background bool
	surface    &canvas.GpuSurface = unsafe { nil }
	paint      canvas.Paint
	error      string
}

fn backdrop(width int, height int) []u8 {
	// Must match skia_oracle.mm.
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			i := (y * width + x) * 4
			alpha := 128 + (x * 7 + y * 3) % 128
			pixels[i] = u8((x * 13) % (alpha + 1))
			pixels[i + 1] = u8((y * 29) % (alpha + 1))
			pixels[i + 2] = u8(((x + y) * 5) % (alpha + 1))
			pixels[i + 3] = u8(alpha)
		}
	}
	return pixels
}

fn floats(words []string, from int, count int) []f32 {
	mut out := []f32{cap: count}
	for i in from .. from + count {
		out << f32(strconv.atof64(words[i]) or { panic('bad number `${words[i]}`') })
	}
	return out
}

fn main() {
	if os.args.len < 3 {
		eprintln('usage: canvas_scene SCRIPT ORACLE_DIRECTORY [--verbose]')
		exit(2)
	}
	verbose := '--verbose' in os.args
	lines := os.read_lines(os.args[1]) or { panic(err) }
	directory := os.args[2]
	trace_directory := os.join_path(directory, 'gg-trace')
	$if trace ? {
		os.mkdir_all(trace_directory) or {}
		C.vox_metal_trace_install(&char(trace_directory.str))
	}
	mut ctx := canvas.new_gpu_context() or { panic(err) }
	mut state := SceneState{}
	mut passed := 0
	mut failed := 0
	mut unsupported := 0
	mut unsupported_reasons := map[string]int{}
	for line in lines {
		words := line.fields()
		if words.len == 0 || words[0].starts_with('#') {
			continue
		}
		match words[0] {
			'scene' {
				state = SceneState{
					name:       words[1]
					width:      words[2].int()
					height:     words[3].int()
					samples:    words[4].int()
					background: words[5] == '1'
				}
				$if trace ? {
					C.vox_metal_trace_begin(&char(trace_directory.str), &char(state.name.str))
				}
				state.surface = ctx.new_surface(
					width:        state.width
					height:       state.height
					sample_count: state.samples
				) or { panic(err) }
				if state.background {
					pixels := backdrop(state.width, state.height)
					state.surface.write_pixels(pixels.data, state.width * 4) or {
						state.error = err.msg()
					}
				} else {
					state.surface.clear(canvas.Color4f{})
				}
				if state.samples == 4 {
					// The oracle forces MSAA like Vox: a tiny transparent path.
					state.surface.draw_msaa_trigger()
				}
			}
			'matrix' {
				v := floats(words, 1, 9)
				state.surface.set_matrix(canvas.Matrix.values([v[0], v[1], v[2], v[3], v[4], v[5],
					v[6], v[7], v[8]]!))
			}
			'paint' {
				v := floats(words, 1, 4)
				state.paint = canvas.Paint{
					color:        canvas.Color4f{v[0], v[1], v[2], v[3]}
					anti_alias:   words[5] == '1'
					style:        if words[6] == '1' { .stroke } else { .fill }
					stroke_width: floats(words, 7, 1)[0]
					join:         match words[8] {
						'1' { .round }
						'2' { .bevel }
						else { .miter }
					}
					cap:          match words[9] {
						'1' { .round }
						'2' { .square }
						else { .butt }
					}
					miter_limit:  floats(words, 10, 1)[0]
				}
			}
			'gradient' {
				// KIND TILE PREMUL DITHER LINEARCS OPACITY N, six points, the
				// local matrix and N stops (R G B A POS), like the oracle.
				count := words[7].int()
				pts := floats(words, 8, 6)
				m := floats(words, 14, 9)
				mut colors := []canvas.Color4f{}
				mut positions := []f32{}
				for i in 0 .. count {
					s := floats(words, 23 + i * 5, 5)
					colors << canvas.Color4f{s[0], s[1], s[2], s[3]}
					positions << s[4]
				}
				base := canvas.Gradient{
					colors:       colors
					positions:    positions
					tile_mode:    unsafe { canvas.TileMode(words[2].int()) }
					premul:       words[3] == '1'
					local_matrix: canvas.Matrix.values([m[0], m[1], m[2], m[3], m[4], m[5], m[6],
						m[7], m[8]]!)
				}
				if words[1] == '1' {
					state.paint.gradient = canvas.Gradient{
						...base
						kind: .linear
						p0:   canvas.Point{pts[0], pts[1]}
						p1:   canvas.Point{pts[2], pts[3]}
					}
				} else {
					state.paint.gradient = canvas.Gradient.two_point_conical(canvas.Point{pts[0], pts[1]},
						pts[2], canvas.Point{pts[3], pts[4]}, pts[5], base) or {
						state.error = err.msg()
						continue
					}
				}
				state.paint.dither = words[4] == '1'
				opacity := floats(words, 6, 1)[0]
				c := state.paint.color
				state.paint.color = canvas.Color4f{c.r, c.g, c.b, if opacity < 0 {
					f32(0)
				} else if opacity > 1 {
					f32(1)
				} else {
					opacity
				}}
				if words[5] == '1' {
					state.error = 'gg.canvas: linear color space gradients are not supported'
				}
			}
			'color8' {
				state.paint.color = canvas.Color4f.from_rgba8(u8(words[1].int()), u8(words[2].int()),
					u8(words[3].int()), u8(words[4].int()))
			}
			'clipout' {
				v := floats(words, 1, 4)
				state.surface.clip_rect(canvas.Rect.ltrb(v[0], v[1], v[2], v[3]), .difference,
					false) or { state.error = err.msg() }
			}
			'cliprect' {
				v := floats(words, 1, 4)
				op := if words[5] == '1' {
					canvas.ClipOp.difference
				} else {
					canvas.ClipOp.intersect
				}
				state.surface.clip_rect(canvas.Rect.ltrb(v[0], v[1], v[2], v[3]), op, words[6] == '1') or {
					state.error = err.msg()
				}
			}
			'cliprrect' {
				rrect := read_rrect(words, 1)
				op := if words[13] == '1' {
					canvas.ClipOp.difference
				} else {
					canvas.ClipOp.intersect
				}
				state.surface.clip_rrect(rrect, op, words[14] == '1') or { state.error = err.msg() }
			}
			'drrect' {
				state.surface.draw_drrect(read_rrect(words, 1), read_rrect(words, 13), state.paint) or {
					state.error = err.msg()
				}
			}
			'path' {
				path := read_path(words) or {
					state.error = err.msg()
					continue
				}
				state.surface.draw_path(path, state.paint) or { state.error = err.msg() }
			}
			'clippath' {
				op := if words[1] == '1' {
					canvas.ClipOp.difference
				} else {
					canvas.ClipOp.intersect
				}
				// read_path() reads the fill rule and tokens after two words.
				path := read_path(words[2..]) or {
					state.error = err.msg()
					continue
				}
				state.surface.clip_path(path, op, words[2] == '1') or { state.error = err.msg() }
			}
			'save' {
				state.surface.save()
			}
			'restore' {
				state.surface.restore()
			}
			'savelayer' {
				if words.len >= 5 {
					v := floats(words, 1, 4)
					state.surface.save_layer(canvas.Rect.ltrb(v[0], v[1], v[2], v[3])) or {
						state.error = err.msg()
					}
				} else {
					state.surface.save_layer(none) or { state.error = err.msg() }
				}
			}
			'rect', 'oval', 'rrect' {
				v := floats(words, 1, 4)
				rect := canvas.Rect.ltrb(v[0], v[1], v[2], v[3])
				if words[0] == 'rect' {
					state.surface.draw_rect(rect, state.paint) or { state.error = err.msg() }
				} else if words[0] == 'oval' {
					state.surface.draw_oval(rect, state.paint) or { state.error = err.msg() }
				} else {
					r := floats(words, 5, 8)
					rrect := canvas.RRect.rect_radii(rect, [canvas.Point{r[0], r[1]},
						canvas.Point{r[2], r[3]}, canvas.Point{r[4], r[5]}, canvas.Point{r[6], r[7]}]!)
					state.surface.draw_rrect(rrect, state.paint) or { state.error = err.msg() }
				}
			}
			'end' {
				pitch := state.width * 4
				mut actual := []u8{len: pitch * state.height}
				state.surface.read_pixels(actual.data, pitch) or {
					// Errors of draws gg.canvas defers to the flush, like a
					// layer's restore.
					if state.error == '' {
						state.error = err.msg()
					}
				}
				state.surface.free()
				$if trace ? {
					C.vox_metal_trace_end()
				}
				if state.error != '' {
					unsupported++
					unsupported_reasons[state.error]++
					if verbose {
						println('UNSUPPORTED ${state.name}: ${state.error}')
					}
					continue
				}
				expected := os.read_bytes(os.join_path(directory, state.name + '.expected.bgra')) or {
					panic(err)
				}
				mut differing := 0
				mut max_error := 0
				for i in 0 .. expected.len {
					if expected[i] != actual[i] {
						differing++
						d := int(expected[i]) - int(actual[i])
						if d > max_error || -d > max_error {
							max_error = if d < 0 { -d } else { d }
						}
					}
				}
				if differing == 0 {
					passed++
					if verbose {
						println('PASS ${state.name}')
					}
				} else {
					failed++
					println('FAIL ${state.name}: ${differing} bytes differ, max error ${max_error}')
					os.write_file_array(os.join_path(directory, state.name + '.actual.bgra'),
						actual) or {}
				}
			}
			else {
				panic('unknown command `${words[0]}`')
			}
		}
	}
	ctx.free()
	for reason, count in unsupported_reasons {
		println('unsupported (${count}): ${reason}')
	}
	println('${passed} passed, ${failed} failed, ${unsupported} unsupported')
	exit(if failed == 0 { 0 } else { 1 })
}

// read_rrect parses a rectangle and four radius pairs starting at word
// `start`, like SkRRect::setRectRadii().
fn read_rrect(words []string, start int) canvas.RRect {
	v := floats(words, start, 4)
	r := floats(words, start + 4, 8)
	return canvas.RRect.rect_radii(canvas.Rect.ltrb(v[0], v[1], v[2], v[3]), [
		canvas.Point{r[0], r[1]},
		canvas.Point{r[2], r[3]},
		canvas.Point{r[4], r[5]},
		canvas.Point{r[6], r[7]},
	]!)
}

// read_path parses a `path FILL TOKENS...` line like skia_oracle.mm.
fn read_path(words []string) !canvas.Path {
	mut b := canvas.PathBuilder{}
	mut i := 2
	for i < words.len {
		token := words[i]
		i++
		match token {
			'M' {
				v := floats(words, i, 2)
				b.move_to(v[0], v[1])
				i += 2
			}
			'L' {
				v := floats(words, i, 2)
				b.line_to(v[0], v[1])
				i += 2
			}
			'Q' {
				v := floats(words, i, 4)
				b.quad_to(v[0], v[1], v[2], v[3])
				i += 4
			}
			'C' {
				v := floats(words, i, 6)
				b.cubic_to(v[0], v[1], v[2], v[3], v[4], v[5])
				i += 6
			}
			'K' {
				v := floats(words, i, 5)
				b.conic_to(v[0], v[1], v[2], v[3], v[4])
				i += 5
			}
			'A' {
				v := floats(words, i, 7)
				b.arc_to_svg(v[0], v[1], v[2], v[3] != 0, if v[4] != 0 { .cw } else { .ccw }, v[5],
					v[6])
				i += 7
			}
			'Z' {
				b.close()
			}
			'O' {
				v := floats(words, i, 4)
				b.add_oval(canvas.Rect.ltrb(v[0], v[1], v[2], v[3]), .cw, 1)
				i += 4
			}
			else {
				return error('unknown path token `${token}`')
			}
		}
	}
	b.set_fill_type(match words[1] {
		'1' { .even_odd }
		'2' { .inverse_winding }
		'3' { .inverse_even_odd }
		else { .winding }
	})
	return b.detach()
}
