defmodule RFM69.RFConfiguration do
  @moduledoc """
  RFConfiguration is a module and associated struct to model the registers in an RFM69 chip
  """

  use Bitwise

  alias RFM69.RFConfiguration

  # default settings from
  # http://www.hoperf.com/upload/rf/RFM69HW-V1.3.pdf

  defstruct [fifo:           0x00,               # FIFO read/write access
             op_mode:        0x04,               # Operating modes of the transceiver
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

  def to_binary(rf_config = %RFConfiguration{}) do
    <<rf_config.fifo::8,
      rf_config.op_mode::8,
      rf_config.data_modul::8,
      rf_config.bitrate::16,
      rf_config.fdev::16,
      rf_config.frf::24,
      rf_config.osc1::8,
      rf_config.afc_ctrl::8,
      rf_config.reserved0_c::8,
      rf_config.listen1::8,
      rf_config.listen2::8,
      rf_config.listen3::8,
      rf_config.version::8,
      rf_config.pa_level::8,
      rf_config.pa_ramp::8,
      rf_config.ocp::8,
      rf_config.reserved14::8,
      rf_config.reserved15::8,
      rf_config.reserved16::8,
      rf_config.reserved17::8,
      rf_config.lna::8,
      rf_config.rx_bw::8,
      rf_config.afc_bw::8,
      rf_config.ook_peak::8,
      rf_config.ook_avg::8,
      rf_config.ook_fix::8,
      rf_config.afc_fei::8,
      rf_config.afc::16,
      rf_config.fei::16,
      rf_config.rssi_config::8,
      rf_config.rssi_value::8,
      rf_config.dio_mapping1::8,
      rf_config.dio_mapping2::8,
      rf_config.irq_flags1::8,
      rf_config.irq_flags2::8,
      rf_config.rssi_thresh::8,
      rf_config.rx_timeout1::8,
      rf_config.rx_timeout2::8,
      rf_config.preamble::16,
      rf_config.sync_config::8,
      rf_config.sync_value::64,
      rf_config.packet_config1::8,
      rf_config.payload_length::8,
      rf_config.node_adrs::8,
      rf_config.broadcast_adrs::8,
      rf_config.auto_modes::8,
      rf_config.fifo_thresh::8,
      rf_config.packet_config2::8,
      rf_config.aes_key::128,
      rf_config.temp1::8,
      rf_config.temp2::8>>
  end

  @oscillator_frequency 32_000_000
  def frequency_to_registers(frequency_in_hz) do
    trunc(((frequency_in_hz <<< 19) + (@oscillator_frequency / 2)) / @oscillator_frequency)
  end

  def bitrate_to_registers(bitrate) do
    trunc((@oscillator_frequency + bitrate / 2) / bitrate)
  end
end
