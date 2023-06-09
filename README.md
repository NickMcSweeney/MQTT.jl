# MQTTClient.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NickMcSweeney.github.io/MQTTClient.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NickMcSweeney.github.io/MQTTClient.jl/dev/)
[![Build Status](https://github.com/NickMcSweeney/MQTTClient.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/NickMcSweeney/MQTTClient.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/NickMcSweeney/MQTTClient.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/NickMcSweeney/MQTTClient.jl)
[![Coverage](https://coveralls.io/repos/github/NickMcSweeney/MQTTClient.jl/badge.svg?branch=main)](https://coveralls.io/github/NickMcSweeney/MQTTClient.jl?branch=main)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

MQTT Client Library for Julia

This library provides a powerful and easy-to-use interface for connecting to an MQTT broker, publishing messages, and subscribing to topics to receive published messages. It supports fully multi-threaded operation with Dagger.jl and file persistence for reliable message delivery.


Contents
--------
 * [Installation](#installation)
 * [Testing](#testing)
 * [Usage](#usage)
    * [Getting started](#getting-started)
        * [Basic example](#basic-example)
    * [Client struct](#client-struct)
        * [Constructors](#constructors)
    * [Message struct](#message-struct)
        * [Constructors](#constructors-1)
    * [Connect](#connect)
        * [Arguments](#arguments)
        * [Call example](#call-example)
        * [Synchronous connect](#synchronous-connect)
        * [Asynchronous connect](#asynchronous-connect)
    * [Publish](#publish)
        * [Arguments](#arguments-1)
        * [Call example](#call-example-1)
        * [Synchronous publish](#synchronous-publish)
        * [Asynchronous publish](#asynchronous-publish)
    * [Subscribe](#subscribe)
        * [Arguments](#arguments-2)
        * [Call example](#call-example-2)
        * [Synchronous subscribe](#synchronous-subscribe)
        * [Asynchronous subscribe](#asynchronous-subscribe)
    * [Unsubscribe](#unsubscribe)
        * [Arguments](#arguments-3)
        * [Call example](#call-example-3)
        * [Synchronous unsubscribe](#synchronous-unsubscribe)
        * [Asynchronous unsubscribe](#asynchronous-unsubscribe)
    * [Disconnect](#disconnect)
        * [Arguments](#arguments-4)
        * [Call example](#call-example-4)
        * [Synchronous disconnect](#synchronous-disconnect)
 * [Internal workings](#internal-workings)

Installation
------------
```julia
Pkg.clone("https://github.com/NickMcSweeney/MQTTClient.jl.git")
```
Testing
-------
```julia
Pkg.test("MQTTClient")
```
Usage
-----
Import the library with the `using` keyword.

Samples are available in the `examples` directory.
```julia
using MQTTClient
```

Advanced Usage
--------------
True multi-threading is available via Dagger.jl and will be enabled if Julia is run with more than 1 thread enabled.

```bash
julia -t 2
```
The _read_loop_, _write_loop_ _keep_alive_loop_, and _on_msg_ callback are all called as scheduled processes via `Dagger.@spawn` rather than `@async`. 
This is work in progress, so it is not 100% stable. 
Also based on testing, for simple/low load networks it is slower to run it threaded than to run async (probably because there is more overhead managing threads).

## Getting started
To use this library you need to follow at least these steps:
1. Define an `on_msg` callback function for a given topic.
2. Create an instance of the `Client` struct.
3. Call the connect method with your `Client` instance.
4. Exchange data with the broker through publish, subscribe and unsubscribe. When subscribing, pass your `on_msg` function for that topic.
5. Disconnect from the broker. (Not strictly necessary, if you don't want to resume the session but considered good form and less likely to crash).

#### Basic example
Refer to the corresponding method documentation to find more options.

```julia
using MQTTClient
broker = "test.mosquitto.org"

#Define the callback for receiving messages.
function on_msg(topic, payload)
    info("Received message topic: [", topic, "] payload: [", String(payload), "]")
end

#Instantiate a client.
client = Client()
connect(client, broker, 1883)
#Set retain to true so we can receive a message from the broker once we subscribe
#to this topic.
publish(client, "jlExample", "Hello World!", retain=true)
#Subscribe to the topic we sent a retained message to.
subscribe(client, "jlExample", on_msg, qos=QOS_1))
#Unsubscribe from the topic
unsubscribe(client, "jlExample")
#Disconnect from the broker. Not strictly needed as the broker will also
#disconnect us if the socket is closed. But this is considered good form
#and needed if you want to resume this session later.
disconnect(client)
```

## Client struct
The client struct is used to store state for an MQTT connection. All callbacks, apart from `on_message`, can't be set through the constructor and have to be set manually after instantiating the `Client` struct.

**Fields in the Client that are relevant for the library user:**
* **ping_timeout**::UInt64: Time, in seconds, the Client waits for the PINGRESP after sending a PINGREQ before he disconnects ; *default = 60 seconds*
* **on_message**::Function: This function gets called upon receiving a publish message from the broker.
* **on_disconnect**::Function:
* **on_connect**::Function:
* **on_subscribe**::Function:
* **on_unsubscribe**::Function:

##### Constructors

```julia
Client()
```

Specify a custom ping_timeout
```julia
Client(ping_timeout::UInt64 = 10)
```

Use the wrapping function. this is equivalent to using the Client constructor; but with more specific syntax.
```julia
MQTTConnection()
```

## Message struct
The `Message` struct is the data structure for generic MQTT messages. This is mostly used internally but is exposed to the user in some cases for easier to read arguments (Passing a "will" to the connect method uses the `Message` struct for example).

#### Constructors
This is a reduced constructor meant for messages that can't be duplicate or retained (like the "will"). **This message constructor should be in most cases!** The dup and retained flag are false by default.

```julia
function Message(qos::QOS, topic::String, payload...)
```

This is the full `Message` constructor. It has all possible fields.

```julia
function Message(dup::Bool, qos::QOS, retain::Bool, topic::String, payload...)
```

This constructor is mostly for internal use. It uses the `UInt8` equivalent of the `QOS` enum for easier processing.

```julia
function Message(dup::Bool, qos::UInt8, retain::Bool, topic::String, payload...)
```

## Connect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718028)

Connects the `Client` instance to the specified broker. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The client to connect to the broker.
* **host**::AbstractString: The hostname or ip address of the broker.

**Optional arguments:**
* **port**::Integer: The port to use ; *default = 1883*
* **keep_alive**::Int64: If the client hasn't sent or received a message within this time limit, it will ping the broker to verify the connection is still active. A value of 0 means no pings will be sent. ; *default = 0*
* **client_id**::String: The id of the client. This should be unique per broker. Some brokers allow an empty client_id for a stateless connection (this means clean_session needs to be true). ; *default = random 8 char string*
* **user**::User: The user, password pair for authentication with the broker. Password can be empty even if user isn't. The password should probably be encrypted. ; *default = empty pair*  
* **will**::Message: The will of this client. This message gets published on the specified topic once the client disconnects from the broker. The type of this argument is `Message`, consult with it's documentation above for more info. ; *default = empty will*
* **clean_session**::Bool: Specifies whether or not a connection should be resumed. This implies this `Client` instance was previously connected to this broker. ; *default = true*

#### Call example
The dup and retain flag of a will have to be false so it's safest to use the minimal `Message` constructor (Refer to `Message` documentation above).

```julia
connect(c, "test.mosquitto.org", keep_alive=60, client_id="TestClient", user=User("name", "pw"), will=Message(QOS_2, "TestClient/will", "payload", more_payload_data))
```

#### Synchronous connect
This method waits until the client is connected to the broker. TODO add return documentation

```julia
function connect(client::Client, host::AbstractString, port::Integer=1883;
keep_alive::Int64=0,
client_id::String=randstring(8),
user::User=User("", ""),
will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
clean_session::Bool=true)
```

#### Asynchronous connect
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the client is fully connected. TODO add future data documentation

```julia
function connect_async(client::Client, host::AbstractString, port::Integer=1883;
keep_alive::Int64=0,
client_id::String=randstring(8),
user::User=User("", ""),
will::Message=Message(false, 0x00, false, "", Array{UInt8}()),
clean_session::Bool=true)
```

## Publish
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718037)

Publishes a message to the broker connected to the `Client` instance provided as a parameter. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The client to send the message over.
* **topic**::String: The topic to publish on. Normal rules for publish topics apply so "/ are allowed but no wildcards.
* **payload**::Any...: Can be several parameters with potentially different types. Can also be empty.

**Optional arguments:**
* **dup**::Bool: Tells the broker that the message is a duplicate. This should not be used under normal circumstances as the library handles this. ; *default = false*
* **qos**::QOS: The MQTT quality of service to use for the message. This has to be a QOS constant (QOS_0, QOS_1, QOS_2). ; *default = QOS_0*
* **retain**::Bool: Whether or not the message should be retained by the broker. This means the broker sends it to all clients who subscribe to this topic ; *default = false*

#### Call example
These are valid `payload...` examples.
```julia
publish(c, "hello/world")
publish(c, "hello/world", "Test", 6, 4.2)
```

This is a valid use of the optional arguments.
```julia
publish(c, "hello/world", "Test", 6, 4.2, qos=QOS_1, retain=true)
```

#### Synchronous publish
This method waits until the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received. TODO add return documentation

```julia
function publish(client::Client, topic::String, payload...;
    dup::Bool=false,
    qos::UInt8=0x00,
    retain::Bool=false)
```

#### Asynchronous publish
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the publish message has been processed completely and successfully. So in case of QOS 2 it waits until the PUBCOMP has been received. TODO change future data documentation

```julia
function publish_async(client::Client, topic::String, payload...;
    dup::Bool=false,
    qos::UInt8=0x00,
    retain::Bool=false)
```

## Subscribe
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718063)

Subscribes the `Client` instance, provided as a parameter, to the specified topics. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The connected client to subscribe on. TODO phrasing?
* **topic**::String: The name of the topic.
* **on_msg**::Function: the callback function for that topic.
* **qos**::QOS: the named argument to set the QOS, defaults to QOS_0.

#### Call example
This example subscribes to the topic "test" with QOS_2 and "test2" with QOS_0.
```julia
subscribe(c, "test", ((t,p)->do_a_thing(p)), qos=QOS_2))
```

#### Synchronous subscribe
This method waits until the subscribe message has been successfully sent and acknowledged. TODO add return documentation

```julia
subscribe(c, "test", on_msg, qos=QOS_2))
```

#### Asynchronous subscribe
This method doesn't wait and returns a `Future` object. You may choose to wait on this object. This future completes once the subscribe message has been successfully sent and acknowledged. TODO change future data documentation

```julia
function subscribe_async(c, "test", on_msg, qos=QOS_2))
```

## Unsubscribe
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718072)

This method unsubscribes the `Client` instance from the specified topics. There is a synchronous and an asynchronous version available. Both versions take the same arguments.

#### Arguments
**Required arguments:**
* **client**::Client: The connected client to unsubscribe from the topics.
* **topics**::String...: The `Tuple` of topics to unsubscribe from.

#### Example call
```julia
unsubscribe(c, "test1", "test2", "test3")
```

#### Synchronous unsubscribe
This method waits until the unsubscribe method has been sent and acknowledged. TODO add return documentation

```julia
function unsubscribe(client::Client, topics::String...)
```

#### Asynchronous unsubscribe
This method doesn't wait and returns a `Future` object. You may wait on this object with the fetch method. This future completes once the unsubscribe message has been sent and acknowledged. TODO add future data documentation

```julia
function unsubscribe_async(client::Client, topics::String...)
```

## Disconnect
[MQTT v3.1.1 Doc](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718090)

Disconnects the `Client` instance gracefully, shuts down the background tasks and stores session state. There is only a synchronous version available.

#### Arguments
**Required arguments:**
* **client**::Client: The client to disconnect.

#### Example call
```julia
disconnect(c)
```

#### Synchronous disconnect
```julia
function disconnect(client::Client))
```
Internal workings
-----------------
It isn't necessary to read this section if you just want to use this library but it might give additional insight into how everything works.

The `Client` instance has a `Channel`, called `write_packets`, to keep track of outbound messages that still need to be sent. Julia channels are basically just blocking queues so they have exactly the behavior we want.

For storing messages that are awaiting acknowledgment, `Client` has a `Dict`, mapping message ids to `Future` instances. These futures get completed once the message has been completely acknowledged. There might then be information in the `Future` relevant to the specific message.

Once the connect method is called on a `Client`, relevant fields are initialized and the julia `connect` method is called to get a connected socket. Then two background tasks are started that perpetually check for messages to send and receive. If `keep_alive` is non-zero another tasks get started that handles sending the keep alive and verifying the pingresp arrived in time.

TODO explain read and write loop a bit

## Contributing

This package's development is sponsored by [MapXact](mapxact.com/) and used in production systems at MapXact. However, this is an open source project, and contrubutions and feature requests are welcome. 

### TODO

- [ ] Review examples
- [ ] protocol error handling
- [ ] reconnect
- [ ] persistence (in memory, files)
- [ ] look at enums and how to use them
- [ ] qos2 
    * separate handle_pubrecrel into two different methods and fix them
- [ ] fix connect method
    * make it not hardcoded
- [ ] disconnect_async/disconnect
    * think about what we need to do and how
    * the reconnect should still work
- [ ] implement clean session = false