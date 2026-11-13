module libjs

import vunicode

pub fn regex_unicode_category_from_string(name string) ?u32 { return vunicode.category_id(name) }

fn regex_unicode_category_mask(id u32) u32 { return vunicode.category_mask(id) }

pub fn regex_unicode_property_from_string(name string) ?u32 { return vunicode.property_id(name) }

pub fn regex_unicode_script_from_string(name string) ?u32 { return vunicode.script_id(name) }

fn regex_unicode_property_id_start(point u32) bool {
	return vunicode.property_named(point, 'ID_Start')
}

fn regex_unicode_property_id_continue(point u32) bool {
	return vunicode.property_named(point, 'ID_Continue')
}

pub fn regex_unicode_has_general_category(point u32, id u32, ignore_case bool) bool {
	mask := vunicode.category_mask(id)
	if (u32(1) << vunicode.category(point)) & mask != 0 { return true }
	if ignore_case {
		for p in vunicode.case_closure(point) {
			if (u32(1) << vunicode.category(p)) & mask != 0 { return true }
		}
	}
	return false
}

pub fn regex_unicode_has_property(point u32, id u32, ignore_case bool) bool {
	// Synthetic properties are tested directly, without case closure.
	if id >= 77 { return vunicode.has_property(point, id) }
	if point > 0x10ffff && id >= 37 && id <= 41 { return true }
	if point >= 0x80000000 && id in [u32(51), 52, 53, 55] { return true }
	if vunicode.has_property(point, id) { return true }
	if ignore_case {
		for p in vunicode.case_closure(point) { if vunicode.has_property(p, id) { return true } }
	}
	return false
}

pub fn regex_unicode_has_script(point u32, id u32) bool {
	return point <= 0x10ffff && vunicode.script(point) == id
}

pub fn regex_unicode_has_script_extension(point u32, id u32) bool {
	return if point > 0x10ffff { id == 103 } else { vunicode.has_script(point, id) }
}

pub fn regex_unicode_is_ecma262_property(id u32) bool {
	return id in [u32(0), 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 13, 15, 16, 17, 18, 19, 20, 21, 22, 23,
		24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 35, 36, 42, 43, 49, 50, 51, 52, 53, 54, 55, 56,
		57, 58, 59, 60, 61, 62, 64, 77, 78, 79]
}

pub fn regex_unicode_is_ecma262_string_property(id u32) bool { return id >= 65 && id <= 71 }
