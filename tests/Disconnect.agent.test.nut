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

class DisconnectTestCase extends ImpTestCase {
    _bayeuxClient = null;

    function testDisconnect() {
        // The plan is:
        // 1) Emulate state connected
        // 2) Set the onDisconnected callback to our handler
        // 3) Emulate a pending "extra" http request and a couple of messages in the queue
        // 4) Call disconnect()
        // 5) The lib should:
        //    1) Cancel the "extra" http request and call it's callback with an error
        //    2) Cancel all the messages from the queue and call their callbacks
        //    3) Call the onDisconnected callback

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            const MSG_NUM = 3;

            // Emulation of state connected
            _bayeuxClient._onConnected(null);

            local httpReqCanceled = false;
            local msgCbCallCounter = 0;

            local onDisconnected = function(err) {
                if (httpReqCanceled && msgCbCallCounter == MSG_NUM) {
                    return resolve();
                }
                return reject("Have not got the expected result");
            }.bindenv(this);
            _bayeuxClient.setOnDisconnected(onDisconnected);

            local httpReqCb = function(err) {
                if (err != null &&
                    err.type == BC_ERROR_TYPE.LIBRARY_ERROR &&
                    err.details == BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW) {
                    httpReqCanceled = true;
                }
            }.bindenv(this);

            _bayeuxClient._extraHttpRequest = [http.post("", {}, ""), httpReqCb];

            local msgCb = function(err) {
                if (err != null &&
                    err.type == BC_ERROR_TYPE.LIBRARY_ERROR &&
                    err.details == BC_LIBRARY_ERROR_NOT_CONNECTED) {
                    msgCbCallCounter += 1;   
                }
            }.bindenv(this);

            for (local i = 0; i < MSG_NUM; i += 1) {
                _bayeuxClient._enqueueMessage({}, msgCb);
            }

            _bayeuxClient.disconnect();
        }.bindenv(this));
    }
}