module browserjs

import libjs

pub struct AttributeValueReply {
pub:
	handled bool
	present bool
	value   string
}

pub type AttributeValueQuery = fn (key string, name string) !AttributeValueReply

// __ladybirdAttributeValue(key, name): an element's attribute value, null when
// it has none, or undefined when the owner asks the facade to use the
// ordinary DOM query transport. Keys and names are borrowed only for the
// synchronous callback; the value is copied into the returned string.
pub fn (mut runtime Runtime) install_attribute_value_query(callback AttributeValueQuery) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		owner := &runtime
		runtime.define_value_host_function('__ladybirdAttributeValue', fn [owner, callback] (_ voidptr, args []voidptr) !voidptr {
			undefined := C.vox_jsc_JSValueMakeUndefined(owner.context)
			if args.len != 2 || !C.JSValueIsString(owner.context, args[0])
				|| !C.JSValueIsString(owner.context, args[1]) {
				return undefined
			}
			mut key_bytes := [96]u8{}
			mut name_bytes := [256]u8{}
			key_length := owner.binding_dom_string_into(args[0], &key_bytes[0], 96)
			name_length := if key_length < 0 { -1 } else {
				owner.binding_dom_string_into(args[1], &name_bytes[0], 256)
			}
			if name_length < 0 { return undefined }
			reply := callback(unsafe { tos(&key_bytes[0], key_length) }, unsafe { tos(&name_bytes[0],
				name_length) })!
			if !reply.handled { return undefined }
			if !reply.present { return C.vox_jsc_JSValueMakeNull(owner.context) }
			return owner.dom_string_value(reply.value)
		})!
		runtime.own_closure(voidptr(callback))
	}
}

// A DOMString kept as WTF-8 (lone surrogates, NUL) as a JavaScript string.
// Plain ASCII without NUL takes the C string conversion.
fn (runtime &Runtime) dom_string_value(value string) voidptr {
	mut plain := true
	for index in 0 .. value.len {
		byte := unsafe { value.str[index] }
		if byte == 0 || byte >= 0x80 {
			plain = false
			break
		}
	}
	if plain {
		text := js_source_string(value)
		defer { C.JSStringRelease(text) }
		return C.vox_jsc_JSValueMakeString(runtime.context, text)
	}
	units := libjs.utf16_string_from_utf8_without_validation(value).code_units()
	text := C.JSStringCreateWithCharacters(units.data, uint(units.len))
	defer { C.JSStringRelease(text) }
	return C.vox_jsc_JSValueMakeString(runtime.context, text)
}

// A host function of no arguments returning a number, such as the document's
// tree version that lets the compact facade reuse navigation results.
pub fn (mut runtime Runtime) install_number_query(name string, callback fn () f64) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		owner := &runtime
		runtime.define_value_host_function(name, fn [owner, callback] (_ voidptr, _ []voidptr) !voidptr {
			return C.vox_jsc_JSValueMakeNumber(owner.context, callback())
		})!
		runtime.own_closure(voidptr(callback))
	}
}
