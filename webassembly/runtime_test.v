module webassembly

import webidl

fn test_global_value_types_defaults_mutability_and_conversion() {
	mut global := Global.construct(GlobalDescriptor{ value: .i32, mutable_: true },
		webidl.number_value(4))!
	assert global.value()!.number_value == 4
	global.set_value(webidl.number_value(7.9))!
	assert global.value_of()!.number_value == 7
	mut constant := Global.construct(GlobalDescriptor{ value: .f64 }, none)!
	assert constant.value()!.number_value == 0
	if _ := constant.set_value(webidl.number_value(1)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := Global.construct(GlobalDescriptor{ value: .v128 }, none) {
		assert false
	} else {
		assert err.msg().contains('V128')
	}
}

fn test_i64_uses_bigint_and_externref_defaults_to_undefined() {
	global := Global.construct(GlobalDescriptor{ value: .i64 }, webidl.bigint_value(-42))!
	assert global.value()!.kind == .bigint
	assert global.value()!.bigint_value == -42
	if _ := Global.construct(GlobalDescriptor{ value: .i64 }, webidl.number_value(42)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	extern_global := Global.construct(GlobalDescriptor{ value: .externref }, none)!
	assert extern_global.value()!.kind == .undefined
	extern_table := Table.construct(TableDescriptor{ element: .externref, initial: 1 }, none)!
	assert extern_table.get(0)!.kind == .undefined
}

fn test_table_bounds_grow_and_anyfunc_validation() {
	mut table := Table.construct(TableDescriptor{ element: .externref, initial: 2, maximum: 3 },
		webidl.string_value('x'))!
	assert table.length() == 2
	assert table.get(1)!.string_value == 'x'
	table.set(0, webidl.number_value(9))!
	assert table.get(0)!.number_value == 9
	assert table.grow(1, webidl.null_value())! == 2
	if _ := table.grow(1, none) {
		assert false
	} else {
		assert err.msg().starts_with('RangeError:')
	}
	if _ := Table.construct(TableDescriptor{ element: .anyfunc, initial: 1 },
		webidl.string_value('not callable'))
	{
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}
