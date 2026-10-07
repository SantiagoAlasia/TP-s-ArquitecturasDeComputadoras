## ============================================================
## Constraints para Uart_Top - Placa Basys3 (Artix-7)
## Puertos del top: i_clk, i_reset, i_rx, o_tx, o_leds[7:0]
## ============================================================

## ---------- Clock (100 MHz) ----------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ---------- Reset: boton central (btnC) ----------
set_property PACKAGE_PIN U18 [get_ports i_reset]
set_property IOSTANDARD LVCMOS33 [get_ports i_reset]

## ---------- UART: puente USB-serie integrado en la placa ----------
## RsRx = entrada a la FPGA (PC -> FPGA)
set_property PACKAGE_PIN B18 [get_ports i_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_rx]

## RsTx = salida de la FPGA (FPGA -> PC)
set_property PACKAGE_PIN A18 [get_ports o_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_tx]

## ---------- LEDs: o_leds[7:0] ----------
set_property PACKAGE_PIN U16 [get_ports {o_leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[0]}]
set_property PACKAGE_PIN E19 [get_ports {o_leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[1]}]
set_property PACKAGE_PIN U19 [get_ports {o_leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[2]}]
set_property PACKAGE_PIN V19 [get_ports {o_leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[3]}]
set_property PACKAGE_PIN W18 [get_ports {o_leds[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[4]}]
set_property PACKAGE_PIN U15 [get_ports {o_leds[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[5]}]
set_property PACKAGE_PIN U14 [get_ports {o_leds[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[6]}]
set_property PACKAGE_PIN V14 [get_ports {o_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[7]}]

## ---------- Configuracion general (recomendada por Digilent) ----------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
