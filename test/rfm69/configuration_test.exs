defmodule RFM69.RFConfigurationTest do
  use ExUnit.Case, async: true

  alias RFM69.RFConfiguration

  test "to_binary returns correct information" do
    # This is a correctness test, which ought to be able to go away once the
    # other behavior tests are in place. For now, it holds the configuration
    # constant to a known good register configuration

    test_configuration = %RFConfiguration{
      frf: RFConfiguration.frequency_to_registers(916_600_000),
      bitrate: RFConfiguration.bitrate_to_registers(16_384),
      data_modul: 0x08,
      pa_level: 0x5F,
      lna: 0x88,
      # 250kHz with dcc freq shift 2, RxBwMant of 16 and RxBwExp of 0
      rx_bw: 0x40,
      # dcc freq shift of 4
      afc_bw: 0x80,
      dio_mapping1: 0x80,
      dio_mapping2: 0x07,
      rssi_thresh: 0xE4,
      preamble: 0x0018,
      sync_config: 0x98,
      sync_value: 0xFF00FF0001010101,
      packet_config1: 0x00,
      payload_length: 0x00,
      fifo_thresh: 0x94,
      packet_config2: 0x00
    }

    {:ok, expected_bytes} =
      Base.decode16(
        "00040807A10052E5266641000292F520245F091A40B07B9B884080408006100000000002FF80078000E40000001898FF00FF000101010100000000009400000000000000000000000000000000000100"
      )

    assert expected_bytes == RFConfiguration.to_binary(test_configuration)
  end
end
