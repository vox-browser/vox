module html

import dom

fn test_global_cache_storage_getter_exposes_real_storage_and_preserves_identity() {
	document := dom.Document.create(dom.URL{value: 'https://cache-global.example/page'})
	window := WindowModel.create_top_level(document, none, 'cache-global') or { panic(err) }
	mut scope := window.window_or_worker_global_scope()
	mut storage := scope.caches()
	assert storage == scope.caches()
	assert storage.has('assets').value or { panic('missing boolean result') } == false
	opened := storage.open('assets')
	assert opened.state == .fulfilled
	assert opened.cache != none
	assert scope.caches().has('assets').value or { panic('missing boolean result') } == true
	assert scope.caches().keys().keys == ['assets']
	assert storage.delete_('assets').value or { panic('missing boolean result') } == true
	assert scope.caches().has('assets').value or { panic('missing boolean result') } == false
}

fn test_worker_and_window_cache_storage_services_retain_separate_global_instances() {
	document := dom.Document.create(dom.URL{value: 'https://cache-owner.example/page'})
	window := WindowModel.create_top_level(document, none, 'cache-owner') or { panic(err) }
	mut window_scope := window.window_or_worker_global_scope()
	worker := WorkerGlobalScope.create(dom.URL{value: 'https://cache-owner.example/worker.js'}, .classic, '', &ScriptingRealm{})
	mut worker_scope := worker.window_or_worker_global_scope()
	mut worker_storage := worker_scope.caches()
	worker_storage.open('worker-assets')
	assert worker_scope.caches() == worker_storage
	assert worker_storage != window_scope.caches()
	assert worker_scope.caches().has('worker-assets').value or { panic('missing boolean result') } == true
	assert window_scope.caches().has('worker-assets').value or { panic('missing boolean result') } == false
}
