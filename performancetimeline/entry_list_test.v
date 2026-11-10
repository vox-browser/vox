module performancetimeline

fn test_entry_list_filters_and_sorts_chronologically() {
	a := PerformanceEntry.new('same', 'mark', 20, 1)
	b := PerformanceEntry.new('other', 'resource', 10, 2)
	c := PerformanceEntry.new('same', 'mark', 5, 3)
	list := PerformanceObserverEntryList.new([a, b, c])
	entries := list.get_entries()
	assert entries.map(it.start_time) == [f64(5), 10, 20]
	assert list.get_entries_by_type('mark').map(it.name) == ['same', 'same']
	assert list.get_entries_by_name('same', 'mark').map(it.start_time) == [f64(5), 20]
	assert list.get_entries_by_name('same', none).len == 2
}

fn test_entry_list_create_factory_owns_its_entry_vector() {
	a := PerformanceEntry.new('first', 'mark', 1, 0)
	mut entries := [a]
	list := PerformanceObserverEntryList.create(entries)
	entries.clear()
	assert list.get_entries().map(it.name) == ['first']
}

fn test_performance_entry_json_and_registry_names() {
	entry := PerformanceEntry.new('load', 'resource', 2.5, 4.5)
	json := entry.to_json()
	assert json.name == 'load'
	assert json.entry_type == 'resource'
	assert json.start_time == 2.5
	assert json.duration == 4.5
	assert entry_types.len == 12
	assert supported_entry_types == ['mark', 'measure', 'resource']
	assert supported_entry_types_for_global(true) == ['mark', 'measure', 'resource', 'visibility-state']
	assert supported_entry_types_for_global(false) == supported_entry_types
	assert 'resourcetimingbufferfull' in event_names
}
