## digger.xdc  --  OWNER: Person A (Hardware & Video)
## Pin constraints for the Cmod A7-35T game. Already filled in; the pin locations were
## checked against Digilent's CmodA7_Master.xdc. The "pio[NN]" in each comment is the
## number printed next to that hole on the DIP header.
##
## TODO(A): (1) double-check each pin against Digilent's master XDC before wiring;
##          (2) wire the breadboard exactly as in README_TASKS.md section "Hardware wiring";
##          (3) if a signal does nothing on hardware, this file is the first suspect.

## ---------------- Clock (12 MHz) ----------------
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { sysclk }]
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { sysclk }]

## ---------------- Onboard LEDs ----------------
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]   ;# on = clock locked
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]   ;# on = playing

## ---------------- Onboard buttons (active high) ----------------
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]   ;# reset
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]   ;# start / restart

## ---------------- VGA through resistor ladder (DIP header) ----------------
## Bit [1] = MSB (390 ohm), bit [0] = LSB (820 ohm)
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]  ;# pio[01]
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]  ;# pio[02]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]  ;# pio[03]
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]  ;# pio[04]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]  ;# pio[05]
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]  ;# pio[06]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports { vga_hs }]    ;# pio[07]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports { vga_vs }]    ;# pio[08]

## ---------------- Game buttons: each between the pin and GND (internal pull-ups) ----------------
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { key_up }]     ;# pio[09]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 PULLUP true } [get_ports { key_down }]   ;# pio[10]
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports { key_left }]   ;# pio[11]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports { key_right }]  ;# pio[12]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports { key_pump }]   ;# pio[13]

## ---------------- Timing: these paths are asynchronous to the design ----------------
set_false_path -from [get_ports { btn[*] key_* }]
set_false_path -to   [get_ports { led[*] vga_* }]

## ---------------- Configuration ----------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
