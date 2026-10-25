module main

fn test_window_state_restoration_respects_launch_modes_and_explicit_sizes() {
	assert browser_window_state_enabled(LaunchOptions{}, [])
	assert browser_window_state_enabled(LaunchOptions{ source: 'https://example.com' }, [])
	for arguments in [
		['--window-width', '800'],
		['--window-height', '600'],
		['--window-width=800'],
		['--window-height=600'],
	] {
		options := parse_launch_options(arguments)!
		assert !browser_window_state_enabled(options, arguments)
	}
	for arguments in [
		['--screenshot', 'out.png'],
		['--headless-smoke'],
		['--headless=layout-tree'],
		['--restore-tab', '/tmp/tab.json'],
	] {
		options := parse_launch_options(arguments)!
		assert !browser_window_state_enabled(options, arguments)
	}
}
