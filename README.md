# BayeuxClient #

This library implements the client side of [Bayeux protocol](https://docs.cometd.org/current/reference/#_bayeux) and allows your agent code to interact with Bayeux servers.

This version of the library supports the following functionality:
- Connect to Bayeux server
- Subscribe to a channel (topic)
- Receive server-to-client messages (events)
- Unsubscribe from a channel (topic)
- Disconnect from the server

The library supports only long-polling transport now.

**To add this library to your project, add** `#require "BayeuxClient.agent.lib.nut:1.0.0"` **to the top of your agent code**

## Library Usage ##

## Bayeux.Client Class ##

### Constructor: Bayeux.Client(*configuration[, onConnected[, onDisconnected]]*) ###

This method returns a new Bayeux.Client instance.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| [*configuration*](#configuration) | Table | Yes | Key-value table with settings. There are required and optional settings. |
| [*onConnected*](#callback-onconnectederror) | Function | Optional | Callback called every time the client is connected. |
| [*onDisconnected*](#callback-ondisconnectedreason) | Function | Optional | Callback called every time the client is disconnected. |

#### Callback: onConnected(*error*) ####

This callback is called every time the client is connected.

The client is considered as connected when the handshake and the first "connect" messages were successful. To learn what handshake and "connect" messages are, please read the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | null if the connection is successful, error details otherwise. |

#### Callback: onDisconnected(*reason*) ####

This callback is called every time the client is disconnected.

The client is considered as disconnected if any of these events occurs:
- disconnection was caused by application
- sending of "connect" message is failed (e.g., request timeout, HTTP error)
- the last "connect" message is unsuccessful (response's "successful" field is "false") and has no "reconnect" advice set to "retry"

To learn what "connect" message is, please read the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

This is a good place to call the [connect()](#connect) method again if it was an unexpected disconnection.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *reason* | [Bayeux.Error](#bayeuxerror-class) | null if the disconnection was caused by the [disconnect()](#disconnect) method, error details which explains a reason of the disconnection otherwise. |

#### Configuration ####

These settings affect the client's behavior and the operations.

| Key (String) | Value Type | Required? | Default | Description |
| --- | --- | --- | --- | --- |
| "url" | String | Yes | - | The URL of the Bayeux server this client will connect to. |
| "backoffIncrement" | Integer | Optional | 1 | The number of seconds that the backoff time increments every time a connection with the Bayeux server fails. BayeuxClient attempts to reconnect after the backoff time elapses. |
| "maxBackoff" | Integer | Optional | 60 | The maximum number of seconds of the backoff time after which the backoff time is not incremented further. |
| "requestTimeout" | Integer | Optional | 10 | The maximum number of seconds to wait before considering a request to the Bayeux server failed. |
| "requestHeaders" | Table | Optional | 10 | A key-value table containing the request headers to be sent for every Bayeux request (for example, {"My-Custom-Header":"MyValue"}). |

**Note**: please read the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux) to understand these parameters better.

#### Example ####

```squirrel
function onConnected(error) {
    if (error != null) {
        server.error("Сonnection failed");
        server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
        return;
    }
    server.log("Connected!");
    // Here is a good place to make required subscriptions
}

function onDisconnected(error) {
    if (error != null) {
        server.error("Disconnected unexpectedly with error:");
        server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
        // Reconnect if disconnection is not initiated by application
        client.connect();
    } else {
        server.log("Disconnected by application");
    }
}

config <- {
    "url" : "yourBayeuxServer.com",
    "requestHeaders": {
        "Authorization" : "<Your authorization header if needed>"
    }
};

// Instantiate and connect a client
client <- Bayeux.Client(config, onConnected, onDisconnected);
client.connect();
```

### connect() ###

This method negotiates a connection to the Bayeux server specified in the [configuration](#configuration).

Connection negotiation includes handshake and the first "connect" messages. To learn what handshake and "connect" messages are, please read the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

The method returns nothing. A result of the operation may be obtained via the [*onConnected*](#callback-onconnectederror) callback specified in the client's constructor or set by calling [setOnConnected()](#setonconnectedcallback) method.

### disconnect() ###

This method closes the connection to the Bayeux server. Does nothing if the connection is already closed.

The method returns nothing. When the disconnection is completed the [*onDisconnected*](#callback-ondisconnectedreason) callback is called, if specified in the client's constructor or set by calling [setOnDisconnected()](#setondisconnectedcallback) method.

### isConnected() ###

This method checks if the client is connected to the Bayeux server.

The method returns *Boolean*: `true` if the client is connected, `false` otherwise.

### subscribe(*topic, handler[, onDone]*) ###

This method makes a subscription to the specified topic (channel).

All incoming messages with that topic are passed to the specified handler. If the subscription is already made this method just sets new handler for that subscription.

The [subscribe()](#subscribetopic-handler-ondone) method can be called for different topics so the client can be subscribed to multiple topics. Any handler can be used for one or several subscriptions.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *topic* | String  | Yes | The topic to subscribe to. Valid topic (channel) should meet [this description](https://docs.cometd.org/current/reference/#_channels). |
| *[handler](#callback-handlertopic-message)* | Function  | Yes | Callback called every time a message with the *topic* is received. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | Callback called when the operation is completed or an error occurs. |

#### Callback: handler(*topic, message*) ####

This callback is called every time a message with the topic specified in the [subscribe()](#subscribetopic-handler-ondone) method is received.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *topic* | String | Topic id. |
| *message* | Table | The data from received Bayeux message (event). [Described here](https://docs.cometd.org/current/reference/#_code_data_code). |

#### Callback: onDone(*error*) #####

This callback is called when a method is completed.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | null if the operation is completed successfully, error details otherwise. |

#### Example ####

```squirrel
function handler(topic, msg) {
    server.log(format("Event received from %s channel: %s", topic, http.jsonencode(msg)));
}

function onDone(error) {
    if (error != null) {
        server.error("Subscribing failed:");
        server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
    } else {
        server.log("Successfully subscribed");
    }
}

client.subscribe("/example/topic", handler, onDone);
```

### unsubscribe(*topic[, onDone]*) ###

This method unsubscribes from the specified topic.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *topic* | String  | Yes | The topic to unsubscribe from. Valid topic (channel) should meet [this description](https://docs.cometd.org/current/reference/#_channels). |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | Callback called when the operation is completed or an error occurs. |

#### Callback: onDone(*error*) #####

This callback is called when a method is completed.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | null if the operation is completed successfully, error details otherwise. |

#### Example ####

```squirrel
function onDone(error) {
    if (error != null) {
        server.error("Unsubscribing failed:");
        server.error(format("Error type: %d, details: %s", error.type, error.details.tostring()));
    } else {
        server.log("Successfully unsubscribed");
    }
}

client.unsubscribe("/example/topic", onDone);
```

### setOnConnected(*callback*) ###

This method sets [*onConnected*](#callback-onconnectederror) callback. The method returns nothing.

### setOnDisconnected(*callback*) ###

This method sets [*onDisconnected*](#callback-ondisconnectedreason) callback. The method returns nothing.

### setDebug(*value*) ###

This method enables (*value* is `true`) or disables (*value* is `false`) the client debug output (including error logging). It is disabled by default. The method returns nothing.

## Bayeux.Error Class ##

This class represents an error returned by the library and has the following public properties:
- *type* &mdash; The error type, which is one of the following *BAYEUX_CLIENT_ERROR_TYPE* enum values:
    - *LIBRARY_ERROR* &mdash; The library is wrongly initialized, a method is called when it is not allowed, or an internal error has occurred. The [error code](#library-error-codes) can be found in the *details* property. Usually, this indicates an issue during application development which should be fixed during debugging and therefore should not occur after the application has been deployed.
    - *TRANSPORT_FAILED* &mdash; An HTTP request to the Bayeux server failed. The error code can be found in the *details* property. This is the code returned by [Imp's HTTP API](https://developer.electricimp.com/api/httprequest/sendasync). This error may occur during the normal execution of an application. The application logic should process this error.
   - *BAYEUX_ERROR* &mdash; An unexpected response from the Bayeux server or simply unsuccessful Bayeux operation. The error description can be found in the *details* property. It may contain a description provided by the Bayeux server. Generally, it is a human-readable string.
- *details* &mdash; An integer error code or a string containing a description of the error.

### Library Error Codes ###

An *Integer* error code which specifies a concrete LIBRARY error (if any) happened during an operation.

| Error Code | Description |
| --- | --- |
| 1 | The client is not connected. |
| 2 | The client is already connected. |
| 3 | The operation is not allowed now. E.g. the same operation is already in process. |
| 4 | The client is not subscribed to the topic. E.g. it is impossible to unsubscribe from the topic the client is not subscribed to. |

## Examples ##

Working examples are provided in the [examples](./examples) directory and described [here](./examples/README.md).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory and described [here](./tests/README.md).

## License ##

The BayeuxClient library is licensed under the [MIT License](./LICENSE)
