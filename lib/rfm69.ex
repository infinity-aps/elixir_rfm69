defmodule RFM69 do
  use Bitwise

  @device RFM69.Device
  @moduledoc false
  @fifo_size 66
  @transfer_sleep trunc(@fifo_size / 4)

  @doc """
  Sets the base frequency of the RFM69 chip in MHz
  """
  @spec set_base_frequency(pos_integer) :: {:ok}
  def set_base_frequency(mhz) do
    @device.write_frequency(trunc(mhz * 1_000_000))
  end

  @doc """
  reads a frame of binary data from the chip's FIFO queue
  """
  @spec read(non_neg_integer) :: {:ok, %{data: binary, rssi: number}} | {:error, any()}
  def read(timeout_ms) do
    set_auto_modes([])
    set_mode(:receiver)
    @device.await_interrupt()

    result =
      receive do
        {:ok, :interrupt_received} ->
          rssi = read_rssi()
          bytes = read_until_null(<<>>)
          {:ok, %{data: bytes, rssi: rssi}}
      after
        timeout_ms ->
          @device.cancel_interrupt()
          {:error, :timeout}
      end

    set_mode(:sleep)
    result
  end

  @doc """
  Writes a frame of binary data to the FIFO queue
  """
  @spec write(binary, pos_integer, non_neg_integer, non_neg_integer, boolean) :: {:ok, <<>>}
  def write(packet_bytes, repetitions, repetition_delay, timeout_ms, initial \\ true) do
    if initial == true do
      clear_fifo()
      set_mode(:standby)
    end

    case repetitions do
      r when r >= 1 ->
        _write(packet_bytes, timeout_ms)
        :timer.sleep(repetition_delay)
        write(packet_bytes, repetitions - 1, repetition_delay, timeout_ms, false)

      0 ->
        set_mode(:sleep)
        {:ok, ""}
    end
  end

  @doc """
  Writes the given binary data to the FIFO queue and waits for the response.
  """
  @spec write_and_read(binary, non_neg_integer) :: {:ok, %{data: binary, rssi: number}} | {:error, any()}
  def write_and_read(packet_bytes, timeout_ms) do
    write(packet_bytes, 1, 0, timeout_ms)
    read(timeout_ms)
  end

  @spec clear_buffers() :: :ok
  def clear_buffers do
    clear_fifo()
  end

  defp _write(packet_bytes, _timeout_ms) do
    modes = [:enter_condition_fifo_not_empty, :exit_condition_fifo_empty, :intermediate_mode_tx]
    set_auto_modes(modes)
    transmit(packet_bytes, @fifo_size)
  end

  defp read_until_null(data) do
    case @device.read_single(0x00) do
      {:ok, 0x00} -> data
      {:ok, byte} -> read_until_null(data <> <<byte::8>>)
    end
  end

  defp transmit(bytes, available_buffer_bytes) when byte_size(bytes) <= available_buffer_bytes do
    _transmit(bytes)
    wait_for_mode(:standby)
  end

  defp transmit(bytes, available_buffer_bytes) do
    <<transmit_now::binary-size(available_buffer_bytes), transmit_later::binary>> = bytes
    available_buffer_bytes = _transmit(transmit_now)
    transmit(transmit_later, available_buffer_bytes)
  end

  defp _transmit(bytes) do
    @device.write_burst(0x00, bytes)
    :timer.sleep(@transfer_sleep)
    wait_for_buffer_to_become_available()
  end

  @reg_irq_flags2 0x28
  @fifo_overrun 0x10
  defp clear_fifo do
    @device.write_single(@reg_irq_flags2, @fifo_overrun)
  end

  @fifo_level 0x20
  defp fifo_threshold_exceeded?() do
    {:ok, byte} = @device.read_single(@reg_irq_flags2)
    (byte &&& @fifo_level) != 0x00
  end

  defp wait_for_buffer_to_become_available do
    case fifo_threshold_exceeded?() do
      true -> wait_for_buffer_to_become_available()
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
  defp set_mode(mode) do
    mode = Map.get(@modes, mode)
    current_mode = get_mode()

    case mode do
      ^current_mode -> true
      _ ->
        @device.write_single(@reg_op_mode, mode)
        wait_for_mode_ready(mode)
    end
  end

  defp get_mode do
    {:ok, byte} = @device.read_single(@reg_op_mode)
    byte
  end

  defp wait_for_mode(mode) do
    mode = Map.get(@modes, mode)
    _wait_for_mode(mode)
  end

  defp _wait_for_mode(mode) do
    if get_mode() != mode do
      :timer.sleep(1)
      _wait_for_mode(mode)
    end
  end

  @reg_auto_modes 0x3B
  @auto_modes %{
    enter_condition_fifo_not_empty: 0x20,
    exit_condition_fifo_empty:      0x04,
    intermediate_mode_tx:           0x03
  }
  defp set_auto_modes(modes) do
    register_value =
      modes
      |> Enum.map(fn mode -> @auto_modes[mode] end)
      |> Enum.reduce(0x00, &(&1 ||| &2))

    @device.write_single(@reg_auto_modes, register_value)
  end

  @reg_irq_flags1 0x27
  @mode_ready     0x80
  defp wait_for_mode_ready(mode) do
    {:ok, current_mode} = @device.read_single(@reg_op_mode)
    {:ok, irq_flags1} = @device.read_single(@reg_irq_flags1)
    mode_ready = (irq_flags1 &&& @mode_ready) != 0x00

    case current_mode == mode && mode_ready do
      true -> true
      false -> wait_for_mode_ready(mode)
    end
  end

  @reg_rssi_val 0x24
  defp read_rssi do
    {:ok, <<raw_rssi::8>>} = @device.read_burst(@reg_rssi_val, 1)
    -1 * trunc(raw_rssi) / 2
  end
end
