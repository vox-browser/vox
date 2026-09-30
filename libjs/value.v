module libjs

// Translated from LibJS/Runtime/Value.h. Upstream NaN-boxes every value into 64
// bits; this translation keeps an explicit tag beside the payload so the VM,
// environment, and execution-context records can run before the interpreter and
// the full object model exist in V.

pub enum ValueTag as u8 {
	empty
	undefined
	null
	boolean
	int32
	double
	string
	symbol
	object
	bigint
	accessor
}

pub struct Value {
pub:
	tag    ValueTag = .undefined
	number f64
	cell   voidptr
}

pub fn js_undefined() Value {
	return Value{}
}

pub fn js_null() Value {
	return Value{
		tag: .null
	}
}

// The special empty value marks uninitialized registers and bindings. It is never
// observable from JavaScript.
pub fn js_special_empty_value() Value {
	return Value{
		tag: .empty
	}
}

pub fn Value.from_bool(value bool) Value {
	return Value{
		tag:    .boolean
		number: if value { 1.0 } else { 0.0 }
	}
}

pub fn Value.from_i32(value i32) Value {
	return Value{
		tag:    .int32
		number: f64(value)
	}
}

// Integral doubles that fit in an i32 are stored as Int32; negative zero stays a
// double so SameValue can distinguish it.
pub fn Value.from_f64(value f64) Value {
	if value >= -2147483648.0 && value <= 2147483647.0 {
		truncated := i32(value)
		if f64(truncated) == value && !(value == 0.0 && 1.0 / value < 0.0) {
			return Value{
				tag:    .int32
				number: value
			}
		}
	}
	return Value{
		tag:    .double
		number: value
	}
}

pub fn Value.from_string(text &PrimitiveString) Value {
	return Value{
		tag:  .string
		cell: voidptr(text)
	}
}

pub fn Value.from_symbol(symbol &Symbol) Value {
	return Value{
		tag:  .symbol
		cell: voidptr(symbol)
	}
}

pub fn Value.from_object(object &Object) Value {
	return Value{
		tag:  .object
		cell: voidptr(object)
	}
}

pub fn (value Value) is_special_empty_value() bool {
	return value.tag == .empty
}

pub fn (value Value) is_undefined() bool {
	return value.tag == .undefined
}

pub fn (value Value) is_null() bool {
	return value.tag == .null
}

pub fn (value Value) is_nullish() bool {
	return value.tag == .undefined || value.tag == .null
}

pub fn (value Value) is_boolean() bool {
	return value.tag == .boolean
}

pub fn (value Value) is_int32() bool {
	return value.tag == .int32
}

pub fn (value Value) is_double() bool {
	return value.tag == .double
}

pub fn (value Value) is_number() bool {
	return value.tag == .int32 || value.tag == .double
}

pub fn (value Value) is_string() bool {
	return value.tag == .string
}

pub fn (value Value) is_symbol() bool {
	return value.tag == .symbol
}

pub fn (value Value) is_object() bool {
	return value.tag == .object
}

pub fn (value Value) is_bigint() bool {
	return value.tag == .bigint
}

pub fn (value Value) is_accessor() bool {
	return value.tag == .accessor
}

pub fn (value Value) is_cell() bool {
	return value.tag in [.string, .symbol, .object, .bigint, .accessor]
}

pub fn (value Value) as_bool() bool {
	if value.tag != .boolean {
		panic('Value.as_bool() called on a ${value.tag} value')
	}
	return value.number != 0.0
}

pub fn (value Value) as_i32() i32 {
	if value.tag != .int32 {
		panic('Value.as_i32() called on a ${value.tag} value')
	}
	return i32(value.number)
}

pub fn (value Value) as_double() f64 {
	if !value.is_number() {
		panic('Value.as_double() called on a ${value.tag} value')
	}
	return value.number
}

pub fn (value Value) as_string() &PrimitiveString {
	if value.tag != .string {
		panic('Value.as_string() called on a ${value.tag} value')
	}
	return unsafe { &PrimitiveString(value.cell) }
}

pub fn (value Value) as_symbol() &Symbol {
	if value.tag != .symbol {
		panic('Value.as_symbol() called on a ${value.tag} value')
	}
	return unsafe { &Symbol(value.cell) }
}

pub fn (value Value) as_object() &Object {
	if value.tag != .object {
		panic('Value.as_object() called on a ${value.tag} value')
	}
	return unsafe { &Object(value.cell) }
}

// 7.1.2 ToBoolean ( argument ), https://tc39.es/ecma262/#sec-toboolean
pub fn (value Value) to_boolean() bool {
	return match value.tag {
		.empty, .undefined, .null { false }
		.boolean { value.number != 0.0 }
		// NaN compares unequal to itself.
		.int32, .double { value.number != 0.0 && value.number == value.number }
		.string { !value.as_string().is_empty() }
		.symbol, .object, .accessor { true }
		.bigint { panic('BigInt values are not translated yet') }
	}
}

// 7.2.10 SameValue ( x, y ), https://tc39.es/ecma262/#sec-samevalue
pub fn same_value(a Value, b Value) bool {
	if a.tag != b.tag {
		return false
	}
	match a.tag {
		.empty, .undefined, .null {
			return true
		}
		.boolean, .int32 {
			return a.number == b.number
		}
		.double {
			// Both NaN compare equal; +0 and -0 never share the double tag.
			if a.number != a.number && b.number != b.number {
				return true
			}
			return a.number == b.number
		}
		else {
			return a.cell == b.cell
		}
	}
}

pub fn (value Value) str() string {
	return match value.tag {
		.empty { '<empty>' }
		.undefined { 'undefined' }
		.null { 'null' }
		.boolean { if value.number != 0.0 { 'true' } else { 'false' } }
		.int32 { i32(value.number).str() }
		.double { format_f64_value(value.number) }
		.string { '"${value.as_string().str()}"' }
		.symbol { value.as_symbol().descriptive_string().str() }
		.object { '[object ${value.as_object().class_name}]' }
		.bigint { '<bigint>' }
		.accessor { '<accessor>' }
	}
}
