using Test
using Sniffbot

@testset "parse_sensor_id" begin
    @test parse_sensor_id("tele/tasmota_F847F7/SENSOR") == "tasmota_F847F7"
    @test parse_sensor_id("tele/tasmota_AABBCC/SENSOR") == "tasmota_AABBCC"
    @test parse_sensor_id("tele/other/deep/topic")      == "other"
    @test parse_sensor_id("notopic")                    == "notopic"   # fallback
end
