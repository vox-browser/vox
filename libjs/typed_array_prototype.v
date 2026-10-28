module libjs

// Runtime/TypedArrayPrototype.{h,cpp} initialization. All method bodies are
// installed in source order. Remaining realm intrinsics are explicit inputs;
// this record is not a substitute for the complete concrete builtin graph.
pub struct TypedArrayPrototypeDependencies {
pub:
	primitives         PrimitiveObjectPrototypes
	@[required]
	constructor_getter TypedArrayIntrinsicConstructorGetter
	@[required]
	prototype_getter   TypedArrayIntrinsicPrototypeGetter
	iterator_prototype &Object
	array_prototype    &Object
}

@[heap]
pub struct TypedArrayPrototype {
pub:
	object &Object
}

pub fn TypedArrayPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object, dependencies TypedArrayPrototypeDependencies) &TypedArrayPrototype {
	mut object := Object.create(realm, object_prototype)
	attributes := attribute_writable | attribute_configurable
	for name in ['buffer', 'byteLength', 'byteOffset', 'length'] {
		object.define_native_accessor(mut vm, realm, PropertyName.from_str(name), fn [name, dependencies] (mut vm VM) !Value {
			return match name {
				'buffer' { typed_array_prototype_buffer_getter(mut vm, dependencies.primitives)! }
				'byteLength' { typed_array_prototype_byte_length_getter(mut vm,
						dependencies.primitives)! }
				'byteOffset' { typed_array_prototype_byte_offset_getter(mut vm,
						dependencies.primitives)! }
				else { typed_array_prototype_length_getter(mut vm, dependencies.primitives)! }
			}
		}, unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	for name in ['at', 'copyWithin', 'entries', 'every', 'fill', 'filter', 'find', 'findIndex',
		'findLast', 'findLastIndex', 'forEach', 'includes', 'indexOf', 'join', 'keys', 'lastIndexOf',
		'map', 'reduce', 'reduceRight', 'reverse', 'set', 'slice', 'some', 'sort', 'subarray',
		'toLocaleString', 'toReversed', 'toSorted', 'with', 'values'] {
		length := match name {
			'copyWithin', 'slice', 'subarray', 'with' { 2.0 }
			'entries', 'keys', 'reverse', 'toLocaleString', 'toReversed', 'values' { 0.0 }
			else { 1.0 }
		}

		function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, dependencies] (mut vm VM) !Value {
			return match name {
				'at' { typed_array_prototype_at(mut vm, dependencies.primitives)! }
				'copyWithin' { typed_array_prototype_copy_within(mut vm, dependencies.primitives)! }
				'entries' { typed_array_prototype_entries(mut vm, dependencies.primitives,
						dependencies.iterator_prototype)! }
				'every' { typed_array_prototype_every(mut vm, dependencies.primitives)! }
				'fill' { typed_array_prototype_fill(mut vm, dependencies.primitives)! }
				'filter' { typed_array_prototype_filter(mut vm, dependencies.primitives,
						dependencies.constructor_getter, dependencies.prototype_getter)! }
				'find' { typed_array_prototype_find(mut vm, dependencies.primitives)! }
				'findIndex' { typed_array_prototype_find_index(mut vm, dependencies.primitives)! }
				'findLast' { typed_array_prototype_find_last(mut vm, dependencies.primitives)! }
				'findLastIndex' { typed_array_prototype_find_last_index(mut vm,
						dependencies.primitives)! }
				'forEach' { typed_array_prototype_for_each(mut vm, dependencies.primitives)! }
				'includes' { typed_array_prototype_includes(mut vm, dependencies.primitives)! }
				'indexOf' { typed_array_prototype_index_of(mut vm, dependencies.primitives)! }
				'join' { typed_array_prototype_join(mut vm, dependencies.primitives)! }
				'keys' { typed_array_prototype_keys(mut vm, dependencies.primitives,
						dependencies.iterator_prototype)! }
				'lastIndexOf' { typed_array_prototype_last_index_of(mut vm, dependencies.primitives)! }
				'map' { typed_array_prototype_map(mut vm, dependencies.primitives,
						dependencies.constructor_getter, dependencies.prototype_getter)! }
				'reduce' { typed_array_prototype_reduce(mut vm, dependencies.primitives)! }
				'reduceRight' { typed_array_prototype_reduce_right(mut vm, dependencies.primitives)! }
				'reverse' { typed_array_prototype_reverse(mut vm, dependencies.primitives)! }
				'set' { typed_array_prototype_set(mut vm, dependencies.primitives)! }
				'slice' { typed_array_prototype_slice(mut vm, dependencies.primitives,
						dependencies.constructor_getter, dependencies.prototype_getter)! }
				'some' { typed_array_prototype_some(mut vm, dependencies.primitives)! }
				'sort' { typed_array_prototype_sort(mut vm, dependencies.primitives)! }
				'subarray' { typed_array_prototype_subarray(mut vm, dependencies.primitives,
						dependencies.constructor_getter, dependencies.prototype_getter)! }
				'toLocaleString' { typed_array_prototype_to_locale_string(mut vm,
						dependencies.primitives)! }
				'toReversed' { typed_array_prototype_to_reversed(mut vm, dependencies.primitives,
						dependencies.constructor_getter)! }
				'toSorted' { typed_array_prototype_to_sorted(mut vm, dependencies.primitives,
						dependencies.constructor_getter)! }
				'with' { typed_array_prototype_with(mut vm, dependencies.primitives,
						dependencies.constructor_getter)! }
				else { typed_array_prototype_values(mut vm, dependencies.primitives,
						dependencies.iterator_prototype)! }
			}
		}, length, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attributes)
	}
	object.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		typed_array_prototype_to_string_tag_getter, unsafe { nil }, attribute_configurable,
		realm.function_prototype)
	object.define_direct_property(PropertyName.from_str('toString'),
		dependencies.array_prototype.get_without_side_effects(PropertyName.from_str('toString')),
		attributes)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		object.get_without_side_effects(PropertyName.from_str('values')), attributes)
	return &TypedArrayPrototype{
		object: object
	}
}
