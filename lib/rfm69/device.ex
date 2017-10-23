defmodule RFM69.Device do
  @moduledoc """
  `RFM69.Device` is a GenServer to manage the SPI, reset and receive interrupt pids state and provide functions for reading and writing the registers and the FIFO buffer.
  """

  use Bitwise
  use GenServer

  require Logger

  alias ElixirALE.{GPIO, SPI}
  alias RFM69.Configuration

  @doc """
  Accepts the SPI device (eg "spidev0.0"), the reset and interrupt GPIO pin numbers and initializes communication with
  the RFM69 chip.
  """
  def start_link(spi_device, reset_pin, interrupt_pin) do
    GenServer.start_link(__MODULE__, [spi_device, reset_pin, interrupt_pin], name: __MODULE__)
  end

  @doc """
  Initializes the SPI device and the reset and interrupt pins and prepares the RFM69 chip for interaction.
  """
  def init([spi_device, reset_pin, interrupt_pin]) do
    with {:ok, spi_pid} <- SPI.start_link(spi_device, speed_hz: 6_000_000),
         {:ok, reset_pid} <- GPIO.start_link(reset_pin, :output),
         {:ok, interrupt_pid} <- GPIO.start_link(interrupt_pin, :input),
         :ok <- GPIO.write(reset_pid, 0) do
      {:ok, %{spi_pid: spi_pid, reset_pid: reset_pid, interrupt_pid: interrupt_pid}}
    else
      error ->
        message = "The SPI RFM69 chip interface failed to start"
        {:error, message}
    end
  end

  @doc """
  Read burst operations happen similarly to `write_burst`, where the first byte is the register location, and each
  subsequent byte sent (the value of the tx byte doesn't matter) results in a byte read with the value of that register
  location using the same auto-incrementing as in writes.
  """
  @spec read_burst(byte, pos_integer) :: {:ok, binary}
  def read_burst(location, byte_count) do
    GenServer.call(__MODULE__, {:read_burst, location, byte_count})
  end

  @doc """
  Read single is a subtype of `read_burst` where only the location byte and a "don't care" byte are sent in the frame
  and the second byte returned is the register value.
  """
  @spec read_single(byte) :: {:ok, byte}
  def read_single(location) do
    {:ok, <<value::8>>} = read_burst(location, 1)
    {:ok, value}
  end

  @doc """
  Writing to one or more configuration register locations is done via a "write burst", where the first byte transferred
  over SPI is the location logically ORed with 0x80 (the write bit), the second byte is the value for that register
  location, and each subsequent sent byte is stored in the proceeding register locations. The RFM69 chip auto-increments
  the register location for each byte so that a single frame of bytes can write the entire register configuration.
  """
  @spec write_burst(byte, binary) :: :ok
  def write_burst(location, data), do: GenServer.call(__MODULE__, {:write_burst, location, data})

  @doc """
  Write single is a subtype of `write_burst` where only the location byte and a single value byte are sent in the frame.
  """
  @spec write_single(byte, byte) :: :ok
  def write_single(location, data), do: write_burst(location, <<data::8>>)

  @doc """
  Sets the reset GPIO pin high long enough to power cycle the RFM69 chip
  """
  @spec reset() :: :ok
  def reset, do: GenServer.call(__MODULE__, {:reset})

  @doc """
  Sets the receive pin interrupt so that the next incoming packet triggers an `{:ok, :interrupt_received}` message to
  the caller so that the fifo buffer can be processed to decode the packet.
  """
  @spec await_interrupt() :: :ok
  def await_interrupt, do: GenServer.call(__MODULE__, {:await_interrupt})

  @doc """
  Cancels the recieve pin interrupt. The interrupt is canceled under normal conditions when a response message is
  triggered, but in the case of a timeout where the caller no longer has interest in the next packet, this function can
  be used.
  """
  @spec cancel_interrupt() :: :ok
  def cancel_interrupt, do: GenServer.call(__MODULE__, {:cancel_interrupt})

  @configuration_start 0x01
  @doc """
  Writes a full configuration struct to the registers on the chip.
  """
  @spec write_configuration(Configuration.t) :: :ok
  def write_configuration(rf_config = %Configuration{}) do
    configuration_bytes = Configuration.to_binary(rf_config)
    :ok = write_burst(@configuration_start, configuration_bytes)
  end

  @frf_location 0x07
  @doc """
  Sets the frequency to the appropriate chip registers
  """
  @spec write_frequency(pos_integer) :: {:ok}
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
