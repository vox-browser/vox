module webidl

fn double_number(value Value) !Value {
	return number_value(value.number_value * 2)
}

fn reject_step(value Value) !Value {
	return error('callback rejected ${value.string_value}')
}

fn promise_callback(_ Value, arguments []Value) !Value {
	if arguments.len == 0 {
		return error('missing argument')
	}
	return arguments[0]
}

fn test_promise_settlement_reactions_and_handled_flag() {
	mut source := create_promise()
	mut child := source.upon_fulfillment(double_number)
	assert child.state == .pending
	source.resolve(number_value(21))
	assert source.is_fulfilled()
	assert child.is_fulfilled()
	assert child.result.number_value == 42
	source.reject(string_value('ignored'))
	assert source.result.number_value == 21
	mut rejected := create_rejected_promise(string_value('reason'))
	mut failed_child := rejected.upon_rejection(reject_step)
	assert failed_child.is_rejected()
	assert failed_child.result.string_value.contains('callback rejected')
	rejected.mark_as_handled()
	assert rejected.is_handled
	assert rejected.rejection_was_handled_after_settlement
}

fn test_relevant_context_promise_helpers_preserve_realm() {
	context := PromiseContext{
		realm_id: 42
	}
	mut pending := create_promise_for(context)
	assert promise_realm(pending) == 42
	resolve_promise(mut pending, number_value(7))
	assert pending.is_fulfilled()
	assert pending.result.number_value == 7

	resolved := create_resolved_promise_for(context, string_value('ready'))
	assert promise_realm(resolved) == 42
	assert resolved.result.string_value == 'ready'
	mut rejected := create_rejected_promise_for(context, string_value('reason'))
	assert promise_realm(rejected) == 42
	assert rejected.is_rejected()
	reject_promise(mut rejected, string_value('ignored'))
	assert rejected.result.string_value == 'reason'
}

fn test_reject_promise_with_exception_helpers() {
	context := PromiseContext{
		realm_id: 9
	}
	exception := SimpleException{
		type_: .type_error
		message: 'bad input'
	}
	rejected := create_rejected_promise_from_exception_for(context, exception)
	assert promise_realm(rejected) == 9
	assert rejected.is_rejected()
	assert rejected.result.string_value == 'bad input'

	mut pending := create_promise_for(context)
	reject_promise_with_exception(mut pending, exception)
	assert pending.is_rejected()
	assert pending.result.string_value == 'bad input'
}

fn test_async_iterator_next_return_and_throw() {
	mut iterator := AsyncIterator.create_in_realm([string_value('a'), string_value('b')], .key_value, 77)
	assert iterator.promise_realm() == 77
	first := iterator.next()
	assert promise_realm(first) == 77
	assert first.is_fulfilled()
	assert first.result.object_value['done'].boolean_value == false
	pair := first.result.object_value['value'].sequence_value
	assert pair[0].number_value == 0
	assert pair[1].string_value == 'a'
	returned := iterator.return_(string_value('stop'))
	assert promise_realm(returned) == 77
	assert returned.result.object_value['done'].boolean_value
	assert iterator.next().result.object_value['done'].boolean_value
	mut throwing := AsyncIterator.create_in_realm([]Value{}, .value, 88)
	thrown := throwing.throw_(string_value('boom'))
	assert thrown.is_rejected()
	assert promise_realm(thrown) == 88
}

fn test_async_iterator_and_promise_named_algorithm_entries() {
	mut iterator := AsyncIterator.create([string_value('value')], .value)
	assert iterator.iterator_next_impl().result.object_value['value'].string_value == 'value'
	assert iterator.iterator_return_impl(string_value('done')).result.object_value['done'].boolean_value
	assert iterator.iterator_return(string_value('again')).is_fulfilled()
	callback := CallbackType{
		callback: promise_callback
		operation_returns_promise: .yes
	}
	assert invoke_callback_impl(callback, none, [number_value(3)])!.number_value == 3
	assert invoke_promise_callback(callback, none, []Value{}).is_rejected()
	mut source := create_resolved_promise(number_value(2))
	mut child := react_to_promise(mut source, double_number, double_number)
	assert child.result.number_value == 4
	mark_promise_as_handled(mut source)
	assert source.is_handled
	assert is_promise_fulfilled(source)
	rejected := create_rejected_promise_from_exception(SimpleException{
		type_: .type_error
		message: 'failure'
	})
	assert rejected.is_rejected()
	conversion := property_to_callback(object_value({
		'run': callback_value()
	}), 'run', .no)!
	assert conversion.callback != none
}

fn test_cached_attribute_first_value_wins_until_clear() {
	mut attribute := CachedAttribute{}
	assert attribute.get_or_set(string_value('first')).string_value == 'first'
	assert attribute.get_or_set(string_value('second')).string_value == 'first'
	attribute.clear()
	assert attribute.get_or_set(string_value('third')).string_value == 'third'
}

fn test_wait_for_all_observes_pending_promises_in_input_order() {
	mut first := create_promise()
	mut second := create_promise()
	mut combined := get_promise_for_wait_for_all([first, second])
	assert combined.state == .pending
	second.resolve(string_value('second'))
	assert combined.state == .pending
	first.resolve(string_value('first'))
	assert combined.is_fulfilled()
	assert combined.result.sequence_value[0].string_value == 'first'
	assert combined.result.sequence_value[1].string_value == 'second'
}

fn test_wait_for_all_rejects_once_and_empty_input_resolves() {
	mut first := create_promise()
	mut second := create_promise()
	mut combined := get_promise_for_wait_for_all([first, second])
	second.reject(string_value('failure'))
	first.resolve(string_value('ignored'))
	assert combined.is_rejected()
	assert combined.result.string_value == 'failure'
	empty := get_promise_for_wait_for_all([]&Promise{})
	assert empty.is_fulfilled()
	assert empty.result.sequence_value.len == 0
}
