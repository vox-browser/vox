module url

import os

fn source_file_origin_child(mode string) (int, string) {
	mut environment := os.environ()
	environment['VOX2_SOURCE_FILE_ORIGIN_POLICY'] = mode
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	code := process.code
	output := process.stdout_slurp() + process.stderr_slurp()
	process.close()
	return code, output
}

fn test_source_file_origin_policy_is_process_wide_and_one_shot() {
	assert !file_scheme_urls_have_tuple_origins()
	cached := parse('file://original-host/tmp/before-enable.html')?
	first := cached.origin()
	assert first.is_opaque_file_origin()
	assert !first.is_same_origin(cached.origin())
	mode := os.getenv('VOX2_SOURCE_FILE_ORIGIN_POLICY')
	if mode == 'enabled' {
		set_file_scheme_urls_have_tuple_origins()
		assert file_scheme_urls_have_tuple_origins()
		actual := cached.origin()
		assert !actual.is_opaque() && !actual.is_opaque_file_origin()
		assert actual.serialize() == 'file://'
		// Dispatch on the sum type before narrowing it. Current V otherwise
		// retains the narrowed receiver when compiling this later method call.
		for address in ['file:///tmp/other.html', 'file://different-host/tmp/other.html',
			'blob:file:///tmp/actual-blob-id'] {
			assert actual.is_same_origin(parse(address)?.origin())
		}
		if actual is OriginTuple {
			assert actual.scheme? == 'file'
			assert actual.host.serialize() == ''
			assert actual.port == none && actual.domain == none
		} else {
			assert false
		}
		assert cached.host?.serialize() == 'original-host'
		assert first.is_opaque_file_origin()
		data := parse('data:text/plain,file-policy-control')?
		assert data.origin().is_opaque() && !data.origin().is_opaque_file_origin()
		assert !data.origin().is_same_origin(data.origin())
		assert parse('https://file-policy.test:8443/page')?.origin().serialize() == 'https://file-policy.test:8443'
		assert parse('resource://file-policy-control:8123/a')?.origin().serialize() == 'resource://'
		return
	}
	if mode == 'repeat' {
		set_file_scheme_urls_have_tuple_origins()
		set_file_scheme_urls_have_tuple_origins()
		assert false, 'Source VERIFY allowed a repeated file-origin enable'
		return
	}
	if mode == 'fresh-default' {
		return
	}
	for child_mode in ['enabled', 'fresh-default', 'repeat'] {
		code, output := source_file_origin_child(child_mode)
		if child_mode == 'repeat' {
			assert code != 0 && output.contains('File scheme tuple origins have already been enabled'), output
		} else {
			assert code == 0, output
		}
		assert !file_scheme_urls_have_tuple_origins()
		assert cached.origin().is_opaque_file_origin()
	}
}
