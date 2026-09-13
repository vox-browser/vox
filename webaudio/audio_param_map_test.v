module webaudio

fn test_audio_param_map_preserves_insertion_order_and_replaces_values() {
	graph := &AudioGraphState{}
	mut gain := new_audio_param(1, 1, graph, 1, 0, 2, .a_rate, false)
	mut frequency := new_audio_param(2, 1, graph, 440, 0, 20_000, .a_rate, false)
	mut replacement := new_audio_param(3, 1, graph, 0.5, 0, 2, .a_rate, false)
	mut parameter_map := AudioParamMap.create()
	parameter_map.set_entry('gain', &gain)
	parameter_map.set_entry('frequency', &frequency)
	parameter_map.set_entry('gain', &replacement)

	assert parameter_map.size() == 2
	assert parameter_map.keys() == ['gain', 'frequency']
	assert parameter_map.values().map(it.id) == [u64(3), 2]
	assert parameter_map.entries().map(it.key) == ['gain', 'frequency']
	assert (parameter_map.get('gain') or { panic('missing gain') }).id == 3
	assert parameter_map.get('missing') == none
}

fn test_audio_param_map_binding_helpers_are_read_only_views() {
	graph := &AudioGraphState{}
	mut parameter := new_audio_param(7, 1, graph, 1, 0, 2, .a_rate, false)
	mut parameter_map := AudioParamMap.create()
	parameter_map.set_entry('gain', &parameter)

	assert map_has(parameter_map, 'gain')
	assert !map_has(parameter_map, 'missing')
	assert (map_get(parameter_map, 'gain') or { panic('missing gain') }).id == 7
	assert map_get(parameter_map, 'missing') == none
	assert map_entries(parameter_map)[0].value.id == 7

	mut detached_entries := map_entries(parameter_map)
	detached_entries.clear()
	assert parameter_map.size() == 1
}
