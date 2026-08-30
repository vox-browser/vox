module requestidlecallback

fn test_time_remaining_clamps_and_rounds_up_to_milliseconds() {
	deadline := IdleDeadline.create(false)
	assert deadline.time_remaining_at(10.2, 14.3) == 5
	assert deadline.time_remaining_at(15, 14) == 0
	assert !deadline.did_timeout()
	assert IdleDeadline.create(true).did_timeout()
	assert IdleRequestOptions{}.timeout or { u32(99) } == 0
}

fn test_time_remaining_uses_the_injected_event_loop_boundary() {
	deadline := IdleDeadline.create_with_host(false, IdleDeadlineHost{
		now:                 10.2
		event_loop_deadline: 14.3
	})
	assert deadline.time_remaining() == 5
}
