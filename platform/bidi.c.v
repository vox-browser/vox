module platform

#flag darwin -licucore
#flag linux -licuuc
#include <unicode/ubidi.h>

fn C.ubidi_openSized(i32, i32, &i32) voidptr
fn C.ubidi_close(voidptr)
fn C.ubidi_setPara(voidptr, &u16, i32, u8, &u8, &i32)
fn C.ubidi_getLevelAt(voidptr, i32) u8
fn C.ubidi_reorderVisual(&u8, i32, &i32)

// UTF-16 levels and the visual-to-logical map share the offsets used by DOM
// ranges and shaped text. ICU owns only its temporary paragraph record.
pub fn bidi_paragraph_levels(text []u16, rtl bool) []u8 {
	if text.len == 0 { return []u8{} }
	mut status := i32(0)
	bidi := C.ubidi_openSized(i32(text.len), 0, &status)
	if status > 0 || bidi == unsafe { nil } { return []u8{} }
	defer { C.ubidi_close(bidi) }
	C.ubidi_setPara(bidi, text.data, i32(text.len), if rtl { u8(1) } else { u8(0) }, unsafe { nil }, &status)
	if status > 0 { return []u8{} }
	mut levels := []u8{len: text.len}
	for index in 0 .. text.len { levels[index] = C.ubidi_getLevelAt(bidi, i32(index)) }
	return levels
}

pub fn bidi_visual_order(levels []u8) []int {
	if levels.len == 0 { return []int{} }
	mut indices := []i32{len: levels.len}
	C.ubidi_reorderVisual(levels.data, i32(levels.len), indices.data)
	return indices.map(int(it))
}
