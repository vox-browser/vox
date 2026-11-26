// vtest build: macos
module ggshape

fn test_document_pipeline_preparation_joins_at_first_gg_use() {
	if prepare_document_pipelines_early {
		assert document_pipelines_need_preparation()
		assert submit_document_pipelines()
		assert gpu.pipelines_pending
		assert !document_pipelines_need_preparation()
		assert !submit_document_pipelines()
	}
	ctx := context() or { panic(err) }
	assert !gpu.pipelines_pending
	finish_document_pipelines()
	current := context() or { panic(err) }
	assert voidptr(current) == voidptr(ctx)
}
