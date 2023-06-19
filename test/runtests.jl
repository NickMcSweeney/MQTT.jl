using Test

using MQTTClient
using Distributed, Random

import MQTTClient: topic_wildcard_len_check, filter_wildcard_len_check, MQTTException
import Sockets: TCPSocket, connect


println("ENV Vars: ")
for (k,v) in ENV
    println("$k => $v")
end

@testset verbose=true "client tests" begin
include("unittest.client.jl")
end
@testset verbose=true "utils tests" begin
include("unittest.utils.jl")
end

## Needs to have internet connection to run
# include("smoke.jl")
## !TODO: Fix packet tests for full unit testing
# include("mocksocket.jl")
# include("packet.jl")