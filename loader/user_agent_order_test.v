module loader

// Ladybird 8df0e61b479f5810d26fcb61f36eb08ad4debd3e.
fn test_default_user_agent_has_the_chrome_compatible_token_order() {
	user_agent := default_user_agent()
	assert user_agent.starts_with('Mozilla/5.0 (')
	assert user_agent.contains('${browser_name}/${browser_version}')
	assert user_agent.contains('AppleWebKit/537.36 (KHTML, like Gecko) Chrome/')
	assert user_agent.ends_with(' Safari/537.36')
}
