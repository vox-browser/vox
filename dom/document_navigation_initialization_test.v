module dom

fn test_direct_navigation_document_installs_final_sandbox_flags() {
	for flags in [u32(0), u32(64 | 256 | 1024)] {
		document := Document.create_and_initialize(.html, 'text/html', &NavigationParams{
			response_url:               URL{
				value: 'https://example.test/'
			}
			final_sandboxing_flag_bits: flags
		})!
		assert document.active_sandboxing_flag_bits() == flags
		assert document.active_sandboxing_flag_set().sandboxed_forms == (flags & u32(64) != 0)
		assert document.active_sandboxing_flag_set().sandboxed_document_domain == (flags & u32(1024) != 0)
	}
}

fn test_direct_navigation_document_installs_navigation_metadata() {
	policy := &PolicyContainer{}
	base := URL{
		value: 'https://example.test/parent/'
	}
	document := Document.create_and_initialize(.html, 'text/html', &NavigationParams{
		response_url:        URL{
			value: 'about:srcdoc'
		}
		request_current_url: URL{
			value: 'about:srcdoc'
		}
		policy_container:    policy
		about_base_url:      base
		id:                  'navigation-17'
	})!
	assert document.policy_container() == policy
	assert document.get_about_base_url()? == base
	assert document.base_url() == base
	assert document.get_navigation_id()? == 'navigation-17'
	assert document.url_string() == 'about:srcdoc'
}
