module buildtools

fn test_existing_upstream_http2_admission_is_reused_without_a_second_gate() {
	source := 'struct H2PooledTransport {\n\tio_admission &sync.Mutex = sync.new_mutex()\n}\nfn (mut t H2PooledTransport) lock_io() {\n\tt.io_admission.lock()\n\tt.io_mu.lock()\n\tt.io_admission.unlock()\n}\nfn calls() { t.lock_io(); t.lock_io(); t.lock_io(); t.lock_io() }'
	patched := patch_h2_admission(source)!
	assert patched.starts_with(source)
	assert patched.contains('fn (mut t H2PooledTransport) vox_lock_io() { t.lock_io() }')
	assert !patched.contains('vox_admission_mu')
	for variant in [source.replace('t.io_admission.unlock()', 't.io_mu.unlock()'), source.replace('t.lock_io(); ', '')] {
		mut rejected := false
		patch_h2_admission(variant) or { rejected = true }
		assert rejected
	}
}

fn test_legacy_http2_transport_retains_the_guarded_admission_adapter() {
	source := 'struct H2PooledTransport {\n\tio_mu  &sync.Mutex  = sync.new_mutex()\n}\nfn calls() { t.io_mu.lock(); t.io_mu.lock(); t.io_mu.lock(); t.io_mu.lock() }'
	patched := patch_h2_admission(source)!
	assert patched.contains('vox_admission_mu &sync.Mutex')
	assert patched.count('t.vox_lock_io()') == 4
	assert patched.count('t.io_mu.lock()') == 1
}
