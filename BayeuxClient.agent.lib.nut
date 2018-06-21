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


// BayeuxClient is an Electric Imp agent-side library for interacting with Bayeux servers

// BayeuxClient library error types
enum BC_ERROR_TYPE {
    LIBRARY_ERROR,
    TRANSPORT_FAILED,
    BAYEUX_ERROR
}

// Error codes for errors of LIBRARY_ERROR type
const BC_LIBRARY_ERROR_NOT_CONNECTED         = 1;
const BC_LIBRARY_ERROR_ALREADY_CONNECTED     = 2;
const BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW    = 3;
const BC_LIBRARY_ERROR_NOT_SUBSCRIBED        = 4;

class Bayeux {
    static VERSION = "1.0.0";
}

class Bayeux.Client {
    _debugEnabled           = false;

    _isDisconnected         = true;
    _isDisconnecting        = false;
    _isConnected            = false;
    _isConnecting           = false;

    _onConnectedCb          = null;
    _onDisconnectedCb       = null;

    _configuration          = null;
    // It contains some useful information came from Bayeux server about what client should do
    _advice                 = null;
    _backoff                = 0;
    _curMsgId               = 1;
    _clientId               = null;
    _cookies                = null;

    // Topic -> handler for user messages (events)
    _userHandlers           = null;

    // Id -> handler for meta messages
    _metaHandlers           = null;

    // A timer for delayed connection
    _reconnectTimer         = null;
    // Bayeux protocol recommeds to keep at most 2 open HTTP requests from client to server.
    // So we have "connect" and "extra" requests.
    // The "connect" (heartbeat) request is open and waiting for a response almost all the time.
    _connectHttpRequest     = null;
    // A dedicated HTTP request to a server.
    // The "extra" request allows to send messages without waiting the "connect" request to be answered.
    // Array [<httprequest>, <callback>].
    _extraHttpRequest       = null;
    // Array of arrays [<message>, <callback>]. Here we keep messages waiting the "extra" request to be free.
    _messageQueue           = null;


    // Bayeux Client class constructor.
    //
    // Parameters:
    //     configuration : Table        Key-value table with settings. There are required and optional settings.
    //     onConnected : Function       Callback called every time the client is connected.
    //          (optional)              The callback signature:
    //                                  onConnected(error), where
    //                                      error :             null if the connection is successful, error details otherwise.
    //                                          Bayeux.Error
    //     onDisconnected : Function    Callback called every time the client is disconnected.
    //          (optional)              The callback signature:
    //                                  onDisconnected(reason), where
    //                                      reason :            null if the disconnection was caused by the disconnect() method,
    //                                          Bayeux.Error    error details which explains a reason of the disconnection otherwise.
    //
    // Returns:                         Bayeux.Client instance created.
    constructor(configuration, onConnected = null, onDisconnected = null) {
        // Library defaults
        const DEFAULT_REQUEST_TIMEOUT             = 10;
        const DEFAULT_ADVICE_TIMEOUT              = 60;
        const DEFAULT_ADVICE_INTERVAL             = 0;
        const DEFAULT_BACKOFF_INCREMENT           = 1;
        const DEFAULT_BACKOFF_MAXIMUM             = 60;

        const PROTOCOL_VERSION                    = "1.0";
        const LONGPOLL_TRANSPORT_NAME             = "long-polling";

        const META_CHANNEL_HANDSHAKE              = "/meta/handshake";
        const META_CHANNEL_CONNECT                = "/meta/connect";
        const META_CHANNEL_DISCONNECT             = "/meta/disconnect";
        const META_CHANNEL_SUBSCRIBE              = "/meta/subscribe";
        const META_CHANNEL_UNSUBSCRIBE            = "/meta/unsubscribe";

        // Indexes
        const REQUEST_INDEX = 0;
        const CALLBACK_INDEX = 1;
        const MESSAGE_INDEX = 0;

        _configuration = {
            "requestHeaders" : {},
            "requestTimeout" : DEFAULT_REQUEST_TIMEOUT,
            "backoffIncrement" : DEFAULT_BACKOFF_INCREMENT,
            "maxBackoff" : DEFAULT_BACKOFF_MAXIMUM
        }
        foreach (k, v in configuration) {
            _configuration[k] <- v;
        }

        _onConnectedCb = onConnected;
        _onDisconnectedCb = onDisconnected;

        _init();
    }

    // Negotiates a connection to the Bayeux server specified in the configuration.
    //
    // Returns:                         Nothing.
    function connect() {
        if (_isConnected || _isConnecting) {
            local errorCode = _isConnected ? BC_LIBRARY_ERROR_ALREADY_CONNECTED : BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW;
            _onConnectedCb && _onConnectedCb(Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, errorCode));
            return;
        }

        _isConnecting = true;

        local handshakeDone = function (error) {
            if (error == null) {
                _connect(true);
            } else {
                _onConnected(error);
            }
        }.bindenv(this);

        _handshake(handshakeDone);
    }

    // Closes the connection to the Bayeux server. Does nothing if the connection is already closed.
    //
    // Returns:                         Nothing.
    function disconnect() {
        if (_isConnecting) {
            _onDisconnected(null);
            return;
        } else if (_isDisconnected || _isDisconnecting) {
            return;
        }

        _isDisconnecting = true;

        local msgId = _nextMessageId();
        local message = {
            "id" : msgId,
            "clientId" : _clientId,
            "channel" : META_CHANNEL_DISCONNECT
        }

        local sent = function(error) {
            _onDisconnected(null);
        }.bindenv(this);

        // Cancel current request and send "disconnect" immediately
        if (_extraHttpRequest != null) {
            _extraHttpRequest[REQUEST_INDEX].cancel();
            _extraHttpRequest[CALLBACK_INDEX](Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW));
            _extraHttpRequest = null;
        }
        _send(message, sent);
    }

    // Checks if the client is connected to the Bayeux server.
    //
    // Returns:                         Boolean: true if the client is connected, false otherwise.
    function isConnected() {
        return _isConnected;
    }

    // Makes a subscription to the specified topic (channel).
    //
    // Parameters:
    //     topic : String               The topic to subscribe to. Valid topic (channel) should meet the Bayeux protocol description.
    //     handler : Function           Callback called every time a message with the topic is received.
    //                                  The callback signature:
    //                                  handler(topic, message), where
    //                                      topic : String      Topic id.
    //                                      message : Table     The data from received Bayeux message (event).
    //     onDone : Function            Callback called when the operation is completed or an error occurs.
    //          (optional)              The callback signature:
    //                                  onDone(error), where
    //                                      error :             null if the operation is completed successfully, error details otherwise.
    //                                          Bayeux.Error
    //
    // Returns:                         Nothing.
    function subscribe(topic, handler, onDone = null) {
        if (!_isConnected || _isDisconnecting) {
            local errorCode = _isConnected ? BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW : BC_LIBRARY_ERROR_NOT_CONNECTED;
            onDone && onDone(Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, errorCode));
            return;
        }

        // Already subscribed
        if (topic in _userHandlers) {
            _setTopicHandler(topic, handler);
            onDone && onDone(null);
            return;
        }

        local msgId = _nextMessageId();
        local message = {
            "id" : msgId,
            "clientId" : _clientId,
            "channel" : META_CHANNEL_SUBSCRIBE,
            "subscription" : topic
        }

        local onResponse = function(response) {
            _onSubscribeResponse(response, topic, handler, onDone);
        }.bindenv(this);

        _metaHandlers[msgId] <- onResponse;

        local sent = function(error) {
            if (error != null) {
                if (msgId in _metaHandlers) {
                    delete _metaHandlers[msgId];
                }
                onDone && onDone(error);
            }
        }.bindenv(this);

        _enqueueMessage(message, sent);
    }

    // Unsubscribes from the specified topic.
    //
    // Parameters:
    //     topic : String               The topic to unsubscribe from.
    //     onDone : Function            Callback called when the operation is completed or an error occurs.
    //          (optional)              The callback signature:
    //                                  onDone(error), where
    //                                      error :             null if the operation is completed successfully, error details otherwise.
    //                                          Bayeux.Error
    //
    // Returns:                         Nothing.
    function unsubscribe(topic, onDone = null) {
        if (!_isConnected || _isDisconnecting) {
            local errorCode = _isConnected ? BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW : BC_LIBRARY_ERROR_NOT_CONNECTED;
            onDone && onDone(Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, errorCode));
            return;
        }

        // Not subscribed
        if (!(topic in _userHandlers)) {
            onDone && onDone(Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, BC_LIBRARY_ERROR_NOT_SUBSCRIBED));
            return;
        }

        local msgId = _nextMessageId();
        local message = {
            "id" : msgId,
            "clientId" : _clientId,
            "channel" : META_CHANNEL_UNSUBSCRIBE,
            "subscription" : topic
        }

        local onResponse = function(response) {
            _onUnsubscribeResponse(response, topic, onDone);
        }.bindenv(this);

        _metaHandlers[msgId] <- onResponse;

        local sent = function(error) {
            if (error != null) {
                if (msgId in _metaHandlers) {
                    delete _metaHandlers[msgId];
                }
                onDone && onDone(error);
            }
        }.bindenv(this);

        _enqueueMessage(message, sent);
    }

    // Sets onConnected callback.
    //
    // Parameters:
    //     onConnected : Function       Callback called every time the client is connected.
    //                                  The callback signature:
    //                                  onConnected(error), where
    //                                      error :             null if the connection is successful, error details otherwise.
    //                                          Bayeux.Error
    //
    // Returns:                         Nothing.
    function setOnConnected(callback) {
        _onConnectedCb = callback;
    }

    // Sets onDisconnected callback.
    //
    // Parameters:
    //     onDisconnected : Function    Callback called every time the client is disconnected.
    //                                  The callback signature:
    //                                  onDisconnected(reason), where
    //                                      reason :            null if the disconnection was caused by the disconnect() method,
    //                                          Bayeux.Error    error details which explains a reason of the disconnection otherwise.
    //
    // Returns:                         Nothing.
    function setOnDisconnected(callback) {
        _onDisconnectedCb = callback;
    }

    // Enables or disables the client debug output. Disabled by default.
    //
    // Parameters:
    //     value : Boolean              true to enable, false to disable
    //
    // Returns:                         Nothing.
    function setDebug(value) {
        _debugEnabled = value;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _init() {
        _cookies = {
            // TODO: We should get this cookie from Bayeux server
            // Waiting for EI to fix the issue with Set-Cookie headers
            "BAYEUX_BROWSER" : "BAYEUX_BROWSER=" + imp.configparams.deviceid
        }

        _advice = {
            "timeout" : DEFAULT_ADVICE_TIMEOUT * 1000,
            "interval" : DEFAULT_ADVICE_INTERVAL * 1000
        }
        _userHandlers = {};
        _metaHandlers = {};
        _messageQueue = [];
    }

    function _handleMessages(messages) {
        // We should update the advice before the sort
        foreach (msg in messages) {
            _updateAdvice(msg);
        }

        // We have to sort messages because of two cases:
        // 1) We can receive events for the topic we subscribed to WITH the response for this subscription
        // 2) We can receive events for the topic we unsubscribed from WITH the response for this unsubscription
        // So for the case 1 we want to call the users's subscription callback firstly and then handle the events
        // For the case 2 we want to handle the events firstly and then call the user's unsubscription callback
        _sortMessages(messages);
        foreach (msg in messages) {
            _log("Handling message:");
            _logTable(msg);

            if (msg["channel"].find("/meta/") == 0 && "id" in msg) {
                local msgId = msg["id"];
                if (msgId in _metaHandlers) {
                    local handler = delete _metaHandlers[msgId];
                    handler(msg);
                }
            // After the _sortMessages() we have only messages that have "channel" field
            } else if (msg["channel"].find("/meta/") != 0 && "data" in msg) {
                // msg is not a meta message
                _onUserMessage(msg);
            } else {
                // msg is a meta message so it MUST have "id" or msg is a user event so it MUST have "data"
                _logError("Invalid Bayeux message!");
            }
        }
    }

    function _sortMessages(messages) {
        local subscribes = [];
        local unsubscribes = [];
        local others = [];
        foreach (msg in messages) {
            if (!("channel" in msg)) {
                _logTable(msg);
                _logError("Message does not have \"channel\" field!");
                continue;
            }
            if (msg["channel"].find(META_CHANNEL_SUBSCRIBE) == 0) {
                subscribes.append(msg);
            } else if (msg["channel"].find(META_CHANNEL_UNSUBSCRIBE) == 0) {
                unsubscribes.append(msg);
            } else {
                others.append(msg);
            }
        }
        messages.clear();
        messages.extend(subscribes);
        messages.extend(others);
        messages.extend(unsubscribes);
    }

    function _onUserMessage(message) {
        local channelPart = "";
        // For example: message["channel"] = "/a/b/c". Then channelParts = ["a", "b", "c"]
        local channelParts = split(message["channel"], "/");
        // Example: partsNum = 3
        local partsNum = channelParts.len();
        local channelLen = 0;
        local builtChannel = null;
        // Example: 3 iterations
        foreach (part in channelParts) {
            // Example:
            // 1-st iter: channelPart = "/a", channelLen = 1
            // 2-nd iter: channelPart = "/a/b", channelLen = 2
            // 3-rd iter: channelPart = "/a/b/c", channelLen = 3
            channelPart += "/" + part;
            channelLen++;
            // Example: this branch on the 3-rd iteration
            if (channelLen == partsNum) {
                // Example: builtChannel = "/a/b/c"
                builtChannel = channelPart;
            // Example: this branch on the 2-nd iteration
            } else if (channelLen == partsNum - 1) {
                // Example: builtChannel = "/a/b/*"
                builtChannel = channelPart + "/*";

                if (builtChannel in _userHandlers) {
                    _userHandlers[builtChannel](message["channel"], message["data"]);
                }

                // Example: builtChannel = "/a/b/**"
                builtChannel += "*";
            // Example: this branch on the 1-st iteration
            } else {
                // Example: builtChannel = "/a/**"
                builtChannel = channelPart + "/**";
            }

            if (builtChannel in _userHandlers) {
                _userHandlers[builtChannel](message["channel"], message["data"]);
            }
        }
    }

    function _handshake(callback) {
        local msgId = _nextMessageId();
        local message = {
            "id" : msgId,
            "version" : PROTOCOL_VERSION,
            "minimumVersion" : PROTOCOL_VERSION,
            "channel" : META_CHANNEL_HANDSHAKE,
            "supportedConnectionTypes" : [LONGPOLL_TRANSPORT_NAME],
            "advice" : {
                "timeout" : _advice.timeout,
                "interval" : _advice.interval
            }
        }

        local onResponse = function(response) {
            _onHandshakeResponse(response, callback);
        }.bindenv(this);

        _metaHandlers[msgId] <- onResponse;

        local sent = function(error) {
            if (error != null) {
                if (msgId in _metaHandlers) {
                    delete _metaHandlers[msgId];
                }
                callback(error);
            }
        }.bindenv(this);

        // We can send it directly without the queue because it should be the first message
        // and the other messages are not allowed before the handshake
        _send(message, sent);
    }

    function _onHandshakeResponse(response, callback) {
        _log("Handshake response received:");
        _logTable(response);

        if (!_checkSuccessfulField(response, callback)) {
            return;
        }

        local success = response["successful"];

        if (success && "clientId" in response) {
            _clientId = response["clientId"];
            callback(null);
            return;
        }
        local errMsg = null;

        if (success) {
            // "clientId" NOT in response
            errMsg = "Handshake response does not have \"clientId\" field!";
            _logError(errMsg);
        } else if ("error" in response) {
            errMsg = response["error"];
        } else {
            errMsg = "Handshake was unsuccessful, but response does not have \"error\" field!";
            _logError(errMsg);
        }
        callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, errMsg));
    }

    // establish = true, if we are establishing a new connection
    // establish = false, if we are maintaining the established connection by sending a heartbeat message
    function _connect(establish = false) {
        _reconnectTimer = null;

        local msgId = _nextMessageId();
        local message = {
            "id" : msgId,
            "clientId" : _clientId,
            "channel" : META_CHANNEL_CONNECT,
            "connectionType" : LONGPOLL_TRANSPORT_NAME,
            "advice" : {
                "timeout" : establish ? 0 : _advice.timeout
            }
        }

        local onResponse = _onReconnectResponse;

        if (establish) {
            onResponse = _onConnectResponse;
        }

        _metaHandlers[msgId] <- onResponse.bindenv(this);

        local sent = function(error) {
            if (error != null) {
                if (msgId in _metaHandlers) {
                    delete _metaHandlers[msgId];
                }
                if (establish) {
                    _onConnected(error);
                } else {
                    _onDisconnected(error);
                }
            }
        }.bindenv(this);

        _send(message, sent, true);
    }

    function _onConnectResponse(response, establish = true) {
        _log("Connect response received:");
        _logTable(response);

        local callback = null;

        if (establish) {
            // Connection is being established now
            callback = _onConnected;
        } else {
            // Connection has been established and now we are maintaining it
            // In case of any error we will call _onDisconnected
            callback = _onDisconnected;
        }

        if (!_checkSuccessfulField(response, callback)) {
            return;
        }

        if (response["successful"]) {
            if (!_isDisconnecting) {
                // _advice.interval is in msecs, so we need to convert it to secs
                _delayedReconnect(_advice.interval / 1000.0);
            }
            if (establish) {
                callback(null);
            }
            return;
        }

        local reconnectAdvice = null;
        if ("advice" in response && "reconnect" in response["advice"]) {
            reconnectAdvice = response["advice"]["reconnect"]
        }

        if (reconnectAdvice == "retry") {
            // We can reconnect automatically
            if (!_isDisconnecting) {
                // _advice.interval is in msecs, so we need to convert it to secs
                _delayedReconnect(_advice.interval / 1000.0 + _backoff, establish);
                _increaseBackoff();
            }
            return;
        }

        // We can't reconnect automatically
        if ("error" in response) {
            callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, response["error"]));
        } else {
            callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR,
                "Connection failed, but response does not have \"error\" field!"));
        }
    }

    function _onReconnectResponse(response) {
        _onConnectResponse(response, false);
    }

    // delay in seconds
    function _delayedReconnect(delay, establish = false) {
        local reconnect = _connect;
        if (establish) {
            reconnect = function() {
                _connect(true);
            };
        }
        _reconnectTimer = imp.wakeup(delay, reconnect.bindenv(this));
    }

    function _onSubscribeResponse(response, topic, handler, callback) {
        _log("Subscribe response received:");
        _logTable(response);

        _checkSuccessfulField(response, callback);

        if (response["successful"]) {
            _setTopicHandler(topic, handler);
            callback && callback(null);
            return;
        }

        if ("error" in response) {
            callback && callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, response["error"]));
        } else {
            callback && callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR,
                "Subscription failed, but response does not have \"error\" field!"));
        }
    }

    function _onUnsubscribeResponse(response, topic, callback) {
        _log("Unsubscribe response received:");
        _logTable(response);

        _checkSuccessfulField(response, callback);

        if (response["successful"]) {
            _setTopicHandler(topic, null);
            callback && callback(null);
            return;
        }

        if ("error" in response) {
            callback && callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, response["error"]));
        } else {
            callback && callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR,
                "Unsubscription failed, but response does not have \"error\" field!"));
        }
    }

    function _checkSuccessfulField(response, callback) {
        if (!("successful" in response)) {
            local errMsg = "Response does not have \"successful\" field!";
            _logError(errMsg);
            callback && callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, errMsg));
            return false;
        }
        return true;
    }

    function _increaseBackoff() {
        _backoff += _configuration.backoffIncrement;
        if (_backoff > _configuration.maxBackoff) {
            _backoff = _configuration.maxBackoff;
        }
    }

    function _resetBackoff() {
        _backoff = 0;
    }

    function _onConnected(error) {
        if (error == null) {
            _isConnected = true;
            _isDisconnected = false;
            _log("Connected!");
        }
        _isConnecting = false;
        _onConnectedCb && _onConnectedCb(error);
    }

    function _onDisconnected(reason) {
        _log("Disconnected!");
        _cleanup();
        _onDisconnectedCb && _onDisconnectedCb(reason);
    }

    function _cleanup() {
        _isConnecting       = false;
        _isConnected        = false;
        _isDisconnecting    = false;
        _isDisconnected     = true;

        if (_reconnectTimer != null) {
            imp.cancelwakeup(_reconnectTimer);
            _reconnectTimer = null;
        }

        if (_connectHttpRequest != null) {
            _connectHttpRequest.cancel();
            _connectHttpRequest = null;
        }
        if (_extraHttpRequest != null) {
            _extraHttpRequest[REQUEST_INDEX].cancel();
            _extraHttpRequest[CALLBACK_INDEX](Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, BC_LIBRARY_ERROR_NOT_CONNECTED));
            _extraHttpRequest = null;
        }

        foreach (msgCb in _messageQueue) {
            // msgCb is an array [<message>, <callback>]
            msgCb[CALLBACK_INDEX](Bayeux.Error(BC_ERROR_TYPE.LIBRARY_ERROR, BC_LIBRARY_ERROR_NOT_CONNECTED));
        }

        _curMsgId = 1;
        _clientId = null;
        _backoff = 0;
        _init();
    }

    function _setTopicHandler(topic, handler) {
        if (handler != null) {
            _log("Setting a handler for \"" + topic + "\" topic");
            _userHandlers[topic] <- handler;
        } else if (topic in _userHandlers) {
            _log("Unsetting a handler for \"" + topic + "\" topic");
            delete _userHandlers[topic];
        } else {
            _logError("Topic's handler cannot be null");
        }
    }

    function _nextMessageId() {
        _curMsgId %= 65536;
        return "" + _curMsgId++;
    }

    // message : Table
    function _updateAdvice(message) {
        local newAdvice = "advice" in message ? message["advice"] : null;

        if (newAdvice != null) {
            foreach (k, v in newAdvice) {
                _advice[k] <- v;
            }
        } else {
            return;
        }

        if ("interval" in newAdvice) {
            _resetBackoff();
        }

        _log("Advice updated:");
        _logTable(_advice);
    }

    function _enqueueMessage(message, callback) {
        if (_extraHttpRequest == null && _messageQueue.len() == 0) {
            _send([message], callback);
        } else {
            _messageQueue.push([message, callback]);
        }
    }

    function _processQueue() {
        // We have a free request
        if (!_isDisconnecting && _extraHttpRequest == null && _messageQueue.len() > 0) {
            // msgCb is an array [<message>, <callback>]
            local msgCb = _messageQueue.remove(0);
            _send([msgCb[MESSAGE_INDEX]], msgCb[CALLBACK_INDEX]);
        }
    }

    function _send(message, callback, connect = false) {
        local headers = {
            "Content-Type" : "application/json;charset=UTF-8"
        }

        foreach (k, v in _configuration.requestHeaders) {
            headers[k] <- v;
        }

        foreach (name, cookie in _cookies) {
            if (!("Cookie" in headers)) {
                headers["Cookie"] <- "";
            }
            headers["Cookie"] += cookie + "; ";
        }

        local jsonMsg = null;
        try {
            jsonMsg = http.jsonencode(message);
        } catch (e) {
            _logError("Cannot convert message to JSON string: " + e);
            return;
        }

        _log("Sending message: " + jsonMsg);

        local httpRequest = http.post(_configuration.url, headers, jsonMsg);
        if (connect) {
            _connectHttpRequest = httpRequest;
        } else {
            _extraHttpRequest = [httpRequest, callback];
        }

        local sent = function(response) {
            _onSent(response, callback, connect);
        }.bindenv(this);

        local timeout = _configuration.requestTimeout;
        if (connect) {
            // _advice.timeout is in msec, so we need to convert it to sec
            timeout += _advice.timeout / 1000.0;
        }

        httpRequest.sendasync(sent, null, timeout);
    }

    function _onSent(response, callback, connect) {
        if (connect) {
            _connectHttpRequest = null;
        } else {
            _extraHttpRequest = null;
        }

        _log("Response received:");
        _logTable(response);

        if (!_statusIsOk(response.statuscode)) {
            callback(Bayeux.Error(BC_ERROR_TYPE.TRANSPORT_FAILED, response.statuscode));
            _processQueue();
            return;
        }

        // TODO: Handle the cookies properly
        // Waiting for EI to fix the issue with Set-Cookie headers
        foreach (k, v in response.headers) {
            if (k.tolower() == "set-cookie") {
                try {
                    local cookieName = split(v, "=")[0];
                    _cookies[cookieName] <- v;
                } catch(e) {
                    _logError(e);
                }
            }
        }

        local tableMsg = null;
        try {
            tableMsg = http.jsondecode(response.body);
        } catch (e) {
            _logError("Response body is not a valid JSON: " + e);
            _logError("Message: " + response.body);
            callback(Bayeux.Error(BC_ERROR_TYPE.BAYEUX_ERROR, "Response body is not a valid JSON: " + e));
            _processQueue();
            return;
        }

        if (tableMsg != null) {
            callback(null);
            _handleMessages(tableMsg);
        }

        _processQueue();
    }

    // Check HTTP status
    function _statusIsOk(status) {
        return status / 100 == 2;
    }

    function _logTable(tbl) {
        if (!_debugEnabled) {
            return;
        }

        local text = "";
        foreach (k, v in tbl) {
            text += k + " : " + v + "\n";
        }

        _log(text);
    }

    // Metafunction to return class name when typeof <instance> is run
    function _typeof() {
        return "BayeuxClient";
    }

     // Information level logger
    function _log(txt) {
        if (_debugEnabled) {
            server.log("[" + (typeof this) + "] " + txt);
        }
    }

    // Error level logger
    function _logError(txt) {
        if (_debugEnabled) {
            server.error("[" + (typeof this) + "] " + txt);
        }
    }
}

class Bayeux.Error {
    type = null;
    details = null;

    constructor(type, details = null) {
        this.type = type;
        this.details = details;
    }
}
