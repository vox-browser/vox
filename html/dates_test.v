module html

fn test_week_number_of_the_last_day() {
	assert week_number_of_the_last_day(2015) == 53
	assert week_number_of_the_last_day(2020) == 53
	assert week_number_of_the_last_day(2021) == 52
}

fn test_valid_date_microsyntaxes() {
	assert is_valid_week_string('2020-W53')
	assert !is_valid_week_string('2021-W53')
	assert is_valid_month_string('2024-02')
	assert !is_valid_month_string('0000-02')
	assert is_valid_date_string('2024-02-29')
	assert !is_valid_date_string('2023-02-29')
	assert is_valid_time_string('23:59:59.999')
	assert is_valid_time_string('00:00')
	assert !is_valid_time_string('24:00')
	assert !is_valid_time_string('12:60')
	assert !is_valid_time_string('12:30:00.0000')
	assert is_valid_local_date_and_time_string('2024-02-29T23:59')
	assert is_valid_local_date_and_time_string('2024-02-29 23:59')
}

fn test_normalize_local_date_and_time_string() {
	assert normalize_local_date_and_time_string('1986-01-28 11:38:00.010') == '1986-01-28T11:38:00.01'
	assert normalize_local_date_and_time_string('1986-01-28T11:38:00.000') == '1986-01-28T11:38'
	assert normalize_local_date_and_time_string('1986-01-28T11:38:01.000') == '1986-01-28T11:38:01'
}

fn test_parse_date_microsyntaxes() {
	assert parse_a_month_string('2024-02')? == YearAndMonth{2024, 2}
	assert parse_a_month_string('2024-2') == none
	assert number_of_months_since_unix_epoch(YearAndMonth{1970, 1}) == 0
	assert parse_a_week_string('2020-W53')? == WeekYearAndWeek{2020, 53}
	assert parse_a_week_string('2021-W53') == none
	assert parse_a_date_string('2024-02-29')? == YearMonthDay{2024, 2, 29}
	assert parse_a_date_string('2023-02-29') == none
	time := parse_time_string('12:34:56.75')!
	assert time.hour == 12
	assert time.minute == 34
	assert time.second == f32(56.75)
	date_time := parse_a_local_date_and_time_string('2024-02-29T12:34')?
	assert date_time.date == YearMonthDay{2024, 2, 29}
	assert date_time.time == HourMinuteSecond{12, 34, 0}
}
