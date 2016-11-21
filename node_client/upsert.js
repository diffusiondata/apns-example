#!/usr/bin/env node
/*jshint esversion: 6 */

const diffusion = require('diffusion');

const urlParser = require('url');
function buildSessionOptionsFromURL(urlStr) {
	// Process the URL
	const url = urlParser.parse(urlStr);

	if (null === url.host || url.pathname === null)  {
		return null;
	}

	var result = {
		reconnect: false,
	    host : url.hostname,
	    rootTopic : url.pathname.substring(1)
	};

	if (null !== url.port) {
	    result.port = url.port;
	}

	if (null !== url.auth) {
	    const urlCredentials = url.auth.split(":");
	    result.principal = urlCredentials[0];
	    result.credentials = urlCredentials[1];
	}

	return result;
}

function usage() {
    console.log("Usage:", process.argv[1], "ws://username:password@somehost:80/some/root/topic topic-value");
}

if (process.argv.length < 4) {
    usage();
    process.exit(0);
}

const urlStr = process.argv[2];
const topicContent = process.argv[3];

const sessionOptions = buildSessionOptionsFromURL(urlStr);

diffusion.connect(sessionOptions).then(function(session){
	console.log("Connected to", urlStr);

	session.topics.add(sessionOptions.rootTopic, topicContent).then(function(result){
		if (result.added) {
			console.log("Created", sessionOptions.rootTopic, "with value", topicContent);
		} else {
			console.log("Updated", sessionOptions.rootTopic, "with value", topicContent);
		}
		process.exit(0);
	}, function(addFailureSeason){
		if(addFailureSeason.id == 2 /*diffusion.EXISTS_MISMATCH*/) {
			session.topics.update(sessionOptions.rootTopic, topicContent).then(function(){
				console.log("Updated", sessionOptions.rootTopic, "to", topicContent);
				process.exit(0);
			}, function(reason){
				console.error("Cannot update", sessionOptions.rootTopic, reason);
				process.exit(1);
			});
		} else {
			console.error("Cannot add topic", sessionOptions.rootTopic, addFailureSeason);
			process.exit(1);
		}
	});
}, function(reason) {
    console.warn("Cannot connect to", urlStr, reason.message);
	process.exit(1);
});
