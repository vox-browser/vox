module libjs

// Translated from LibJS/Runtime/PrimitiveString.{h,cpp}: the string cell and the
// VM-owned creation caches. Rope and substring representations are not translated;
// every string stores its UTF-16 code units directly.

@[heap]
pub struct PrimitiveString {
pub:
	utf16 Utf16String
}

pub fn (primitive &PrimitiveString) is_empty() bool {
	return primitive.utf16.is_empty()
}

pub fn (primitive &PrimitiveString) utf16_string() Utf16String {
	return primitive.utf16
}

pub fn (primitive &PrimitiveString) length_in_utf16_code_units() int {
	return primitive.utf16.len()
}

pub fn (primitive &PrimitiveString) str() string {
	return primitive.utf16.str()
}

// Runtime/PrimitiveString.cpp::get. Its IgnoreNumericRoundtrip mode accepts
// only PropertyKey's canonical index representation for virtual characters.
pub fn (primitive &PrimitiveString) get_own_property(mut vm VM, key PropertyName) ?Value {
	if key.is_symbol() { return none }
	if key.is_string() && key.as_string() == utf16_string('length') {
		return Value.from_f64(f64(primitive.utf16.len()))
	}
	if !key.is_number() || u64(key.number) >= u64(primitive.utf16.len()) { return none }
	return Value.from_string(vm.create_string(Utf16String{
		data: [primitive.utf16.data[int(key.number)]]
	}))
}

pub const fly_string_cache_size = 1024
pub const numeric_string_cache_size = 1000
pub const large_numeric_string_cache_size = 1024
pub const string_to_atom_cache_size = 2

// Utf16String::has_short_ascii_storage() covers inline ASCII strings upstream.
const short_ascii_storage_limit = 16

pub fn utf16_string(text string) Utf16String {
	return Utf16String.from_slice(utf16(text))
}

fn has_short_ascii_storage(text Utf16String) bool {
	if text.len() > short_ascii_storage_limit {
		return false
	}
	for code_unit in text.as_slice() {
		if code_unit >= 0x80 {
			return false
		}
	}
	return true
}

// Upstream hashes the fly string identity; content hashing gives the same cache
// behavior for equal strings.
fn fly_string_cache_hash(text Utf16String) u32 {
	mut hash := u32(2166136261)
	for code_unit in text.as_slice() {
		hash ^= u32(code_unit & 0xFF)
		hash *= 16777619
		hash ^= u32(code_unit >> 8)
		hash *= 16777619
	}
	return hash
}

// PrimitiveString::create(VM&, Utf16String const&)
pub fn (mut vm VM) create_string(text Utf16String) &PrimitiveString {
	if text.is_empty() {
		return vm.empty_string()
	}
	if text.len() == 1 {
		code_unit := text.as_slice()[0]
		if code_unit < 0x80 {
			return vm.single_ascii_character_string(u8(code_unit))
		}
	}
	if has_short_ascii_storage(text) {
		return vm.create_fly_string(text)
	}
	return &PrimitiveString{
		utf16: text.clone()
	}
}

pub fn (mut vm VM) create_string_from_str(text string) &PrimitiveString {
	return vm.create_string(utf16_string(text))
}

// PrimitiveString::create(VM&, Utf16FlyString const&)
pub fn (mut vm VM) create_fly_string(text Utf16String) &PrimitiveString {
	if text.is_empty() {
		return vm.empty_string()
	}
	if text.len() == 1 {
		code_unit := text.as_slice()[0]
		if code_unit < 0x80 {
			return vm.single_ascii_character_string(u8(code_unit))
		}
	}
	cache_index := int(fly_string_cache_hash(text) & u32(fly_string_cache_size - 1))
	if cached := vm.fly_string_cache[cache_index] {
		if cached.utf16 == text {
			return cached
		}
	}
	new_string := &PrimitiveString{
		utf16: text.clone()
	}
	vm.fly_string_cache[cache_index] = new_string
	return new_string
}

// PrimitiveString::create_from_unsigned_integer(VM&, u64)
pub fn (mut vm VM) create_string_from_unsigned_integer(number u64) &PrimitiveString {
	if number < u64(numeric_string_cache_size) {
		if cached := vm.numeric_string_cache[int(number)] {
			return cached
		}
		new_string := vm.create_fly_string(utf16_string(number.str()))
		vm.numeric_string_cache[int(number)] = new_string
		return new_string
	}
	cache_index := int(number & u64(large_numeric_string_cache_size - 1))
	entry := vm.large_numeric_string_cache[cache_index]
	if cached := entry.string {
		if entry.number == number {
			return cached
		}
	}
	new_string := vm.create_fly_string(utf16_string(number.str()))
	vm.large_numeric_string_cache[cache_index] = NumericStringCacheEntry{
		number: number
		string: new_string
	}
	return new_string
}
