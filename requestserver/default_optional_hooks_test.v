module requestserver

fn test_optional_resource_hooks_start_uninstalled() {
	assert native_font_fetch_transport_ == none
	assert native_font_response_cache_provider_ == none
	assert native_response_cache_provider_ == none
	assert native_resource_fetch_host() == none
}
