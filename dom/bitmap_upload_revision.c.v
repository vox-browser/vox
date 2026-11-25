module dom

fn C.atomic_compare_exchange_strong_u64(voidptr, voidptr, u64) bool

fn advance_bitmap_upload_revision(previous u64) bool {
	mut expected := previous
	return C.atomic_compare_exchange_strong_u64(&bitmap_upload_revisions, &expected, previous + 1)
}
