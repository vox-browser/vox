module libjs

// AK::Utf16String::replace and Utf16View::replace, specialized to CreateHTML's
// one-unit quotation-mark needle and ReplaceMode::All.
fn replace_string_html_quotes(text Utf16String) Utf16String {
	if text.is_empty() || u16(0x0022) !in text.data { return text }
	needle := Utf16String.from_slice([u16(0x0022)])
	mut units := []u16{}
	mut remaining := uint(0)
	for {
		index := string_index_of(text, needle, remaining) or { break }
		units << text.data[int(remaining)..int(index)]
		units << utf16('&quot;')
		remaining = index + 1
		if remaining == uint(text.len()) { break
		 }
	}
	units << text.data[int(remaining)..]
	return Utf16String{
		data: units
	}
}

// Runtime/StringPrototype.cpp::create_html (Annex B CreateHTML). Tag and
// attribute are the source's ASCII constants; only attribute quotes are escaped.
fn string_create_html(mut vm VM, receiver Value, tag string, attribute string, value Value) !Value {
	require_object_coercible(mut vm, receiver)!
	text := receiver.to_primitive_string(mut vm)!.utf16
	mut units := utf16('<')
	units << utf16(tag)
	if attribute.len != 0 {
		value_string := value.to_primitive_string(mut vm)!.utf16
		escaped := replace_string_html_quotes(value_string)
		units << utf16(' ')
		units << utf16(attribute)
		units << utf16('="')
		units << escaped.data
		units << u16(0x0022)
	}
	units << u16(0x003e)
	units << text.data
	units << utf16('</')
	units << utf16(tag)
	units << u16(0x003e)
	return Value.from_string(vm.create_string(Utf16String{ data: units }))
}

pub fn string_prototype_anchor(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'a', 'name', vm.argument(0))
}

pub fn string_prototype_big(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'big', '', js_undefined())
}

pub fn string_prototype_blink(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'blink', '', js_undefined())
}

pub fn string_prototype_bold(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'b', '', js_undefined())
}

pub fn string_prototype_fixed(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'tt', '', js_undefined())
}

pub fn string_prototype_fontcolor(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'font', 'color', vm.argument(0))
}

pub fn string_prototype_fontsize(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'font', 'size', vm.argument(0))
}

pub fn string_prototype_italics(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'i', '', js_undefined())
}

pub fn string_prototype_link(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'a', 'href', vm.argument(0))
}

pub fn string_prototype_small(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'small', '', js_undefined())
}

pub fn string_prototype_strike(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'strike', '', js_undefined())
}

pub fn string_prototype_sub(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'sub', '', js_undefined())
}

pub fn string_prototype_sup(mut vm VM) !Value {
	return string_create_html(mut vm, vm.this_value(), 'sup', '', js_undefined())
}
