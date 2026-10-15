module main

fn quoted_video_reference_original_scan(scripts []string) []string {
	mut references := []string{}
	mut seen := map[string]bool{}
	for source in scripts {
		mut position := 0
		for position < source.len {
			if source[position] != `'` && source[position] != `"` { position++; continue }
			quote := source[position]
			start := position + 1
			position = start
			for position < source.len && source[position] != quote { position++ }
			if position >= source.len { break }
			value := source[start..position]
			lower := value.to_lower()
			if (lower.contains('.webm') || lower.contains('.mp4')) && value !in seen {
				seen[value] = true
				references << value
			}
			position++
		}
	}
	return references
}

fn test_script_video_reference_scan_preserves_extensions_quotes_order_and_exact_deduplication() {
	scripts := ['const a="clip.MP4?token=1";const b=\'relative.WEbM#frame\';',
		r'"clip.MP4?token=1";"clip.mp4?token=1";"ordinary";".mp";".web";"clip.webm-more";',
		r'"λ.Mp4";"ΜΡ4";".mP4";".wEbM";"unterminated.webm',
		r'const odd="escaped\\";"ending.mp4";']
	assert quoted_video_references(scripts) == quoted_video_reference_original_scan(scripts)
	for value in ['', '.mp', '.web', '.mp4', '.MP4', 'x.webm?query', 'x.WEBM#fragment',
		'λ.mp4', 'clip.webm-more', 'ordinary dot.suffix', '\u0000.mp4'] {
		lower := value.to_lower()
		assert quoted_video_reference_has_extension(value) == (lower.contains('.webm') || lower.contains('.mp4'))
	}
}

fn test_script_video_reference_scan_keeps_large_minified_candidates_without_url_parsing() {
	fragment := 'a.b(c);'.repeat(12_000) + '.Mp4' + 'x+y;'.repeat(12_000)
	scripts := ['const payload="${fragment}";'.repeat(2), r'const local="file:///missing-local.webm";']
	assert quoted_video_references(scripts) == [fragment, 'file:///missing-local.webm']
	assert javascript_video_source_states('https://pikabu.ru/', ['const payload="${fragment}";']).len == 0
}

fn test_script_video_reference_local_gate_preserves_file_sources_and_nonremote_documents() {
	for base in ['https://pikabu.ru/', 'http://example.test/base/'] {
		for reference in ['clip.mp4', '/clip.webm', '//cdn.test/clip.mp4',
			'not a scheme:clip.mp4', ''] {
			assert !javascript_video_reference_can_be_local(reference, base)
		}
		for reference in ['file:///tmp/clip.mp4', 'FiLe:/tmp/clip.webm', '  file:///tmp/clip.webm  ',
			'\u0000\u0001file:///tmp/clip.mp4\u001f', 'f\ti\nl\re:///tmp/clip.webm'] {
			assert javascript_video_reference_can_be_local(reference, base)
			assert resolve_document_reference(reference, base).starts_with('file:')
		}
		// The old decoder treats an opaque URL without :// as a filesystem
		// name. Even unusual explicit schemes must reach that existing check.
		for reference in ['data:clip.mp4', 'custom:clip.webm', 'CuStOm+1.2:clip.mp4',
			'c\tu\ns\rtom:clip.webm'] {
			assert javascript_video_reference_can_be_local(reference, base)
			assert !resolve_document_reference(reference, base).contains('://')
		}
		// Absolute remote URLs may conservatively pass this inexpensive gate;
		// decode_local_video_frame still rejects them after normal resolution.
		assert javascript_video_reference_can_be_local('https://cdn.test/clip.webm', base)
		assert resolve_document_reference('https://cdn.test/clip.webm', base).starts_with('https://')
	}
	for base in ['file:///tmp/page.html', 'about:blank', 'about:srcdoc', ''] {
		for reference in ['clip.mp4', '../clip.webm', '/tmp/clip.mp4', 'file:///tmp/clip.webm'] {
			assert javascript_video_reference_can_be_local(reference, base)
		}
	}
}
