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

class ReconnectTestCase extends ImpTestCase {
    _bayeuxClient = null;

    function testDelayedReconnect() {
        // The plan is:
        // 1) Emulate state connected
        // 2) Set the onDisconnected callback to our handler
        // 3) Emulate a delivery of an unsuccessful "connect" (heartbeat) message response.
        //    It will contain an advice with interval = 3000 (3 sec) and reconnect = "retry"
        // 4) The lib should try to reconnect after 3 sec delay
        // 5) Then it should get an error from http API (because URL is empty)
        // 6) Due to the http error it should go into a disconnected state and call our handler
        // 7) So we can measure the time elapsed between the message delivery and the disconnection.
        //    It should be from 3 to 4 seconds.

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            // msec
            const INTERVAL = 3000;

            // Emulation of state connected
            _bayeuxClient._onConnected(null);

            local msgId = 1;
            _bayeuxClient._metaHandlers[msgId] <- _bayeuxClient._onReconnectResponse.bindenv(_bayeuxClient);

            local startTime = date();
            local onDisconnected = function(err) {
                local endTime = date();
                local timeElasped = (endTime.time - startTime.time) * 1000 + (endTime.usec - startTime.usec) / 1000.0;

                if (math.abs(timeElasped - INTERVAL) < 500) {
                    return resolve();
                } else if (timeElasped >= INTERVAL) {
                    server.error(timeElasped + " milliseconds elapsed");
                    return reject("It took more time than expected");
                } else {
                    server.error(timeElasped + " milliseconds elapsed");
                    return reject("It took less time than expected");
                }
            }.bindenv(this);
            _bayeuxClient.setOnDisconnected(onDisconnected);

            local connectResponse = {
                "clientId" : "test",
                "advice" : {"interval" : INTERVAL, "timeout" : 110000, "reconnect" : "retry"},
                "channel" : "/meta/connect",
                "id" : msgId,
                "successful" : false
            };
            _bayeuxClient._handleMessages([connectResponse]);
        }.bindenv(this));
    }

    function testDelayedBackoffReconnect() {
        // The plan is:
        // 1) Emulate state connected
        // 2) Set the onDisconnected callback to our handler
        // 3) Increase _backoff (by default it should become 1 sec) and set an advice interval manually to 2 sec
        // 4) Emulate a delivery of an unsuccessful "connect" (heartbeat) message response.
        //    It will NOT contain an advice for interval (so _backoff is not reset) and will contain reconnect = "retry"
        // 5) The lib should try to reconnect after 3 sec delay
        // 6) Then it should get an error from http API (because URL is empty)
        // 7) Due to the http error it should go into a disconnected state and call our handler
        // 8) So we can measure the time elapsed between the message delivery and the disconnection.
        //    It should be from 3 to 4 seconds.

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            // msec
            const INTERVAL = 2000;

            // Emulation of state connected
            _bayeuxClient._onConnected(null);
            // Increase _backoff
            _bayeuxClient._increaseBackoff();
            local backoff = _bayeuxClient._backoff;

            _bayeuxClient._advice.interval = INTERVAL;

            local msgId = 1;
            _bayeuxClient._metaHandlers[msgId] <- _bayeuxClient._onReconnectResponse.bindenv(_bayeuxClient);

            local startTime = date();
            local onDisconnected = function(err) {
                local endTime = date();
                local timeElasped = (endTime.time - startTime.time) * 1000 + (endTime.usec - startTime.usec) / 1000.0;
                if (math.abs(timeElasped - (INTERVAL + backoff * 1000)) < 500) {
                    return resolve();
                } else if (timeElasped >= INTERVAL + backoff * 1000) {
                    server.error(timeElasped + " milliseconds elapsed");
                    return reject("It took more time than expected");
                } else {
                    server.error(timeElasped + " milliseconds elapsed");
                    return reject("It took less time than expected");
                }
            }.bindenv(this);
            _bayeuxClient.setOnDisconnected(onDisconnected);

            local connectResponse = {
                "clientId" : "test",
                "advice" : {"timeout" : 110000, "reconnect" : "retry"},
                "channel" : "/meta/connect",
                "id" : msgId,
                "successful" : false
            };
            _bayeuxClient._handleMessages([connectResponse]);
        }.bindenv(this));
    }

    function testNoneReconnect() {
        // The plan is:
        // 1) Emulate state connected
        // 2) Set the onDisconnected callback to our handler
        // 3) Emulate a delivery of an unsuccessful "connect" (heartbeat) message response.
        //    It will contain an advice with reconnect = "none" and "error" field with an error description.
        // 4) The lib should NOT try to reconnect
        // 5) Then it should go into a disconnected state and call our handler with the error described in the message

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            const ERROR_FIELD = "Some test error";

            // Emulation of state connected
            _bayeuxClient._onConnected(null);

            local msgId = 1;
            _bayeuxClient._metaHandlers[msgId] <- _bayeuxClient._onReconnectResponse.bindenv(_bayeuxClient);

            local onDisconnected = function(err) {
                if (err != null &&
                    err.type == BC_ERROR_TYPE.BAYEUX_ERROR &&
                    err.details == ERROR_FIELD) {
                    return resolve();
                } else if (err != null) {
                    server.error(format("Error type: %d, details: %s", err.type, err.details.tostring()));
                    return reject("Another error was expected");
                }
                return reject("An error was expected");
            }.bindenv(this);
            _bayeuxClient.setOnDisconnected(onDisconnected);

            local connectResponse = {
                "clientId" : "test",
                "advice" : {"interval" : 100000, "timeout" : 110000, "reconnect" : "none"},
                "channel" : "/meta/connect",
                "id" : msgId,
                "successful" : false,
                "error" : ERROR_FIELD
            };
            _bayeuxClient._handleMessages([connectResponse]);
        }.bindenv(this));
    }
}