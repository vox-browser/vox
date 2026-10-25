module main

import encoding.utf8

fn test_window_title_preserves_short_titles_and_browser_suffix() {
	assert browser_window_title('') == 'vox'
	assert browser_window_title('Reddit') == 'Reddit — vox'
	assert browser_window_title('Привіт 🌍') == 'Привіт 🌍 — vox'
}

fn test_window_title_does_not_split_suffix_for_reported_reddit_post() {
	title := 'UA Pov: Close-up footage of Storm Shadow missiles strike targeting Proton electronics facility in Oryol : UkraineRussiaReport'
	assert title.len == 125
	result := browser_window_title(title)
	assert utf8.validate_str(result)
	assert result.len == 127
	assert result == title[..119] + ' — vox'
}

fn test_window_title_truncates_multibyte_characters_only_at_boundaries() {
	for character in ['é', '中', '🌍'] {
		for prefix_length in 115 .. 120 {
			prefix := 'a'.repeat(prefix_length)
			title := prefix + character.repeat(20)
			result := browser_window_title(title)
			assert utf8.validate_str(result)
			assert result.len <= 127
			assert result.ends_with(' — vox')
			body := result[..result.len - ' — vox'.len]
			assert title.starts_with(body)
			assert body.len + character.len > 119
		}
	}
}
