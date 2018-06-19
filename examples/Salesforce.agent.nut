// MIT License
//
// Copyright 2018 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Utility Libraries
#require "Rocky.class.nut:1.2.3"

// Web Integration Library
#require "Salesforce.agent.lib.nut:2.0.0"

// Bayeux (cometD) protocol client
#require "BayeuxClient.agent.lib.nut:1.0.0"

// BayeuxClient library example:
// - authenticates the device on Salesforce platform using the provided Consumer Key and Consumer Secret
// - subscribes to the events channel created on Salesforce during the setup
// - periodically (every 10 seconds) sends an event to the cloud. The event contains the current timestamp
// - logs all events received from the cloud (exactly the events sent in the previous point)

const SALESFORCE_VERSION = "v42.0";

// Extends Salesforce Library to handle authorization
class SalesforceOAuth2 extends Salesforce {

    _login = null;
    _onLoggedInCallbacks = null;

    constructor(consumerKey, consumerSecret, loginServiceBase = null, salesforceVersion = SALESFORCE_VERSION) {
        _clientId = consumerKey;
        _clientSecret = consumerSecret;
        _onLoggedInCallbacks = [];

        if ("Rocky" in getroottable()) {
            _login = Rocky();
        } else {
            throw "Unmet dependency: SalesforceOAuth2 requires Rocky";
        }

        if (loginServiceBase != null) _loginServiceBase = loginServiceBase;
        if (salesforceVersion != null) _version = salesforceVersion;

        defineLoginEndpoint();
    }

    function addOnLoggedInCallback(callback) {
        _onLoggedInCallbacks.append(callback);
    }

    function defineLoginEndpoint() {
        // Define log in endpoint for a GET request to the agent URL
        _login.get("/", function(context) {

            // Check if an OAuth code was passed in
            if (!("code" in context.req.query)) {
                // If it wasn't, redirect to login service
                local location = format(
                    "%s/services/oauth2/authorize?response_type=code&client_id=%s&redirect_uri=%s",
                    _loginServiceBase,
                    _clientId, http.agenturl());
                context.setHeader("Location", location);
                context.send(302, "Found");

                return;
            }

            // Exchange the auth code for inan OAuth token
            getOAuthToken(context.req.query["code"], function(err, resp, respData) {
                if (err) {
                    context.send(400, "Error authenticating (" + err + ").");
                    return;
                }

                server.log("Successfully logged in!");

                // Set/update the credentials in the Salesforce object
                setInstanceUrl(respData.instance_url);
                setToken(respData.access_token);

                foreach (callback in _onLoggedInCallbacks) {
                    callback(respData);
                }

                // Finally - inform the user we're done!
                context.send(200, "Authentication complete - you may now close this window");
            }.bindenv(this));
        }.bindenv(this));
    }

    // OAuth 2.0 methods
    function getOAuthToken(code, cb) {
        // Send request with an authorization code
        _oauthTokenRequest("authorization_code", code, cb);
    }

    function refreshOAuthToken(refreshToken, cb) {
        // Send request with refresh token
        _oauthTokenRequest("refresh_token", refreshToken, cb);
    }

    function _oauthTokenRequest(type, tokenCode, cb = null) {
        // Build the request
        local url = format("%s/services/oauth2/token", _loginServiceBase);
        local headers = { "Content-Type": "application/x-www-form-urlencoded" };
        local data = {
            "grant_type": type,
            "client_id": _clientId,
            "client_secret": _clientSecret,
        };

        // Set the "code" or "refresh_token" parameters based on grant_type
        if (type == "authorization_code") {
            data.code <- tokenCode;
            data.redirect_uri <- http.agenturl();
        } else if (type == "refresh_token") {
            data.refresh_token <- tokenCode;
        } else {
            throw "Unknown grant_type";
        }

        local body = http.urlencode(data);

        http.post(url, headers, body).sendasync(function(resp) {
            local respData = http.jsondecode(resp.body);
            local err = null;

            // If there was an error, set the error code
            if (resp.statuscode != 200) {
                err = "message" in data ? data.message : "No error message";
            }

            // Invoke the callback
            if (cb) {
                imp.wakeup(0, function() {
                    cb(err, resp, respData);
                });
            }
        });
    }
}

const EVENT_NAME = "testevent__e";
const EVENT_FIELD_NAME = "mytimestamp__c";
// in seconds
const SEND_INTERVAL = 10;

// Application code, sends events to Salesforce
class SalesforceEventSender {

    _force = null;
    _sendEventUrl = null;
    _started = false;

    constructor(salesforce, eventName = EVENT_NAME) {
        _sendEventUrl = format("sobjects/%s/", eventName);
        _force = salesforce;
        _force.addOnLoggedInCallback(start.bindenv(this));
    }

    function start(authData) {
        if (_started) {
            return;
        }
        server.log("Start sending events!");
        _started = true;
        imp.wakeup(SEND_INTERVAL, sendData.bindenv(this));
    }

    // Sends the data to Salesforce as Platform Event.
    function sendData() {
        local body = {};
        body[EVENT_FIELD_NAME] <- time().tostring();

        // Log the data being sent to the cloud
        server.log("Event to send: " + http.jsonencode(body));

        // Send Salesforce platform event
        _force.request("POST", _sendEventUrl, http.jsonencode(body), function (err, respData) {
            if (err) {
                server.error(http.jsonencode(err));
            }
            else {
                server.log("Event sent successfully\n");
            }
        });

        imp.wakeup(SEND_INTERVAL, sendData.bindenv(this));
    }
}

const COMETD_URL = "/cometd/42.0/";

// Application code, receives the events from Salesforce
class SalesforceEventReceiver {

    _bayeux = null;
    _force = null;
    _started = false;
    _eventName = null;

    constructor(salesforce, eventName = EVENT_NAME) {
        _eventName = eventName;
        _force = salesforce;
        _force.addOnLoggedInCallback(start.bindenv(this));
    }

    function start(authData) {
        if (_started) {
            return;
        }
        _started = true;
        server.log("Start receiving events!");

        local config = {
            "url" : authData.instance_url + COMETD_URL,
            "requestHeaders": {
                "Authorization" : "OAuth " + authData.access_token
            }
        };

        _bayeux = Bayeux.Client(config, onConnected.bindenv(this), onDisconnected.bindenv(this));
        _bayeux.connect();
    }

    function eventHandler(channel, event) {
        server.log("Event received: " + http.jsonencode(event) + "\n");
    }

    function onConnected(error) {
        if (error != null) {
            server.error("Bayeux connection failed");
            server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
            return;
        }

        local onSubscribed = function(error) {
            if (error != null) {
                server.error("Bayeux subscription failed");
                server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
                return;
            }
        };

        _bayeux.subscribe("/event/" + _eventName, eventHandler, onSubscribed);
    }

    function onDisconnected(error) {
        server.log("Bayeux client disconnected!");
    }
}

// RUNTIME
// ---------------------------------------------------------------------------------

// SALESFORCE CONSTANTS
// ----------------------------------------------------------
const CONSUMER_KEY = "<YOUR_CONSUMER_KEY_HERE>";
const CONSUMER_SECRET = "<YOUR_CONSUMER_SECRET_HERE>";

// Start Application
salesforce <- SalesforceOAuth2(CONSUMER_KEY, CONSUMER_SECRET);
SalesforceEventSender(salesforce);
SalesforceEventReceiver(salesforce);
server.log("Log in please!");