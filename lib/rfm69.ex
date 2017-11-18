defmodule RFM69 do
  use Bitwise

  alias RFM69.Device
  alias RFM69.Configuration

  @moduledoc false
  @fifo_size 66
  @transfer_sleep trunc(@fifo_size / 4)

  @doc """
  Sets the base frequency of the RFM69 chip in MHz
  """
  @frf_location 0x07
  @spec set_base_frequency(Device.t, pos_integer) :: {:ok}
  def set_base_frequency(%Device{name: name}, mhz) do
    frequency_in_hz = trunc(mhz * 1_000_000)
    register_values = Configuration.frequency_to_registers(frequency_in_hz)
    register_bytes = <<register_values::24>>
    :ok = GenServer.call(name, {:write_burst, @frf_location, register_bytes})
    {:ok}
  end

  @doc """
  reads a frame of binary data from the chip's FIFO queue
  """
  @spec read(Device.t, non_neg_integer) :: {:ok, %{data: binary, rssi: number}} | {:error, any()}
  def read(%Device{name: name}, timeout_ms) do
    set_auto_modes(name, [])
    set_mode(name, :receiver)
    GenServer.call(name, {:await_interrupt})

    result =
      receive do
        {:ok, :interrupt_received} ->
          rssi = read_rssi(name)
          bytes = read_until_null(name, <<>>)
          {:ok, %{data: bytes, rssi: rssi}}
      after
        timeout_ms ->
          GenServer.call(name, {:cancel_interrupt})
          {:error, :timeout}
      end

    set_mode(name, :sleep)
    result
  end

  @doc """
  Writes a frame of binary data to the FIFO queue
  """
  @spec write(Device.t, binary, pos_integer, non_neg_integer, non_neg_integer, boolean) :: {:ok, <<>>}
  def write(chip = %Device{name: name}, packet_bytes, repetitions, repetition_delay, timeout_ms, initial \\ true) do
    if initial == true do
      clear_fifo(name)
      set_mode(name, :standby)
    end

    case repetitions do
      r when r >= 1 ->
        _write(name, packet_bytes, timeout_ms)
        :timer.sleep(repetition_delay)
        write(chip, packet_bytes, repetitions - 1, repetition_delay, timeout_ms, false)

      0 ->
        set_mode(name, :sleep)
        {:ok, ""}
    end
  end

  @doc """
  Writes the given binary data to the FIFO queue and waits for the response.
  """
  @spec write_and_read(Device.t, binary, non_neg_integer) :: {:ok, %{data: binary, rssi: number}} | {:error, any()}
  def write_and_read(chip = %Device{}, packet_bytes, timeout_ms) do
    write(chip, packet_bytes, 1, 0, timeout_ms)
    read(chip, timeout_ms)
  end

  @spec clear_buffers(Device.t) :: :ok
  def clear_buffers(%Device{name: name}) do
    clear_fifo(name)
  end

  @doc """
  Writes a full configuration struct to the registers on the chip.
  """
  @configuration_start 0x01
  @spec write_configuration(Device.t, RFM69.Configuration.t) :: :ok
  def write_configuration(%Device{name: name}, rf_config = %Configuration{}) do
    configuration_bytes = Configuration.to_binary(rf_config)
    :ok = GenServer.call(name, {:write_burst, @configuration_start, configuration_bytes})
  end

  defp _write(name, packet_bytes, _timeout_ms) do
    modes = [:enter_condition_fifo_not_empty, :exit_condition_fifo_empty, :intermediate_mode_tx]
    set_auto_modes(name, modes)
    transmit(name, packet_bytes, @fifo_size)
  end

  defp read_until_null(name, data) do
    case GenServer.call(name, {:read_burst, 0x00, 1}) do
      {:ok, <<0x00::8>>} -> data
      {:ok, <<byte::8>>} -> read_until_null(name, data <> <<byte::8>>)
    end
  end

  defp transmit(name, bytes, available_buffer_bytes) when byte_size(bytes) <= available_buffer_bytes do
    _transmit(name, bytes)
    wait_for_mode(name, :standby)
  end

  defp transmit(name, bytes, available_buffer_bytes) do
    <<transmit_now::binary-size(available_buffer_bytes), transmit_later::binary>> = bytes
    available_buffer_bytes = _transmit(name, transmit_now)
    transmit(name, transmit_later, available_buffer_bytes)
  end

  defp _transmit(name, bytes) do
    GenServer.call(name, {:write_burst, 0x00, bytes})
    :timer.sleep(@transfer_sleep)
    wait_for_buffer_to_become_available(name)
  end

  @reg_irq_flags2 0x28
  @fifo_overrun 0x10
  defp clear_fifo(name) do
    GenServer.call(name, {:write_burst, @reg_irq_flags2, <<@fifo_overrun::8>>})
  end

  @fifo_level 0x20
  defp fifo_threshold_exceeded?(name) do
    {:ok, <<byte::8>>} = GenServer.call(name, {:read_burst, @reg_irq_flags2, 1})
    (byte &&& @fifo_level) != 0x00
  end

  defp wait_for_buffer_to_become_available(name) do
    case fifo_threshold_exceeded?(name) do
      true -> wait_for_buffer_to_become_available(name)
      false -> nil
    end
  end

  @reg_op_mode 0x01
  @modes %{
    sequencer_off: 0x80,
    listen_on:     0x40,
    listen_abort:  0x20,
    mode_shift:    0x02,
    mode_mask:     0x1C,
    sleep:         0x00,
    standby:       0x04,
    freq_synth:    0x08,
    transmitter:   0x0C,
    receiver:      0x10
  }
  defp set_mode(name, mode) do
    mode = Map.get(@modes, mode)
    current_mode = get_mode(name)

    case mode do
      ^current_mode -> true
      _ ->
        GenServer.call(name, {:write_burst, @reg_op_mode, <<mode::8>>})
        wait_for_mode_ready(name, mode)
    end
  end

  defp get_mode(name) do
    {:ok, <<byte>>} = GenServer.call(name, {:read_burst, @reg_op_mode, 1})
    byte
  end

  defp wait_for_mode(name, mode) do
    mode = Map.get(@modes, mode)
    _wait_for_mode(name, mode)
  end

  defp _wait_for_mode(name, mode) do
    if get_mode(name) != mode do
      :timer.sleep(1)
      _wait_for_mode(name, mode)
    end
  end

  @reg_auto_modes 0x3B
  @auto_modes %{
    enter_condition_fifo_not_empty: 0x20,
    exit_condition_fifo_empty:      0x04,
    intermediate_mode_tx:           0x03
  }
  defp set_auto_modes(name, modes) do
    register_value =
      modes
      |> Enum.map(fn mode -> @auto_modes[mode] end)
      |> Enum.reduce(0x00, &(&1 ||| &2))

    GenServer.call(name, {:write_burst, @reg_auto_modes, <<register_value::8>>})
  end

  @reg_irq_flags1 0x27
  @mode_ready     0x80
  defp wait_for_mode_ready(name, mode) do
    {:ok, <<current_mode>>} = GenServer.call(name, {:read_burst, @reg_op_mode, 1})
    {:ok, <<irq_flags1>>} = GenServer.call(name, {:read_burst, @reg_irq_flags1, 1})
    mode_ready = (irq_flags1 &&& @mode_ready) != 0x00

    case current_mode == mode && mode_ready do
      true -> true
      false -> wait_for_mode_ready(name, mode)
    end
  end

  @reg_rssi_val 0x24
  defp read_rssi(name) do
    {:ok, <<raw_rssi::8>>} = GenServer.call(name, {:read_burst, @reg_rssi_val, 1})
    -1 * trunc(raw_rssi) / 2
  end
end
