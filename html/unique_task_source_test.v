module html

import platform

fn test_unique_task_source_registry_outlives_its_callers_allocation_arena() {
	mut sources := []UniqueTaskSource{cap: 256}
	mut storage := platform.new_retained_arena('task source registry caller')
	mut scope := storage.enter()
	// Grow the shared map while the caller's temporary owner is entered.
	for _ in 0 .. 256 {
		sources << UniqueTaskSource.create()
	}
	scope.finish()
	storage.release()
	for source in sources {
		assert html_allocated_unique_task_sources_[int(source.source)]
		source.finalize()
		assert int(source.source) !in html_allocated_unique_task_sources_
	}
	remaining := UniqueTaskSource.create()
	assert html_allocated_unique_task_sources_[int(remaining.source)]
	remaining.finalize()
}
