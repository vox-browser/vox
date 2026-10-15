module platform

fn test_releasing_unused_browser_memory_retains_live_objects() {
	mut retained := {'nested': ['Unicode λ and 🌍'.repeat(100), 'live document data']}
	for _ in 0 .. 3 {
		release_unused_browser_memory()
		assert retained['nested'][0] == 'Unicode λ and 🌍'.repeat(100)
		assert retained['nested'][1] == 'live document data'
	}
	retained['nested'] << 'after releasing unused pages'
	release_unused_browser_memory()
	assert retained['nested'].last() == 'after releasing unused pages'
}
