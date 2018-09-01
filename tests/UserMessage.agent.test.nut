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

class UserMessageTestCase extends ImpTestCase {
    _bayeuxClient = null;

    function testPositive1() {
        // In this test we expect our handler to be called
        const HANDLER_TOPIC = "/a/**";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return resolve();
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return reject("The handler should have been called");
        }.bindenv(this));
    }

    function testPositive2() {
        // In this test we expect our handler to be called
        const HANDLER_TOPIC = "/a/b/**";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return resolve();
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return reject("The handler should have been called");
        }.bindenv(this));
    }

    function testPositive3() {
        // In this test we expect our handler to be called
        const HANDLER_TOPIC = "/a/b/*";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return resolve();
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return reject("The handler should have been called");
        }.bindenv(this));
    }

    function testPositive4() {
        // In this test we expect our handler to be called
        const HANDLER_TOPIC = "/a/b/c";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return resolve();
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return reject("The handler should have been called");
        }.bindenv(this));
    }

    function testNegative1() {
        // In this test we expect our handler NOT to be called
        const HANDLER_TOPIC = "/a/b";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return reject("The handler was not expected to be called");
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return resolve();
        }.bindenv(this));
    }

    function testNegative2() {
        // In this test we expect our handler NOT to be called
        const HANDLER_TOPIC = "/a/*";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return reject("The handler was not expected to be called");
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return resolve();
        }.bindenv(this));
    }

    function testNegative3() {
        // In this test we expect our handler NOT to be called
        const HANDLER_TOPIC = "/a";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return reject("The handler was not expected to be called");
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return resolve();
        }.bindenv(this));
    }

    function testNegative4() {
        // In this test we expect our handler NOT to be called
        const HANDLER_TOPIC = "/a/b/c/*";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return reject("The handler was not expected to be called");
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return resolve();
        }.bindenv(this));
    }

    function testNegative5() {
        // In this test we expect our handler NOT to be called
        const HANDLER_TOPIC = "/a/b/c/**";
        const MSG_TOPIC = "/a/b/c";

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            local handler = function(topic, msg) {
                return reject("The handler was not expected to be called");
            }.bindenv(this);

            local message = {
                "channel" : MSG_TOPIC,
                "data" : "Some data"
            };

            _bayeuxClient._userHandlers[HANDLER_TOPIC] <- handler;
            // It calls the handler synchronously
            _bayeuxClient._onUserMessage(message);

            return resolve();
        }.bindenv(this));
    }
}