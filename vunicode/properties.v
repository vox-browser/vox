// Unicode data lookup and lossless UTF-16 primitives. All runtime code is V.
module vunicode

const properties_category_data = $embed_file('data/category.bin').to_string()
const properties_ccc_data = $embed_file('data/ccc.bin').to_string()
const properties_bidi_data = $embed_file('data/bidi.bin').to_string()
const properties_script_data = $embed_file('data/script.bin').to_string()
const properties_line_data = $embed_file('data/line.bin').to_string()
const properties_word_data = $embed_file('data/word.bin').to_string()
const properties_east_asian_data = $embed_file('data/east_asian.bin').to_string()
const properties_joining_data = $embed_file('data/joining.bin').to_string()
const properties_script_extensions_data = $embed_file('data/script_extensions.bin').to_string()
const properties_script_extensions_pool_data = $embed_file('data/script_extensions_pool.bin').to_string()
const properties_closure_data = $embed_file('data/closure.bin').to_string()
const properties_closure_pool_data = $embed_file('data/closure_pool.bin').to_string()
const properties_fold_data = $embed_file('data/fold.bin').to_string()
const properties_fold_pool_data = $embed_file('data/fold_pool.bin').to_string()
const properties_brackets_data = $embed_file('data/brackets.bin').to_string()

pub const version = '17.0.0'

fn word(data string, offset int) u32 {
	return u32(data[offset]) | (u32(data[offset + 1]) << 8) | (u32(data[offset + 2]) << 16) | (u32(data[offset + 3]) << 24)
}

fn row(data string, point u32, stride int) int {
	mut low := 0
	mut high := data.len / stride
	for low < high {
		mid := (low + high) / 2
		if point < word(data, mid * stride) {
			high = mid
		} else if point > word(data, mid * stride + 4) {
			low = mid + 1
		} else {
			return mid * stride
		}
	}
	return -1
}

fn value(data string, point u32, fallback u32) u32 {
	i := row(data, point, 12)
	return if i < 0 { fallback } else { word(data, i + 8) }
}

fn mapping(data string, pool string, point u32) []u32 {
	i := row(data, point, 16)
	if i < 0 { return [point] }
	start := int(word(data, i + 8)) * 4
	count := int(word(data, i + 12))
	mut result := []u32{cap: count}
	for j in 0 .. count { result << word(pool, start + j * 4) }
	return result
}

pub fn category(point u32) u32 {
	return value(properties_category_data, point, 0)
}

pub fn combining_class(point u32) u32 {
	return value(properties_ccc_data, point, 0)
}

pub fn bidi_class(point u32) u32 {
	return value(properties_bidi_data, point, 0)
}

pub fn script(point u32) u32 {
	return value(properties_script_data, point, 103)
}

pub fn line_class(point u32) string {
	return line_names[int(value(properties_line_data, point, 0))]
}

pub fn word_class(point u32) string {
	return word_names[int(value(properties_word_data, point, 0))]
}

pub fn east_asian_width(point u32) string {
	return east_asian_names[int(value(properties_east_asian_data, point, 0))]
}

pub fn joining_type(point u32) string {
	return joining_names[int(value(properties_joining_data, point, 0))]
}

pub fn has_script(point u32, id u32) bool {
	data := properties_script_extensions_data
	if row(data, point, 16) < 0 { return script(point) == id }
	return id in mapping(data, properties_script_extensions_pool_data, point)
}

pub fn property_id(name string) ?u32 { return alias_id(property_aliases, name) }

pub fn category_id(name string) ?u32 { return alias_id(category_aliases, name) }

pub fn script_id(name string) ?u32 { return alias_id(script_aliases, name) }

fn alias_id(aliases [][3]string, name string) ?u32 {
	if name == '' { return none }
	for i, names in aliases { if name in names { return u32(i) } }
	return none
}

pub fn has_property(point u32, id u32) bool {
	if point > 0x10ffff { return false }
	if id == 77 { return true }
	if id == 78 { return point < 128 }
	if id == 79 { return category(point) != 0 }
	if id >= u32(property_data.len) { return false }
	return value(property_data[int(id)], point, 0) != 0
}

pub fn property_named(point u32, name string) bool {
	id := property_id(name) or { return false }
	return has_property(point, id)
}

pub fn category_mask(id u32) u32 {
	return match id {
		31 { u32(0xe) }
		32 { u32(0x3e) }
		33 { u32(0x1c0) }
		34 { u32(0xe00) }
		35 { u32(0x30f80000) }
		36 { u32(0x0f000000) }
		37 { u32(0x7000) }
		38 { u32(0x78001) }
		else {
			if id < 30 { u32(1) << id } else { u32(0) }
		}
	}
}

pub fn case_closure(point u32) []u32 {
	return mapping(properties_closure_data, properties_closure_pool_data, point)
}

pub fn simple_fold(point u32) u32 {
	return mapping(properties_fold_data, properties_fold_pool_data, point)[0]
}

pub fn property_strings(id u32) [][]u32 {
	mut result := [][]u32{}
	if id < 65 || id > 71 { return result }
	data := string_data[int(id - 65)]
	mut i := 0
	for i < data.len {
		length := int(word(data, i))
		i += 4
		mut points := []u32{cap: length}
		for _ in 0 .. length {
			points << word(data, i)
			i += 4
		}
		result << points
	}
	return result
}

pub fn decode_utf16(units []u16) []u32 {
	mut result := []u32{cap: units.len}
	mut i := 0
	for i < units.len {
		mut p := u32(units[i])
		i++
		if p >= 0xd800 && p <= 0xdbff && i < units.len && units[i] >= 0xdc00 && units[i] <= 0xdfff {
			p = 0x10000 + ((p - 0xd800) << 10) + u32(units[i]) - 0xdc00
			i++
		}
		result << p
	}
	return result
}

pub fn encode_utf16(points []u32) []u16 {
	mut units := []u16{cap: points.len}
	for p in points {
		if p <= 0xffff {
			units << u16(p)
		} else {
			units << u16(0xd800 + ((p - 0x10000) >> 10))
			units << u16(0xdc00 + ((p - 0x10000) & 0x3ff))
		}
	}
	return units
}

pub fn bracket(point u32) (u32, bool) {
	data := properties_brackets_data
	i := row(data, point, 16)
	if i < 0 { return u32(0), false }
	return word(data, i + 8), word(data, i + 12) == 1
}

pub fn case_variants() []u32 {
	data := properties_closure_data
	mut points := []u32{cap: data.len / 16}
	for i := 0; i < data.len; i += 16 { points << word(data, i) }
	return points
}

pub fn property_singletons(id u32) [][]u32 {
	mut result := [][]u32{}
	if id >= u32(property_data.len) { return result }
	data := property_data[int(id)]
	for i := 0; i < data.len; i += 12 {
		for p := word(data, i); p <= word(data, i + 4); p++ { result << [p] }
	}
	return result
}
