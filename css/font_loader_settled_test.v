module css

fn test_shared_completed_font_loader_keeps_its_remaining_sources_and_typeface() {
	$if macos {
		computer := FontComputer.create()
		mut loader := FontLoader.create(computer, 'Settled source', [], [
			URL.from_url('file:///System/Library/Fonts/Supplemental/Arial.ttf'),
			URL.from_url('file:///System/Library/Fonts/Supplemental/Times New Roman.ttf'),
		], none)
		loader.start_loading_next_url()
		assert loader.has_completed
		assert loader.typeface != unsafe { nil }
		assert loader.urls.len == 1
		first_typeface := loader.typeface
		loader.start_loading_next_url()
		assert loader.urls.len == 1
		assert loader.typeface == first_typeface
	}
}
