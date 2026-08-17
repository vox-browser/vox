module webidl

fn double_number(value Value) !Value {
	return number_value(value.number_value * 2)
}

fn reject_step(value Value) !Value {
	return error('callback rejected ${value.string_value}')
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
}

fn test_async_iterator_next_return_and_throw() {
	mut iterator := AsyncIterator.create([string_value('a'), string_value('b')], .key_value)
	first := iterator.next()
	assert first.is_fulfilled()
	assert first.result.object_value['done'].boolean_value == false
	pair := first.result.object_value['value'].sequence_value
	assert pair[0].number_value == 0
	assert pair[1].string_value == 'a'
	returned := iterator.return_(string_value('stop'))
	assert returned.result.object_value['done'].boolean_value
	assert iterator.next().result.object_value['done'].boolean_value
	mut throwing := AsyncIterator.create([]Value{}, .value)
	assert throwing.throw_(string_value('boom')).is_rejected()
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
