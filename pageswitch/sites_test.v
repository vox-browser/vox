module pageswitch

fn test_registry_only_accepts_sort_switches_in_the_same_old_reddit_community() {
	hot := 'https://old.reddit.com/r/UkraineRussiaReport/'
	assert supports(hot, hot + 'new/')
	assert supports(hot + 'new/', hot + 'hot/')
	assert supports(hot, 'https://old.reddit.com/r/ukrainerussiareport/rising/')
	for address in [hot, hot + 'comments/id/title/', hot + 'new/?after=t3_x', hot + 'new/#thing',
		hot + 'new/?', 'https://old.reddit.com/r/other/new/',
		'https://old.reddit.com.evil/r/UkraineRussiaReport/new/',
		'https://old.reddit.com:443/r/UkraineRussiaReport/new/',
		'https://user@old.reddit.com/r/UkraineRussiaReport/new/',
		'https://www.reddit.com/r/UkraineRussiaReport/new/',
		'http://old.reddit.com/r/UkraineRussiaReport/new/'] {
		assert !supports(hot, address), address
	}
}
