module css

import platform

fn calculated_type_storage_fixture() CalculatedStyleValue {
	return CalculatedStyleValue{
		serialization: 'calc(12px)'.clone()
		numeric_type_: calculated_numeric_type_storage(NumericType.with_type(.length, 1))
		node: [CalcNode(CalcNumeric{kind: .length, value: 12, unit: 'px'.clone(),
			type_: NumericType.with_type(.length, 1)})]
	}
}

fn test_calculated_numeric_metadata_keeps_value_equality_and_snapshot_mutation_independent() {
	first := calculated_type_storage_fixture()
	second := calculated_type_storage_fixture()
	assert voidptr(first.numeric_type_?) != voidptr(second.numeric_type_?)
	assert first == second
	assert StyleValue(first) == StyleValue(second)
	mut snapshot := first.numeric_type() or { panic('missing numeric type') }
	snapshot.set_exponent(.length, 7)
	assert first.numeric_type()? == NumericType.with_type(.length, 1)
	changed := CalculatedStyleValue{...first, numeric_type_: calculated_numeric_type_storage(snapshot)}
	assert first != changed
	assert StyleValue(first) != StyleValue(changed)
	missing := CalculatedStyleValue{}
	present := CalculatedStyleValue{numeric_type_: calculated_numeric_type_storage(NumericType{})}
	assert missing.numeric_type() == none
	assert present.numeric_type()? == NumericType{}
	assert missing != present
	explicit_zero := CalculatedStyleValue{
		numeric_type_: calculated_numeric_type_storage(NumericType.with_type(.length, 0))
	}
	assert present != explicit_zero
	hinted := CalculatedStyleValue{
		numeric_type_: calculated_numeric_type_storage(NumericType{percent_hint: .length})
	}
	assert present != hinted
	hinted_snapshot := hinted.numeric_type() or { panic('missing hinted type') }
	assert (hinted_snapshot.percent_hint or { panic('missing hint') }) == NumericBaseType.length
}

fn test_calculated_numeric_metadata_export_owns_its_box_after_scratch_retirement() {
	mut owner := platform.new_retained_arena('calculation metadata publication')
	mut retained := owner.enter()
	work := platform.begin_thread_scratch('calculation metadata producer')
	mut source := calculated_type_storage_fixture()
	work.leave()
	owned := export_calculated_property_value(source)
	assert voidptr(owned.numeric_type_?) != voidptr(source.numeric_type_?)
	source.numeric_type_ = none
	source.node.clear()
	work.finish()
	churn := platform.begin_thread_scratch('calculation metadata overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	gc_collect()
	assert owned.numeric_type()? == NumericType.with_type(.length, 1)
	assert owned.serialize(.normal) == 'calc(12px)'
	assert owned.resolve_raw_length(CalculationResolutionContext{})? == 12.0
	$if prealloc { assert owner.arena.contains(voidptr(owned.numeric_type_?)) }
	retained.finish()
	owner.release()
}
