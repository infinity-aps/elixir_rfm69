defmodule RFM69.Device do
  @moduledoc """
  `RFM69.Device` is a GenServer to manage the SPI, reset and receive interrupt pids state and provide functions for reading and writing the registers and the FIFO buffer.
  """

  use Bitwise
  use GenServer

  require Logger

  alias ElixirALE.{GPIO, SPI}

  defstruct name: nil, device: nil, reset_pin: nil, interrupt_pin: nil
  @type t :: %RFM69.Device{name: :atom, device: String.t, reset_pin: integer, interrupt_pin: integer}

  @hardware_version 0x10

  @doc """
  Accepts the SPI device (eg "spidev0.0"), the reset and interrupt GPIO pin numbers and initializes communication with
  the RFM69 chip.
  """
  def start_link(%RFM69.Device{name: name, device: device, reset_pin: reset_pin, interrupt_pin: interrupt_pin}) do
    GenServer.start_link(__MODULE__, [device, reset_pin, interrupt_pin], name: name)
  end

  @doc """
  Initializes the SPI device and the reset and interrupt pins and prepares the RFM69 chip for interaction.
  """
  def init([spi_device, reset_pin, interrupt_pin]) do
    with {:ok, spi_pid} <- SPI.start_link(spi_device, speed_hz: 6_000_000),
         {:ok, reset_pid} <- GPIO.start_link(reset_pin, :output),
         {:ok, interrupt_pid} <- GPIO.start_link(interrupt_pin, :input),
         :ok <- GPIO.write(reset_pid, 0),
         {:ok, <<0x24>>} <- _read_burst(spi_pid, @hardware_version, 1) do

      {:ok, %{spi_pid: spi_pid, reset_pid: reset_pid, interrupt_pid: interrupt_pid}}
    else
      error ->
        message = "The SPI RFM69 chip interface failed to start: #{inspect error}"
        {:error, message}
    end
  end

  def chip_present?(%RFM69.Device{device: device}) do
    case SPI.start_link(device, speed_hz: 6_000_000) do
      {:ok, spi_pid} ->
        found = {:ok, <<0x24>>} == _read_burst(spi_pid, @hardware_version, 1)
        SPI.release(spi_pid)
        found
      _error -> false
    end
  end

  @doc """
  Sets the reset GPIO pin high long enough to power cycle the RFM69 chip
  """
  def handle_call({:reset}, _from, state = %{reset_pid: reset_pid}) do
    GPIO.write(reset_pid, 1)
    :timer.sleep(1)
    GPIO.write(reset_pid, 0)
    :timer.sleep(5)
    {:reply, :ok, state}
  end

  @doc """
  Writing to one or more configuration register locations is done via a "write burst", where the first byte transferred
  over SPI is the location logically ORed with 0x80 (the write bit), the second byte is the value for that register
  location, and each subsequent sent byte is stored in the proceeding register locations. The RFM69 chip auto-increments
  the register location for each byte so that a single frame of bytes can write the entire register configuration.
  """
  def handle_call({:write_burst, location, data}, _from, state = %{spi_pid: spi_pid}) do
    {:reply, _write_burst(spi_pid, location, data), state}
  end

  @doc """
  Read burst operations happen similarly to `write_burst`, where the first byte is the register location, and each
  subsequent byte sent (the value of the tx byte doesn't matter) results in a byte read with the value of that register
  location using the same auto-incrementing as in writes.
  """
  def handle_call({:read_burst, location, byte_count}, _from, state = %{spi_pid: spi_pid}) do
    {:reply, _read_burst(spi_pid, location, byte_count), state}
  end

  @doc """
  Sets the receive pin interrupt so that the next incoming packet triggers an `{:ok, :interrupt_received}` message to
  the caller so that the fifo buffer can be processed to decode the packet.
  """
  def handle_call({:await_interrupt}, {sender, _}, state = %{interrupt_pid: interrupt_pid}) do
    GPIO.set_int(interrupt_pid, :rising)
    {:reply, :ok, Map.put(state, :awaiting_interrupt, sender)}
  end

  @doc """
  Cancels the receive pin interrupt. The interrupt is canceled under normal conditions when a response message is
  triggered, but in the case of a timeout where the caller no longer has interest in the next packet, this function can
  be used.
  """
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

  @write_mode 0x80
  defp _write_burst(spi_pid, location, data) do
    tx_bytes = <<@write_mode ||| location::8>> <> data
    SPI.transfer(spi_pid, tx_bytes)
    :ok
  end

  defp _read_burst(spi_pid, location, byte_count) do
    size_bits = byte_count * 8
    tx_bytes = <<location::8, 0x00::size(size_bits)>>
    <<_::8, rx_bytes::binary>> = SPI.transfer(spi_pid, tx_bytes)
    {:ok, rx_bytes}
  end
end
