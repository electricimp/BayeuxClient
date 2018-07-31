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

class ProcessQueueTestCase extends ImpTestCase {
    _bayeuxClient = null;
    _msgCbCallCounter = 0

    function testProcessQueue() {
        // The plan is:
        // 1) Emulate state connected
        // 2) Emulate a couple of messages in the queue
        // 3) Call _processQueue()
        // 4) The lib should:
        //    1) Try to send each request from the queue
        //    2) Get an error from http API for each request
        //    3) Call all the callbacks passed for the messages with that error

        _bayeuxClient = Bayeux.Client({"url" : ""});
        return Promise(function (resolve, reject) {
            const MSG_NUM = 10;

            // Emulation of state connected
            _bayeuxClient._onConnected(null);

            for (local i = 1; i <= MSG_NUM; i += 1) {
                _bayeuxClient._messageQueue.push([{}, _createCallback(resolve, i).bindenv(this)]);
            }

            _bayeuxClient._processQueue();
        }.bindenv(this));
    }

    function _createCallback(resolve, i) {
        return function (err) {
            if (err != null &&
                err.type == BC_ERROR_TYPE.TRANSPORT_FAILED) {
                _msgCbCallCounter += i;
                if (_msgCbCallCounter == (MSG_NUM + 1) * MSG_NUM / 2) {
                    return resolve();
                }
            }
        }
    }
}