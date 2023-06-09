module MQTTClient

using Distributed: Future, RemoteChannel
using Dagger
using Sockets: TCPSocket
import Sockets: connect
using Random: randstring
import Base: ReentrantLock, lock, unlock, convert
using Base.Threads

include("utils.jl")
include("client.jl")
include("handlers.jl")
include("interface.jl")
# include("precompile.jl")

export
    Client,
    MQTTConnection,
    User,
    QOS_0,
    QOS_1,
    QOS_2,
    connect_async,
    connect,
    subscribe_async,
    subscribe,
    unsubscribe_async,
    unsubscribe,
    publish_async,
    publish,
    disconnect,
    MQTT_ERR_INVAL
end
