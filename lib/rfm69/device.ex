defmodule RFM69.Device do
  @moduledoc false

  use Bitwise
  use GenServer

  require Logger

  alias ElixirALE.{GPIO, SPI}
  alias RFM69.Configuration

  def start_link(spi_device, reset_pin, interrupt_pin) do
    GenServer.start_link(__MODULE__, [spi_device, reset_pin, interrupt_pin], name: __MODULE__)
  end

  def init([spi_device, reset_pin, interrupt_pin]) do
    with {:ok, spi_pid} <- SPI.start_link(spi_device, speed_hz: 6_000_000),
         {:ok, reset_pid} <- GPIO.start_link(reset_pin, :output),
         {:ok, interrupt_pid} <- GPIO.start_link(interrupt_pin, :input),
         :ok <- GPIO.write(reset_pid, 0) do
      {:ok, %{spi_pid: spi_pid, reset_pid: reset_pid, interrupt_pid: interrupt_pid}}
    else
      error ->
        message = "The SPI RFM69 chip interface failed to start"
        Logger.error(fn -> "#{message}: #{inspect(error)}" end)
        {:error, message}
    end
  end

  def read_single(location) do
    {:ok, <<value::8>>} = read_burst(location, 1)
    value
  end

  def read_burst(location, byte_count),
    do: GenServer.call(__MODULE__, {:read_burst, location, byte_count})

  def write_burst(location, data), do: GenServer.call(__MODULE__, {:write_burst, location, data})
  def write_single(location, data), do: write_burst(location, <<data::8>>)
  def reset, do: GenServer.call(__MODULE__, {:reset})
  def await_interrupt, do: GenServer.call(__MODULE__, {:await_interrupt})
  def cancel_interrupt, do: GenServer.call(__MODULE__, {:cancel_interrupt})

  @configuration_start 0x01
  def write_configuration(rf_config = %Configuration{}) do
    configuration_bytes = Configuration.to_binary(rf_config)
    :ok = write_burst(@configuration_start, configuration_bytes)
  end

  @frf_location 0x07
  def write_frequency(frequency_in_hz) do
    register_values = Configuration.frequency_to_registers(frequency_in_hz)
    register_bytes = <<register_values::24>>
    :ok = write_burst(@frf_location, register_bytes)
    {:ok}
  end

  def handle_call({:reset}, _from, state = %{reset_pid: reset_pid}) do
    GPIO.write(reset_pid, 1)
    :timer.sleep(1)
    GPIO.write(reset_pid, 0)
    :timer.sleep(5)
    {:reply, :ok, state}
  end

  @write_mode 0x80
  def handle_call({:write_burst, location, data}, _from, state = %{spi_pid: spi_pid}) do
    tx_bytes = <<@write_mode ||| location::8>> <> data
    SPI.transfer(spi_pid, tx_bytes)
    {:reply, :ok, state}
  end

  def handle_call({:read_burst, location, byte_count}, _from, state = %{spi_pid: spi_pid}) do
    size_bits = byte_count * 8
    tx_bytes = <<location::8, 0x00::size(size_bits)>>
    <<_::8, rx_bytes::binary>> = SPI.transfer(spi_pid, tx_bytes)
    {:reply, {:ok, rx_bytes}, state}
  end

  def handle_call({:await_interrupt}, {sender, _}, state = %{interrupt_pid: interrupt_pid}) do
    GPIO.set_int(interrupt_pid, :rising)
    {:reply, :ok, Map.put(state, :awaiting_interrupt, sender)}
  end

  def handle_call({:cancel_interrupt}, {_, _}, state = %{interrupt_pid: interrupt_pid}) do
    GPIO.set_int(interrupt_pid, :none)
    {:reply, :ok, Map.delete(state, :awaiting_interrupt)}
  end

  def handle_info(
        {:gpio_interrupt, _, :rising},
        state = %{awaiting_interrupt: awaiting_interrupt, interrupt_pid: interrupt_pid}
      ) do
    GPIO.set_int(interrupt_pid, :none)
    send(awaiting_interrupt, {:ok, :interrupt_received})
    {:noreply, Map.delete(state, :awaiting_interrupt)}
  end

  def handle_info({:gpio_interrupt, _, _}, state) do
    {:noreply, state}
  end
end
