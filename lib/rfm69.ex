defmodule RFM69 do
  use Bitwise

  require Logger

  @device RFM69.Device
  @moduledoc false
  @fifo_size 66
  # @fifo_threshold 20
  @transfer_sleep trunc(@fifo_size / 4) # time to wait for fifo to be processed during transfer

  def write_and_read(packet_bytes, timeout_ms) do
    write(packet_bytes)
    read(timeout_ms)
  end

  def write(packet_bytes) do
    clear_fifo()
    set_mode(:standby)
    set_auto_modes([:enter_condition_fifo_not_empty, :exit_condition_fifo_empty, :intermediate_mode_tx])
    transmit(packet_bytes <> <<0x00::8>>, @fifo_size)
    set_mode(:sleep)
  end

  def read(timeout_ms) do
    set_auto_modes([])
    set_mode(:receiver)
    @device.await_interrupt()
    receive do
      {:ok, :interrupt_received} ->
        Logger.info "I can't believe this worked"
        # read rssi
        bytes = read_until_null(<<>>)     
        Logger.debug fn() -> "response: #{Base.encode16(bytes)}" end
    after
        timeout_ms -> Logger.info "I got nothin'"
    end
    set_mode(:sleep)
  end

  defp read_until_null(data) do
    case @device.read_single(0x00) do
      0x00 -> data
      byte -> read_until_null(data <> <<byte::8>>)
    end
  end

  defp transmit(bytes, available_buffer_bytes) when byte_size(bytes) <= available_buffer_bytes do
    Logger.debug fn() -> "Transmitting remaining: #{Base.encode16(bytes)}, available_buffer_bytes: #{available_buffer_bytes}" end
    _transmit(bytes)
    wait_for_mode(:standby)
  end

  # defp transmit(bytes, available_buffer_bytes) do
  #   <<transmit_now::binary-size(available_buffer_bytes), transmit_later::binary>> = bytes
  #   Logger.debug fn() -> "Transmitting initial: #{Base.encode16(transmit_now)}, available_buffer_bytes: #{available_buffer_bytes}" end
  #   available_buffer_bytes = _transmit(transmit_now)
  #   Logger.debug fn() -> "Queueing rest: #{Base.encode16(transmit_later)}, new available_buffer_bytes: #{available_buffer_bytes}" end
  #   transmit(transmit_later, available_buffer_bytes)
  # end

  defp _transmit(bytes) do
    @device.write_burst(0x00, bytes)
    :timer.sleep(@transfer_sleep)
    wait_for_buffer_to_become_available()
  end

  @reg_irq_flags2 0x28
  @fifo_overrun 0x10
  defp clear_fifo() do
    Logger.debug "Clearing FIFO"
    @device.write_single(@reg_irq_flags2, @fifo_overrun)
  end

  @fifo_level 0x20
  defp fifo_threshold_exceeded?() do
    (@device.read_single(@reg_irq_flags2) &&& @fifo_level) != 0x00
  end

  defp wait_for_buffer_to_become_available() do
    Logger.debug "Waiting for buffer to become available"
    case fifo_threshold_exceeded?() do
      true -> wait_for_buffer_to_become_available()
      false -> Logger.debug "Buffer available"
    end
  end

  @reg_op_mode      0x01
  @modes %{
    sequencer_off:    0x80,
    listen_on:        0x40,
    listen_abort:     0x20,
    mode_shift:       0x02,
    mode_mask:        0x1C,
    sleep:            0x00,
    standby:          0x04,
    freq_synth:       0x08,
    transmitter:      0x0C,
    receiver:         0x10
  }
  def set_mode(mode) do
    mode = Map.get(@modes, mode)
    current_mode = get_mode()
    case mode do
      ^current_mode -> true
      _ ->
        Logger.debug fn() -> "Setting mode to #{inspect(mode)}" end
        @device.write_single(@reg_op_mode, mode)
        wait_for_mode_ready(mode)
    end
  end

  defp get_mode() do
    @device.read_single(@reg_op_mode)
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
    register_value = modes
    |> Enum.map(fn(mode) -> @auto_modes[mode] end)
    |> Enum.reduce(0x00, &(&1 ||| &2))
    @device.write_single(@reg_auto_modes, register_value)
  end

  @reg_irq_flags1 0x27
  @mode_ready     0x80
  defp wait_for_mode_ready(mode) do
    current_mode = @device.read_single(@reg_op_mode)
    irq_flags1 = @device.read_single(@reg_irq_flags1)
    mode_ready = (irq_flags1 &&& @mode_ready) != 0x00

    case current_mode == mode && mode_ready do
      true -> true
      false -> wait_for_mode_ready(mode)
    end
  end

  # def read_hardware_version() do
  #   <<_::8, version::4, metal_mask::4>> = SPI.transfer(<<0x1000::16>>)
  #   IO.puts "Version: #{version}, Metal Version: #{metal_mask}"
  #   version
  # end
end
