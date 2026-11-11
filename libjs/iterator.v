module libjs

// Runtime/Iterator.{h,cpp}: synchronous iterator records, stepping, closing,
// and collection. Async iterators and Iterator helpers are separate slices.
@[heap]
pub struct IteratorRecord {
pub:
	iterator    &Object
	next_method Value
pub mut:
	done bool
}

// IteratorStep only checks completion. Its value is an undefined sentinel;
// IteratorStepValue requests and consumes the value getter's completion.
pub struct IterationResult {
pub:
	done  Value
	value Completion
}

// These records represent IterationResultOrDone and Optional<Value> without
// conflating a yielded undefined with exhaustion.
pub struct IteratorStep {
pub:
	done   bool
	result IterationResult
}

pub struct IteratorStepValue {
pub:
	done  bool
	value Value
}

pub fn get_iterator_direct(mut vm VM, object &Object) !&IteratorRecord {
	next_method := object.get(mut vm, PropertyName.from_str('next'))!
	return &IteratorRecord{iterator: object, next_method: next_method}
}

pub fn get_iterator_from_method(mut vm VM, value Value, method Value) !&IteratorRecord {
	iterator := call(mut vm, method, value, []Value{})!
	if !iterator.is_object() { return vm.throw_error_type(.type_error, .not_iterable, value.str()) }
	return get_iterator_direct(mut vm, iterator.as_object())
}

// The object-receiver synchronous branch of GetIterator. Primitive String's
// @@iterator lookup depends on the not-yet-translated String prototype.
pub fn get_iterator_sync(mut vm VM, object &Object) !&IteratorRecord {
	method := object.get_method(mut vm, PropertyName.from_symbol(vm.well_known_symbol_iterator()))!
	if method.is_undefined() {
		return vm.throw_error_type(.type_error, .not_iterable, Value.from_object(object).str())
	}
	return get_iterator_from_method(mut vm, Value.from_object(object), method)
}

pub fn iterator_next(mut vm VM, mut record IteratorRecord, value ?Value) !&Object {
	call_arguments := if supplied := value { [supplied] } else { []Value{} }
	result := call(mut vm, record.next_method, Value.from_object(record.iterator), call_arguments) or {
		record.done = true
		return err
	}
	if !result.is_object() {
		record.done = true
		return vm.throw_error_type(.type_error, .iterable_next_bad_return)
	}
	return result.as_object()
}

pub fn iterator_complete(mut vm VM, result &Object) !bool {
	return result.get(mut vm, PropertyName.from_str('done'))!.to_boolean()
}

pub fn iterator_value(mut vm VM, result &Object) !Value {
	return result.get(mut vm, PropertyName.from_str('value'))
}

pub fn iterator_step(mut vm VM, mut record IteratorRecord) !IteratorStep {
	return iterator_step_impl(mut vm, mut record, false)
}

fn iterator_step_impl(mut vm VM, mut record IteratorRecord, with_value bool) !IteratorStep {
	// Builtin marker fast paths are pending; this is the source's ordinary path.
	result := iterator_next(mut vm, mut record, none)!
	done := result.get(mut vm, PropertyName.from_str('done')) or {
		record.done = true
		return err
	}
	if done.to_boolean() {
		record.done = true
		return IteratorStep{done: true}
	}
	value := if !with_value {
		normal_completion(js_undefined())
	} else if yielded := iterator_value(mut vm, result) {
		normal_completion(yielded)
	} else {
		completion_from_error(err)
	}
	return IteratorStep{result: IterationResult{done: done, value: value}}
}

pub fn iterator_step_value(mut vm VM, mut record IteratorRecord) !IteratorStepValue {
	step := iterator_step_impl(mut vm, mut record, true)!
	if step.done { return IteratorStepValue{done: true, value: js_undefined()} }
	if step.result.value.is_error() {
		record.done = true
		return step.result.value.release_error()
	}
	return IteratorStepValue{value: step.result.value.value}
}

pub fn iterator_close(mut vm VM, record &IteratorRecord, completion Completion) Completion {
	method := record.iterator.get_method(mut vm, PropertyName.from_str('return')) or {
		if completion.is_error() { return completion }
		return completion_from_error(err)
	}
	if method.is_undefined() { return completion }
	inner := if value := call(mut vm, method, Value.from_object(record.iterator), []Value{}) {
		normal_completion(value)
	} else {
		completion_from_error(err)
	}
	if completion.is_error() { return completion }
	if inner.is_error() { return inner }
	if !inner.value.is_object() {
		return completion_from_error(vm.throw_error_type(.type_error, .iterable_return_bad_return))
	}
	return completion
}

pub fn iterator_close_all(mut vm VM, records []&IteratorRecord, completion Completion) Completion {
	mut result := completion
	for index := records.len; index > 0; index-- {
		result = iterator_close(mut vm, records[index - 1], result)
	}
	return result
}

// CreateIteratorResultObject's prototype is supplied explicitly until the
// Object intrinsic graph is translated. Premade shapes use ordinary storage.
pub fn create_iterator_result_object(realm &Realm, value Value, done bool, prototype ?&Object) &Object {
	mut object := Object.create(realm, prototype)
	attributes := attribute_writable | attribute_enumerable | attribute_configurable
	object.define_direct_property(PropertyName.from_str('value'), value, attributes)
	object.define_direct_property(PropertyName.from_str('done'), Value.from_bool(done), attributes)
	return object
}

pub fn iterator_to_list(mut vm VM, mut record IteratorRecord) ![]Value {
	mut values := []Value{}
	for {
		next := iterator_step_value(mut vm, mut record)!
		if next.done { return values }
		values << next.value
	}
	return values
}
