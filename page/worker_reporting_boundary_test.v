module page

fn test_page_client_worker_agent_lifetime_and_reporting() {
	mut client := PageClient.create()
	client.page_did_report_worker_exception('boom', 'worker.js', 8, 13)
	assert client.worker_exceptions() == [WorkerException{
		message: 'boom'
		filename: 'worker.js'
		line: 8
		column: 13
	}]
	client.page_did_register_javascript_source(4, 'worker.js')
	assert client.javascript_sources().len == 0
	client.active_devtools_client_ = true
	client.page_did_register_javascript_source(4, 'worker.js')
	assert client.javascript_sources() == [JavaScriptSource{ document_id: 4, description: 'worker.js' }]
	client.page_did_post_broadcast_channel_message('updates:hello')
	assert client.broadcast_channel_messages() == ['updates:hello']

	agent_id := client.start_worker_agent(WorkerAgentStartRequest{
		owner_token: 'owner-a'
		script_url: 'https://example.test/worker.js'
	})
	assert client.worker_agent(agent_id)? == WorkerAgentState{
		id: agent_id
		owner_token: 'owner-a'
		script_url: 'https://example.test/worker.js'
	}
	client.close_worker_agent(agent_id, 'wrong-owner')
	assert client.worker_agent(agent_id) != none
	client.close_worker_agent(agent_id, 'owner-a')
	assert client.worker_agent(agent_id) == none
}

fn test_page_client_flushes_dom_mutations_only_while_listening() {
	mut model := Page.create(1)!
	mut client := model.client()
	client.page_did_mutate_dom('childList', 'parent', ['added'], ['removed'], none, none,
		none)
	assert client.pending_dom_mutation_count() == 1
	client.flush_pending_dom_mutations()
	assert client.pending_dom_mutation_count() == 0
	assert client.events.filter(it.name == 'mutate-dom').len == 0

	model.set_listen_for_dom_mutations(true)
	client.page_did_mutate_dom('attributes', 'node', [], [], none, none, 'class')
	assert client.pending_dom_mutation_count() == 1
	client.flush_pending_dom_mutations()
	assert client.pending_dom_mutation_count() == 0
	assert client.events.last().name == 'mutate-dom'
	assert client.events.last().text == 'attributes:node:0:0:::class'
	model.set_listen_for_dom_mutations(false)
}
