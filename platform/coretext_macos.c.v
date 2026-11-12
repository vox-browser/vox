module platform

#flag darwin -framework CoreText
#flag darwin -framework CoreFoundation
#include "coretext_macos.h"
#include "@DIR/../cpuraster/glyph_coretext.h"

fn C.cpuraster_ct_advances(path &char, index int, size f32, glyphs &u16, count int, widths &f32) int
fn C.cpuraster_ct_register_face(key &char, path &char, name &char, tags &u32, values &f32, count int) int

@[typedef]
struct C.vox_ct_face {
	path        [1024]char
	postscript  [256]char
	family      [256]char
	ascent      f64
	descent     f64
	leading     f64
	x_height    f64
	cap_height  f64
	bbox_x_min  f64
	bbox_y_min  f64
	bbox_x_max  f64
	bbox_y_max  f64
	face_index  int
	weight      int
	italic      int
	axis_count  int
	axis_tags   [16]u32
	axis_values [16]f32
}

fn C.vox_ct_match_family(family &char, weight int, italic int, size f64, face &C.vox_ct_face) int
fn C.vox_ct_family_available(family &char) int
fn C.vox_ct_fallback(text &u16, length int, language &char, base_family &char, weight int, italic int, size f64, face &C.vox_ct_face) int

fn system_font_face_from_native(native &C.vox_ct_face) SystemFontFace {
	mut variations := []FontVariationAxis{cap: native.axis_count}
	for index in 0 .. native.axis_count {
		variations << FontVariationAxis{
			tag:   native.axis_tags[index]
			value: native.axis_values[index]
		}
	}
	return SystemFontFace{
		path:            unsafe { cstring_to_vstring(&char(&native.path[0])) }
		postscript_name: unsafe { cstring_to_vstring(&char(&native.postscript[0])) }
		family_name:     unsafe { cstring_to_vstring(&char(&native.family[0])) }
		metrics:         SystemFontMetrics{
			ascent:     native.ascent
			descent:    native.descent
			leading:    native.leading
			x_height:   native.x_height
			cap_height: native.cap_height
			bbox_x_min: native.bbox_x_min
			bbox_y_min: native.bbox_y_min
			bbox_x_max: native.bbox_x_max
			bbox_y_max: native.bbox_y_max
		}
		face_index:      native.face_index
		weight:          native.weight
		italic:          native.italic != 0
		variations:      variations
	}
}

fn coretext_match_family(family string, weight int, italic bool, size f32) ?SystemFontFace {
	// Current V boxes this large native output record when its fields are
	// borrowed by the converter. Retire it after copying the final face payload.
	mut work := begin_thread_scratch('CoreText face query')
	defer { work.finish() }
	native := C.vox_ct_face{}
	if C.vox_ct_match_family(&char(family.str), weight, int(italic), f64(size), &native) == 0 {
		return none
	}
	work.leave()
	return system_font_face_from_native(&native)
}

fn coretext_family_available(family string) bool {
	return C.vox_ct_family_available(&char(family.str)) != 0
}

fn coretext_fallback(text []u16, language string, base_family string, weight int, italic bool, size f32) ?SystemFontFace {
	if text.len == 0 {
		return none
	}
	mut work := begin_thread_scratch('CoreText face query')
	defer { work.finish() }
	native := C.vox_ct_face{}
	if C.vox_ct_fallback(text.data, text.len, &char(language.str), &char(base_family.str), weight, int(italic),
		f64(size), &native) == 0 {
		return none
	}
	work.leave()
	return system_font_face_from_native(&native)
}
