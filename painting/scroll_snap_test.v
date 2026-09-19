module painting

fn test_momentum_fling_estimator_waits_for_decay_and_predicts_geometric_tail() {
	mut estimator := MomentumFlingEstimator{}
	assert estimator.estimate_remaining_displacement(Point{0, 10}) == none
	estimate := estimator.estimate_remaining_displacement(Point{0, 8}) or {
		panic('missing decaying momentum estimate')
	}
	assert estimate == Point{0, 40}

	estimator.reset()
	assert estimator.estimate_remaining_displacement(Point{10, 0}) == none
	assert estimator.estimate_remaining_displacement(Point{10, 0}) == none
}

fn test_momentum_fling_estimator_eventually_predicts_slow_decay() {
	mut estimator := MomentumFlingEstimator{}
	assert estimator.estimate_remaining_displacement(Point{100, 0}) == none
	assert estimator.estimate_remaining_displacement(Point{98, 0}) == none
	assert estimator.estimate_remaining_displacement(Point{96, 0}) == none
	estimate := estimator.estimate_remaining_displacement(Point{94, 0}) or {
		panic('missing slow-decay estimate')
	}
	assert estimate.x > 4000
}
