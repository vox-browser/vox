module requestidlecallback

fn test_time_remaining_clamps_and_rounds_up_to_milliseconds() {
	deadline := IdleDeadline.create(false)
	assert deadline.time_remaining_at(10.2, 14.3) == 5
	assert deadline.time_remaining_at(15, 14) == 0
	assert !deadline.did_timeout
	assert IdleDeadline.create(true).did_timeout
	assert IdleRequestOptions{}.timeout or { u32(99) } == 0
}
