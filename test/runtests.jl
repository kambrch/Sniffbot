using Test
using Sniffbot

@testset "parse_sensor_id" begin
    @test parse_sensor_id("tele/tasmota_F847F7/SENSOR") == "tasmota_F847F7"  # nominal
    @test parse_sensor_id("tele/other/deep/topic")      == "other"           # extra segments
    @test parse_sensor_id("notopic")                    == "notopic"         # no slash — fallback
    @test parse_sensor_id("")                           == ""                # empty — fallback
    @test parse_sensor_id("/SENSOR")                    == "/SENSOR"         # empty segment — fallback
end
