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

const SALESFORCE_TEST_CONSUMER_KEY = "@{SALESFORCE_TEST_CLIENT_ID}";
const SALESFORCE_TEST_CONSUMER_SECRET = "@{SALESFORCE_TEST_CLIENT_SECRET}";
const SALESFORCE_TEST_USERNAME = "@{SALESFORCE_TEST_USERNAME}";
const SALESFORCE_TEST_PASSWORD = "@{SALESFORCE_TEST_PASSWORD}";

const SALESFORCE_TEST_TOPIC = "/event/Test_Event__e"
const SALESFORCE_TEST_ACCESS_TOKEN_URL = "https://login.salesforce.com/services/oauth2/token";
const SALESFORCE_TEST_COMETD_URL = "/cometd/42.0/";

class SalesforceTestCase extends ImpTestCase {
    _bayeuxClient = null;
    _accessToken = null;
    _instanceUrl = null;

    function setUp() {
        _getAccessInfo();
        local config = {
            "url" : _instanceUrl + SALESFORCE_TEST_COMETD_URL,
            "requestHeaders": {
                "Authorization" : "Bearer " + _accessToken
            }
        };
        _bayeuxClient = Bayeux.Client(config);
        return _connect();
    }

    function tearDown() {
        return _disconnect();
    }

    function testConnect() {
        return _connect()
            .then(function (value) {
                return Promise.reject("Should have returned ALREADY_CONNECTED error");
            }.bindenv(this), function (reason) {
                if (reason.details != BC_LIBRARY_ERROR_ALREADY_CONNECTED) {
                    server.error(format("Error type: %d, details: %s", reason.type, reason.details.tostring()));
                    return Promise.reject("Should have returned ALREADY_CONNECTED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function testIsConnected() {
        this.assertTrue(_bayeuxClient.isConnected());
    }

    function testSubscribeSubscribeUnsubscribe() {
        return _subscribe()
            .then(function (value) {
                return _subscribe();
            }.bindenv(this))
            .then(function (value) {
                return _unsubscribe();
            }.bindenv(this))
            .fail(function (reason) {
                server.error(format("Error type: %d, details: %s", reason.type, reason.details.tostring()));
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testSubscribeUnsubscribe() {
        return _subscribe()
            .then(function (value) {
                return _unsubscribe();
            }.bindenv(this))
            .fail(function (reason) {
                server.error(format("Error type: %d, details: %s", reason.type, reason.details.tostring()));
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testUnsubscribe() {
        return _unsubscribe()
            .then(function (value) {
                return Promise.reject("Should have returned NOT_SUBSCRIBED error");
            }.bindenv(this), function (reason) {
                if (reason.details != BC_LIBRARY_ERROR_NOT_SUBSCRIBED) {
                    server.error(format("Error type: %d, details: %s", reason.type, reason.details.tostring()));
                    return Promise.reject("Should have returned NOT_SUBSCRIBED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function _connect() {
        return Promise(function (resolve, reject) {
            _bayeuxClient.setOnConnected(function (err) {
                if (err != null) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
            _bayeuxClient.connect();
        }.bindenv(this));
    }

    function _disconnect() {
        return Promise(function (resolve, reject) {
            _bayeuxClient.setOnDisconnected(function (err) {
                if (err != null) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
            _bayeuxClient.disconnect();
        }.bindenv(this));
    }

    function _subscribe() {
        local handler = function () {};
        return Promise(function (resolve, reject) {
            _bayeuxClient.subscribe(SALESFORCE_TEST_TOPIC, handler, function (err) {
                if (err != null) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _unsubscribe() {
        return Promise(function (resolve, reject) {
            _bayeuxClient.unsubscribe(SALESFORCE_TEST_TOPIC, function (err) {
                if (err != null) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _getAccessInfo() {
        local body = format("grant_type=password&client_id=%s&client_secret=%s&username=%s&password=%s",
            SALESFORCE_TEST_CLIENT_ID, SALESFORCE_TEST_CLIENT_SECRET, SALESFORCE_TEST_USERNAME, SALESFORCE_TEST_PASSWORD);
        local req = http.post(SALESFORCE_TEST_ACCESS_TOKEN_URL, {}, body);
        local resp = req.sendsync();
        local respBodyTable = http.jsondecode(resp.body);
        _accessToken = respBodyTable["access_token"];
        _instanceUrl = respBodyTable["instance_url"];
    }
}