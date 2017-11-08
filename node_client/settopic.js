#!/usr/bin/env node
/*jshint esversion: 6 */

const diffusion = require('diffusion');
const commander = require('commander');

const TopicSpecification = diffusion.topics.TopicSpecification;
const TopicType = diffusion.topics.TopicType;
const jsonDataType = diffusion.datatypes.json();

function buildConfigFromArgs(argv) {
	var result = {
		sessionOptions: {
			reconnect: false
		}
	};

	commander
		.version('0.0.2')
		.option('-p, --port <portnumber>', 'Server port', parseInt)
		.option('-u, --principal <username>', 'User principal')
		.option('-c, --credentials <password>', 'User credentials/password')
		.arguments('<host> <topicpath> <numeric-topic-value>')
		.action(function(host, rootTopic, topicValue) {
			result.sessionOptions.host = host;
			result.rootTopic = rootTopic;
			result.topicValue = parseInt(topicValue);
		}).parse(argv);
	if(result.sessionOptions.host === undefined || result.rootTopic === undefined || result.topicValue === undefined || !Number.isInteger(result.topicValue)) {
		commander.outputHelp();
		process.exit(1);
	}

	if(commander.port) {result.sessionOptions.port = commander.port;}
	if(commander.principal) {result.sessionOptions.principal = commander.principal;}
	if(commander.credentials) {result.sessionOptions.credentials = commander.credentials;}
	return result;
}

const config = buildConfigFromArgs(process.argv);

diffusion.connect(config.sessionOptions).then(function(session){
	console.log("Connected to", config.sessionOptions.host);

	session.topics.add(config.rootTopic, TopicType.JSON).then(function(result){
		session.topics.update(config.rootTopic, jsonDataType.fromJsonString(config.topicValue)).then(
			function(topic) {
				console.log("Updated topic " + topic + " to " + config.topicValue);
				process.exit(0); 
			}, function(updateFailureReason) {
				console.log("Cannot set topic " + updateFailureReason);
				process.exit(1);
			}
		);
	}, function(addFailureSeason){
		console.error("Cannot add topic", config.rootTopic, addFailureSeason);
		process.exit(1);
	});
}, function(reason) {
    console.warn("Cannot connect to", config.sessionOptions.host, reason.message);
	process.exit(1);
});
