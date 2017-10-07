defmodule RFM69.Configuration do
  @moduledoc """
  RFM69.Configuration is a module and associated struct to model register configuration in an RFM69 chip
  """

  use Bitwise

  alias RFM69.Configuration

  # default settings from
  # http://www.hoperf.com/upload/rf/RFM69HW-V1.3.pdf
  defstruct [op_mode:        0x04,               # Operating modes of the transceiver
             data_modul:     0x00,               # Data operation mode and Modulation settings
             bitrate:        0x1A0B,             # Bit Rate setting
             fdev:           0x0052,             # Frequency Deviation setting
             frf:            0xE4C000,           # RF Carrier Frequency
             osc1:           0x41,               # RF Oscillators Settings
             afc_ctrl:       0x00,               # AFC control in low modulation index situations
             reserved0_c:    0x02,
             listen1:        0x92,               # Listen Mode settings
             listen2:        0xF5,               # Listen Mode Idle duration
             listen3:        0x20,               # Listen Mode Rx duration
             version:        0x24,               # PA selection and Output Power control
             pa_level:       0x9F,               # PA selection and Output Power control
             pa_ramp:        0x09,               # Control of the PA ramp time in FSK mode
             ocp:            0x1A,               # Over Current Protection control
             reserved14:     0x40,
             reserved15:     0xB0,
             reserved16:     0x7B,
             reserved17:     0x9B,
             lna:            0x88,               # LNA settings
             rx_bw:          0x55,               # Channel Filter BW Control
             afc_bw:         0x8B,               # Channel Filter BW control during the AFC routine
             ook_peak:       0x40,               # OOK demodulator selection and control in peak mode
             ook_avg:        0x80,               # Average threshold control of the OOK demodulator
             ook_fix:        0x06,               # Fixed threshold control of the OOK demodulator
             afc_fei:        0x10,               # AFC and FEI control and status
             afc:            0x00,               # Frequency correction of the AFC
             fei:            0x00,               # Calculated frequency error
             rssi_config:    0x02,               # RSSI-related settings
             rssi_value:     0xFF,               # RSSI value in dBm
             dio_mapping1:   0x00,               # Mapping of pins DIO0 to DIO3
             dio_mapping2:   0x07,               # Mapping of pins DIO4 and DIO5, ClkOut frequency
             irq_flags1:     0x80,               # Status register: PLL Lock state, Timeout, RSSI > Threshold...
             irq_flags2:     0x00,               # Status register: FIFO handling flags...
             rssi_thresh:    0xE4,               # RSSI Threshold control
             rx_timeout1:    0x00,               # Timeout duration between Rx request and RSSI detection
             rx_timeout2:    0x00,               # Timeout duration between RSSI detection and PayloadReady
             preamble:       0x0003,             # Preamble length
             sync_config:    0x98,               # Sync Word Recognition control
             sync_value:     0x0101010101010101, # Sync Word bytes, 1 through 8
             packet_config1: 0x10,               # Packet mode settings
             payload_length: 0x40,               # Payload length setting
             node_adrs:      0x00,               # Node address
             broadcast_adrs: 0x00,               # Broadcast address
             auto_modes:     0x00,               # Auto modes settings
             fifo_thresh:    0x8F,               # Fifo threshold, Tx start condition
             packet_config2: 0x02,               # Packet mode settings
             aes_key:        0x00,               # 16 bytes of the cypher key
             temp1:          0x01,               # Temperature Sensor control
             temp2:          0x00,               # Temperature readout Omit test
             test_lna:       0x1B,               # Sensitivity boost
             test_pa1:       0x55,               # High Power PA settings
             test_pa2:       0x70,               # High Power PA settings
             test_dagc:      0x30,               # Fading Margin Improvement
             test_afc:       0x00]               # AFC offset for low modulation index AFC

  def to_binary(
    %Configuration{
      op_mode: op_mode,
      data_modul: data_modul,
      bitrate: bitrate,
      fdev: fdev,
      frf: frf,
      osc1: osc1,
      afc_ctrl: afc_ctrl,
      reserved0_c: reserved0_c,
      listen1: listen1,
      listen2: listen2,
      listen3: listen3,
      version: version,
      pa_level: pa_level,
      pa_ramp: pa_ramp,
      ocp: ocp,
      reserved14: reserved14,
      reserved15: reserved15,
      reserved16: reserved16,
      reserved17: reserved17,
      lna: lna,
      rx_bw: rx_bw,
      afc_bw: afc_bw,
      ook_peak: ook_peak,
      ook_avg: ook_avg,
      ook_fix: ook_fix,
      afc_fei: afc_fei,
      afc: afc,
      fei: fei,
      rssi_config: rssi_config,
      rssi_value: rssi_value,
      dio_mapping1: dio_mapping1,
      dio_mapping2: dio_mapping2,
      irq_flags1: irq_flags1,
      irq_flags2: irq_flags2,
      rssi_thresh: rssi_thresh,
      rx_timeout1: rx_timeout1,
      rx_timeout2: rx_timeout2,
      preamble: preamble,
      sync_config: sync_config,
      sync_value: sync_value,
      packet_config1: packet_config1,
      payload_length: payload_length,
      node_adrs: node_adrs,
      broadcast_adrs: broadcast_adrs,
      auto_modes: auto_modes,
      fifo_thresh: fifo_thresh,
      packet_config2: packet_config2,
      aes_key: aes_key,
      temp1: temp1,
      temp2: temp2
    }) do
    <<op_mode::8,
      data_modul::8,
      bitrate::16,
      fdev::16,
      frf::24,
      osc1::8,
      afc_ctrl::8,
      reserved0_c::8,
      listen1::8,
      listen2::8,
      listen3::8,
      version::8,
      pa_level::8,
      pa_ramp::8,
      ocp::8,
      reserved14::8,
      reserved15::8,
      reserved16::8,
      reserved17::8,
      lna::8,
      rx_bw::8,
      afc_bw::8,
      ook_peak::8,
      ook_avg::8,
      ook_fix::8,
      afc_fei::8,
      afc::16,
      fei::16,
      rssi_config::8,
      rssi_value::8,
      dio_mapping1::8,
      dio_mapping2::8,
      irq_flags1::8,
      irq_flags2::8,
      rssi_thresh::8,
      rx_timeout1::8,
      rx_timeout2::8,
      preamble::16,
      sync_config::8,
      sync_value::64,
      packet_config1::8,
      payload_length::8,
      node_adrs::8,
      broadcast_adrs::8,
      auto_modes::8,
      fifo_thresh::8,
      packet_config2::8,
      aes_key::128,
      temp1::8,
      temp2::8>>
  end

  def from_binary(<<op_mode::8,
    data_modul::8,
    bitrate::16,
    fdev::16,
    frf::24,
    osc1::8,
    afc_ctrl::8,
    reserved0_c::8,
    listen1::8,
    listen2::8,
    listen3::8,
    version::8,
    pa_level::8,
    pa_ramp::8,
    ocp::8,
    reserved14::8,
    reserved15::8,
    reserved16::8,
    reserved17::8,
    lna::8,
    rx_bw::8,
    afc_bw::8,
    ook_peak::8,
    ook_avg::8,
    ook_fix::8,
    afc_fei::8,
    afc::16,
    fei::16,
    rssi_config::8,
    rssi_value::8,
    dio_mapping1::8,
    dio_mapping2::8,
    irq_flags1::8,
    irq_flags2::8,
    rssi_thresh::8,
    rx_timeout1::8,
    rx_timeout2::8,
    preamble::16,
    sync_config::8,
    sync_value::64,
    packet_config1::8,
    payload_length::8,
    node_adrs::8,
    broadcast_adrs::8,
    auto_modes::8,
    fifo_thresh::8,
    packet_config2::8,
    aes_key::128,
    temp1::8,
    temp2::8>>) do

    %Configuration{
      op_mode: op_mode,
      data_modul: data_modul,
      bitrate: bitrate,
      fdev: fdev,
      frf: frf,
      osc1: osc1,
      afc_ctrl: afc_ctrl,
      reserved0_c: reserved0_c,
      listen1: listen1,
      listen2: listen2,
      listen3: listen3,
      version: version,
      pa_level: pa_level,
      pa_ramp: pa_ramp,
      ocp: ocp,
      reserved14: reserved14,
      reserved15: reserved15,
      reserved16: reserved16,
      reserved17: reserved17,
      lna: lna,
      rx_bw: rx_bw,
      afc_bw: afc_bw,
      ook_peak: ook_peak,
      ook_avg: ook_avg,
      ook_fix: ook_fix,
      afc_fei: afc_fei,
      afc: afc,
      fei: fei,
      rssi_config: rssi_config,
      rssi_value: rssi_value,
      dio_mapping1: dio_mapping1,
      dio_mapping2: dio_mapping2,
      irq_flags1: irq_flags1,
      irq_flags2: irq_flags2,
      rssi_thresh: rssi_thresh,
      rx_timeout1: rx_timeout1,
      rx_timeout2: rx_timeout2,
      preamble: preamble,
      sync_config: sync_config,
      sync_value: sync_value,
      packet_config1: packet_config1,
      payload_length: payload_length,
      node_adrs: node_adrs,
      broadcast_adrs: broadcast_adrs,
      auto_modes: auto_modes,
      fifo_thresh: fifo_thresh,
      packet_config2: packet_config2,
      aes_key: aes_key,
      temp1: temp1,
      temp2: temp2
    }
  end

  @oscillator_frequency 32_000_000
  def frequency_to_registers(frequency_in_hz) do
    trunc(((frequency_in_hz <<< 19) + (@oscillator_frequency / 2)) / @oscillator_frequency)
  end

  def bitrate_to_registers(bitrate) do
    trunc((@oscillator_frequency + bitrate / 2) / bitrate)
  end
end
