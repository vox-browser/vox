module main

$if vox_reddit_engine_benchmark ? {
	fn test_reddit_engine_benchmark() {
		reddit_engine_benchmark_main()!
	}
}
