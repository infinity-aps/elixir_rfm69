defmodule RFM69 do
  @moduledoc false

  alias ElixirALE.{GPIO, SPI}
  alias RFM69.RFConfiguration

  def start_link(spi_device) do
    reset_pin     = 24
    {:ok, pid} = SPI.start_link(spi_device, speed_hz: 6_000_000)
    #{:ok, reset_pid} = GPIO.start_link(reset_pin, :output)
    #GPIO.write(reset_pid, 0)
    #{:ok, pid}
  end

  def write_configuration(pid, rf_config = %RFConfiguration{}) do
    <<_::8, response::binary>> = SPI.transfer(pid, <<0x81>> <> RFConfiguration.to_binary(rf_config))
    IO.puts Base.encode16(response)
    response
  end

  def read_configuration(pid) do
    size_bits = byte_size(RFConfiguration.to_binary(%RFConfiguration{})) * 8
    binary = <<0x01::8, 0x00::size(size_bits)>>
    <<_::8, response::binary>> = SPI.transfer(pid, binary)
    IO.puts Base.encode16(response)
    response
  end

  def read_hardware_version(pid) do
    <<_::8, version::4, metal_mask::4>> = SPI.transfer(pid, <<0x1000::16>>)
    IO.puts "Version: #{version}, Metal Version: #{metal_mask}"
    version
  end
end
