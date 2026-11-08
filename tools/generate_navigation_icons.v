// Rebuild the small toolbar assets from the same 24-unit vector geometry.
// v run tools/generate_navigation_icons.v
module main

import image
import image.color
import image.png
import math
import os

struct Point {
	x f64
	y f64
}

struct Icon {
	name    string
	path    string
	strokes [][]Point
}

fn segment_distance(p Point, a Point, b Point) f64 {
	dx, dy := b.x - a.x, b.y - a.y
	t := math.max(0.0, math.min(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)))
	return math.hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
}

fn main() {
	mut arc := []Point{cap: 129}
	for step in 0 .. 129 {
		angle := f64(step) * 7 * math.pi / (4 * 128)
		arc << Point{12 + 7 * math.cos(angle), 12 + 7 * math.sin(angle)}
	}
	arc << Point{20, 10}
	icons := [
		Icon{'back', 'M19 12H5m7-7-7 7 7 7', [[Point{19, 12}, Point{5, 12}],
			[Point{12, 5}, Point{5, 12}, Point{12, 19}]]},
		Icon{'forward', 'M5 12h14m-7-7 7 7-7 7', [[Point{5, 12}, Point{19, 12}],
			[Point{12, 5}, Point{19, 12}, Point{12, 19}]]},
		Icon{'reload', 'M19 12a7 7 0 1 1-2.050253-4.949747L20 10m0-6v6h-6', [arc,
			[Point{20, 4}, Point{20, 10}, Point{14, 10}]]},
	]
	directory := @VMODROOT + '/browserui/icons/navigation'
	os.mkdir_all(directory)!
	for icon in icons {
		os.write_file(directory + '/${icon.name}.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#5f6368" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${icon.path}"/></svg>\n')!
		for disabled in [false, true] {
			ink := if disabled { u32(0xbdc1c6) } else { u32(0x5f6368) }
			mut bitmap := image.new_nrgba(image.rect(0, 0, 48, 48))
			for y in 0 .. 48 {
				for x in 0 .. 48 {
					mut coverage := 0
					for sy in 0 .. 4 {
						for sx in 0 .. 4 {
							p := Point{(f64(x) + (f64(sx) + 0.5) / 4) / 2, (f64(y) + (f64(sy) + 0.5) / 4) / 2}
							mut inside := false
							for stroke in icon.strokes {
								for index in 1 .. stroke.len {
									if segment_distance(p, stroke[index - 1], stroke[index]) <= 1 {
										inside = true
										break
									}
								}
								if inside { break }
							}
							if inside { coverage++ }
						}
					}
					bitmap.set_nrgba(x, y, color.NRGBA{ r: u8(ink >> 16), g: u8(ink >> 8), b: u8(ink), a: u8((coverage * 255 + 8) / 16) })
				}
			}
			name := icon.name + if disabled { '-disabled' } else { '' }
			mut file := os.create(directory + '/${name}.png')!
			png.encode(mut file, bitmap)!
			file.close()
		}
	}
}
