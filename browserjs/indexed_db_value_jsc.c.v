module browserjs

import dom
import html
import indexeddb
import libjs

// IndexedDB's current typed storage representation supports finite value
// trees. Unsupported clone records fail explicitly rather than being stored
// as JSON or losing their native types.
fn (mut runtime Runtime) indexed_db_input(value voidptr) !indexeddb.Value {
	binding := indexed_db_bindings_[voidptr(&runtime)] or { return error('Missing IndexedDB binding') }
	mut projection := NativeCloneProjection{ bridge: binding.clone }
	defer { projection.release_roots() }
	actual := projection.project(value)!
	mut seen := map[voidptr]bool{}
	return indexed_db_value_from_projection(*actual, mut seen)
}

fn indexed_db_value_from_projection(value dom.JSValue, mut seen map[voidptr]bool) !indexeddb.Value {
	match value.kind {
		.undefined { return indexeddb.undefined_value() }
		.null_ { return indexeddb.null_value() }
		.boolean { return indexeddb.bool_value(value.boolean_data) }
		.number { return indexeddb.number_value(value.number_data) }
		.string {
			return indexeddb.string_value(if units := value.string_utf16_ {
				units.str()
			} else {
				value.string_data
			})
		}
		else {}
	}
	if value.kind != .object {
		return error('DataCloneError: IndexedDB cannot yet store this primitive type')
	}
	object := html.structured_object_from_value(value)!
	identity := voidptr(object)
	if identity in seen {
		return error('DataCloneError: IndexedDB cannot yet store shared or cyclic object records')
	}
	seen[identity] = true
	match object.kind {
		.date { return indexeddb.date_value(object.number_data) }
		.array_buffer { return indexeddb.binary_value(object.bytes) }
		.array {
			length := int(object.array_length or { u32(0) })
			if object.properties.len != length {
				return error('DataCloneError: IndexedDB cannot yet store sparse arrays')
			}
			mut items := []indexeddb.Value{len: length}
			for property in object.properties {
				index := property.key.int()
				if index < 0 || index >= length || index.str() != property.key {
					return error('DataCloneError: IndexedDB cannot yet store array named properties')
				}
				items[index] = indexed_db_value_from_projection(*property.value, mut seen)!
			}
			return indexeddb.array_value(items)
		}
		.object {
			mut fields := map[string]indexeddb.Value{}
			for property in object.properties {
				fields[property.key] = indexed_db_value_from_projection(*property.value, mut seen)!
			}
			return indexeddb.object_value(fields)
		}
		else { return error('DataCloneError: IndexedDB cannot yet store this object type') }
	}
}

fn (mut runtime Runtime) indexed_db_output(value indexeddb.Value) !voidptr {
	binding := indexed_db_bindings_[voidptr(&runtime)] or { return error('Missing IndexedDB binding') }
	mut projection := NativeCloneProjection{ bridge: binding.clone }
	defer { projection.release_roots() }
	result := projection.reconstruct(indexed_db_value_to_projection(value)!)!
	// The projection releases its temporary roots on return; keep the actual
	// value rooted through the enclosing native callback's return boundary.
	return runtime.retain_javascript_value(result)
}

fn indexed_db_value_to_projection(value indexeddb.Value) !dom.JSValue {
	match value.kind {
		.undefined { return dom.js_undefined() }
		.null_ { return dom.js_null() }
		.boolean { return dom.js_bool(value.bool_) }
		.number { return dom.js_number(value.number) }
		.string_ { return dom.js_utf16_string(libjs.utf16_string_from_utf8_without_validation(value.text)) }
		else {}
	}
	mut object := html.StructuredObject.create(match value.kind {
		.array { .array }
		.binary { .array_buffer }
		.date { .date }
		else { .object }
	})
	match value.kind {
		.date { object.number_data = value.number }
		.binary { object.bytes = value.bytes.clone() }
		.array {
			object.array_length = u32(value.items.len)
			for index, item in value.items {
				actual := indexed_db_value_to_projection(item)!
				object.properties << html.StructuredProperty{ key: index.str(), value: &actual }
			}
		}
		.object {
			for name, item in value.fields {
				actual := indexed_db_value_to_projection(item)!
				object.properties << html.StructuredProperty{ key: name, value: &actual }
			}
		}
		else { return error('DataCloneError: unsupported IndexedDB stored value') }
	}
	return html.structured_object_value(object)
}
