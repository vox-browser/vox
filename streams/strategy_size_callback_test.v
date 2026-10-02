module streams

import webidl

@[heap]
struct StrategySizeGlobalFixture {
mut:
	count &webidl.CallbackType
	bytes &webidl.CallbackType
	reads []bool
}

fn (mut scope StrategySizeGlobalFixture) count_queuing_strategy_size_callback() !&webidl.CallbackType {
	scope.reads << false
	return scope.count
}

fn (mut scope StrategySizeGlobalFixture) byte_length_queuing_strategy_size_callback() !&webidl.CallbackType {
	scope.reads << true
	return scope.bytes
}

fn test_strategy_source_getters_return_relevant_global_callback_identity_without_invoking_it() {
	count := &webidl.CallbackType{callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value {
		assert false
		return error('getter must not invoke size')
	}}
	bytes := &webidl.CallbackType{callback: fn (_ webidl.Value, _ []webidl.Value) !webidl.Value {
		assert false
		return error('getter must not invoke size')
	}}
	mut global := &StrategySizeGlobalFixture{count: count, bytes: bytes}
	first := CountQueuingStrategy.create_for_constructor(QueuingStrategyInit{high_water_mark: -3})
	second := CountQueuingStrategy.create_for_constructor(QueuingStrategyInit{high_water_mark: 7})
	byte_strategy := ByteLengthQueuingStrategy.create_for_constructor(QueuingStrategyInit{high_water_mark: 0})
	assert voidptr(first.size_callback(mut global)!) == voidptr(count)
	assert voidptr(second.size_callback(mut global)!) == voidptr(count)
	assert voidptr(byte_strategy.size_callback(mut global)!) == voidptr(bytes)
	assert global.reads == [false, false, true]
	assert first.high_water_mark() == -3
}
