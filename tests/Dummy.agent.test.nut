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

class DummyTestCase extends ImpTestCase {
    _bayeuxClient = null;

    function setUp() {
        _bayeuxClient = Bayeux.Client({"url" : ""});
        return _connect();
    }

    function testConnect() {
        // Yes, call it the second time to make sure it returns the same error
        return _connect();
    }

    function testDisconnect() {
        _bayeuxClient.disconnect();
    }

    function testIsConnected() {
        this.assertTrue(!_bayeuxClient.isConnected());
    }

    function testSubscribe() {
        local topic = "/test/topic";
        local handler = function () {};
        _bayeuxClient.subscribe(topic, handler);
        return Promise(function (resolve, reject) {
            _bayeuxClient.subscribe(topic, handler, function (err) {
                if (err != null && 
                    err.type == BAYEUX_CLIENT_ERROR_TYPE.LIBRARY_ERROR &&
                    err.details == BAYEUX_CLIENT_LIBRARY_ERROR_NOT_CONNECTED) {
                    return resolve();
                }
                return reject("BAYEUX_CLIENT_LIBRARY_ERROR_NOT_CONNECTED error was expected!");
            }.bindenv(this));
        }.bindenv(this));
    }

    function testUnsubscribe() {
        local topic = "/test/topic";
        _bayeuxClient.unsubscribe(topic);
        return Promise(function (resolve, reject) {
            _bayeuxClient.unsubscribe(topic, function (err) {
                if (err != null && 
                    err.type == BAYEUX_CLIENT_ERROR_TYPE.LIBRARY_ERROR &&
                    err.details == BAYEUX_CLIENT_LIBRARY_ERROR_NOT_CONNECTED) {
                    return resolve();
                }
                return reject("BAYEUX_CLIENT_LIBRARY_ERROR_NOT_CONNECTED error was expected!");
            }.bindenv(this));
        }.bindenv(this));
    }

    function testSetOnConnected() {
        _bayeuxClient.setOnConnected(function (err) {});
    }

    function testSetOnDisconnected() {
        _bayeuxClient.setOnDisconnected(function (err) {});
    }

    function testSetDebug() {
        _bayeuxClient.setDebug(true);
        _bayeuxClient.setDebug(false);
    }

    function _connect() {
        return Promise(function (resolve, reject) {
            _bayeuxClient.setOnConnected(function (err) {
                if (err != null && err.type == BAYEUX_CLIENT_ERROR_TYPE.TRANSPORT_FAILED) {
                    return resolve();
                }
                return reject("TRANSPORT_FAILED error was expected!");
                }.bindenv(this));
            _bayeuxClient.connect();
        }.bindenv(this));
    }
}