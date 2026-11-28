module main

import os

// Include tools/libjs_reddit.v in the explicit file list. This standalone
// diagnostic avoids browser UI/paint compilation and never supplies timings.
fn test_reddit_builtin_profile() {
	if os.getenv('VOX_REDDIT_BUILTIN_PROFILE') == '' { return }
	main()
}
