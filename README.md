# BayeuxClient #

This library implements the client side of the [Bayeux protocol](https://docs.cometd.org/current/reference/#_bayeux), allowing your agent code to interact with Bayeux servers.

Bayeux is a protocol for transporting asynchronous messages (primarily over web protocols such as HTTP and WebSocket), with low latency between a web server and web clients.

This version of the library supports the following functionality:
- Connect to a Bayeux server.
- Subscribe to a channel (topic).
- Receive server-to-client messages (events).
- Unsubscribe from a channel (topic).
- Disconnect from the server.

The library currently supports only long-polling transport.

**To add this library to your project, add** `#require "BayeuxClient.agent.lib.nut:1.0.0"` **to the top of your agent code**

## Bayeux.Client Class Usage ##

### Constructor: Bayeux.Client(*configuration[, onConnected][, onDisconnected]*) ###

This method returns a new Bayeux.Client instance.

#### Parameters ####

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| [*configuration*](#configuration-values) | Table | Yes | Key-value table with settings. There are both required and optional settings *(see below)* |
| [*onConnected*](#callback-onconnected) | Function | No | Callback called every time the client is connected |
| [*onDisconnected*](#callback-ondisconnected) | Function | No | Callback called every time the client is disconnected |

#### Return Value ####

A new Bayeux.Client instance.

#### Configuration Values ####

These settings affect the client's behavior.

| Key | Value Type | Required? | Description |
| --- | --- | --- | --- |
| *url* | String | Yes | The URL of the Bayeux server this client will connect to |
| *backoffIncrement* | Integer | No | The number of seconds that the backoff time increments every time a connection with the Bayeux server fails. Bayeux.Client attempts to reconnect after the backoff time elapses. Default: 1 |
| *maxBackoff* | Integer | No | The maximum number of seconds of the backoff time after which the backoff time is not incremented further. Default: 60 |
| *requestTimeout* | Integer | No | The maximum number of seconds to wait before considering that a request to the Bayeux server failed. Default: 10 |
| *requestHeaders* | Table | No | A key-value table containing the request headers to be sent for every Bayeux request, eg. `{ "My-Custom-Header" : "MyValue"}`. Default: `null` |

**Note** For more information on these settings, please see the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

#### Callback: onConnected ####

This callback is called every time the client connects. The client is considered to be connected when the handshake and the first *connect* messages were successful. To learn what handshake and *connect* messages are, please see the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

The callback has one parameter of its own:

| Parameter | Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | This will be `null` if the connection is successful, otherwise an error message string |

#### Callback: onDisconnected ####

This callback is called every time the client disconnects. The client is considered as disconnected if any of the following events occurs:

- The application manually disconnected.
- Sending a *connect* message failed (eg. by request timeout, HTTP error, etc).
- The last *connect* message was unsuccessful, ie. the response's *successful* field is `false`, and has no *reconnect* advice set to `"retry"`.

To learn what a ‘connect’ message is, please see the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

This callback is a good place to call the [*connect()*](#connect) method again if there was an unexpected disconnection.

The callback has one parameter of its own:

| Parameter | Type | Description |
| --- | --- | --- |
| *reason* | [Bayeux.Error](#bayeuxerror-class) | `null` if the disconnection was caused by the [*disconnect()*](#disconnect) method, otherwise an error message string which provides a reason for the disconnection |

#### Example ####

```squirrel
#require "BayeuxClient.agent.lib.nut:1.0.0"

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

config <- { "url" : "yourBayeuxServer.com",
            "requestHeaders": { "Authorization" : "YOUR_UTHORIZATION_HEADER"}
};

// Instantiate and connect a client
client <- Bayeux.Client(config, onConnected, onDisconnected);
client.connect();
```

## Bayeux.Client Class Methods ##

### connect() ###

This method negotiates a connection to the Bayeux server specified in the client [configuration](#configuration-values).

Connection negotiation includes a handshake and the first *connect* message. To learn what handshake and *connect* messages are, please see the [Bayeux protocol specification](https://docs.cometd.org/current/reference/#_bayeux).

#### Return Value ####

Nothing. The result of the operation may be obtained via the [*onConnected*](#callback-onconnected) callback specified in the client's constructor or set by calling [*setOnConnected()*](#setonconnectedcallback).

### disconnect() ###

This method closes the connection to the Bayeux server. Does nothing if the connection is already closed.

#### Return Value ####

Nothing. When the disconnection is completed, the [*onDisconnected*](#callback-ondisconnected) callback is called *(see above)*, if specified in the client's constructor or set by calling [*setOnDisconnected()*](#setondisconnectedcallback).

### isConnected() ###

This method checks if the client is connected to the Bayeux server.

#### Return Value ####

Boolean &mdash; `true` if the client is connected, otherwise `false`.

### subscribe(*topic, handler[, onDone]*) ###

This method attempts to subscribe to the specified topic (channel).

All incoming messages within that topic are passed to the specified handler function. If the client is already subscribed to the specified topic, the method just sets a new handler for that topic.

*subscribe()* can be called for different topics so the client can subscribe to multiple topics. A handler can be used for one or more subscriptions.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *topic* | String  | Yes | The topic to subscribe to. Valid topics should meet [this description](https://docs.cometd.org/current/reference/#_channels) |
| *handler* | Function  | Yes | Function called every time a message within the *topic* is received |
| *onDone* | Function  | No | Callback called when the operation is completed or an error occurs |

#### Callback: handler ####

This function is called every time a message with the topic specified in the *subscribe()* method is received. It has two parameters of its own:

| Parameter | Type | Description |
| --- | --- | --- |
| *topic* | String | A topic ID |
| *message* | Table | The data from a *received* Bayeux message (event), [described here](https://docs.cometd.org/current/reference/#_code_data_code) |

#### Callback: onDone #####

This callback is called when the method completes. It has one parameter of its own:

| Parameter | Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | `null` if the operation is completed successfully, otherwise an error message string |

#### Return Value ####

Nothing. A result of the operation may be obtained via the *onDone* callback if specified.

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

#### Parameters ####

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *topic* | String  | Yes | The topic to unsubscribe from. A valid topic (channel) should meet [this description](https://docs.cometd.org/current/reference/#_channels) |
| *onDone* | Function  | No | Function called when the operation is completed or an error occurs |

#### Callback: onDone #####

This callback is called when a method is completed. It has one parameter of its own:

| Parameter | Data Type | Description |
| --- | --- | --- |
| *error* | [Bayeux.Error](#bayeuxerror-class) | `null` if the operation is completed successfully, otherwise an error message string |

#### Return Value ####

Nothing. A result of the operation may be obtained via the *onDone* callback if specified.

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

This method can be used to set the client’s [*onConnected*](#callback-onconnected) callback. It returns nothing.

### setOnDisconnected(*callback*) ###

This method can be used to set the client’s [*onDisconnected*](#callback-ondisconnected) callback. It returns nothing.

### setDebug(*value*) ###

This method enables (*value* is `true`) or disables (*value* is `false`) the client’s debug output, including error logging. It is disabled by default. The method returns nothing.

## Bayeux.Error Class ##

This class represents an error returned by the library and has the following public properties:

- *type* &mdash; The error type, which is one of the following *BAYEUX_CLIENT_ERROR_TYPE* enum values:
    - *LIBRARY_ERROR* &mdash; The library is wrongly initialized, a method is called when it is not allowed, or an internal error has occurred. The [error code](#library-error-codes) can be found in the *details* property. Usually, this indicates an issue during application development which should be fixed during debugging and therefore should not occur after the application has been deployed.
    - *TRANSPORT_FAILED* &mdash; An HTTP request to the Bayeux server failed. The error code can be found in the *details* property. This is the code returned by the imp API’s [**httprequest.sendasync()**](https://developer.electricimp.com/api/httprequest/sendasync) method. This error may occur during the normal execution of an application. The application logic should process this error.
   - *BAYEUX_ERROR* &mdash; An unexpected response from the Bayeux server or simply unsuccessful Bayeux operation. The error description can be found in the *details* property. It may contain a description provided by the Bayeux server. Generally, it is a human-readable string.
- *details* &mdash; An integer error code or a string containing a description of the error.

## Library Error Codes ##

An *Integer* error code which specifies a concrete library error which occurred during an operation.

| Error Code | Error Name | Description |
| --- | --- | --- |
| 1 | *BC_LIBRARY_ERROR_NOT_CONNECTED* | The client is not connected |
| 2 | *BC_LIBRARY_ERROR_ALREADY_CONNECTED* | The client is already connected |
| 3 | *BC_LIBRARY_ERROR_OP_NOT_ALLOWED_NOW* | The operation is not allowed now, eg. the same operation is already in process |
| 4 | *BC_LIBRARY_ERROR_NOT_SUBSCRIBED* | The client is not subscribed to the topic, eg. it is impossible to unsubscribe from a topic the client is not subscribed to |

## Cookies ##

Cookie handling support is limited: all cookie attributes are ignored. The library has only been tested with the [Salesforce platform](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_subscribe_cometd.htm).

## Examples ##

Working examples are provided in the [examples](./examples) directory and described [here](./examples/README.md).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory and described [here](./tests/README.md).

## License ##

The BayeuxClient library is licensed under the [MIT License](./LICENSE)
