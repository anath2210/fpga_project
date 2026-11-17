## digger.xdc  -  constraints for the Cmod A7-35T game (VGA through the VGA Pmod in header JA)
## Pin locations were checked against Digilent's CmodA7_Master.xdc.
## The "pio[NN]" in a comment is the number printed next to that hole on the DIP header.
##

## ---------------- Clock (12 MHz) ----------------
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { sysclk }]
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { sysclk }]

## ---------------- Onboard LEDs ----------------
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]   ;# on = clock locked
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]   ;# on = playing

## ---------------- Onboard buttons (active high) ----------------
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]   ;# reset
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]   ;# start / restart

## ---------------- VGA: course VGA Pmod module plugged into header JA ----------------
## Pin mapping taken from the working xdc of the earlier VGA lab (lab_f). [1] = MSB, [0] = LSB.
##   Pmod pin :  1      2      3      4     7      8      9      10
##   FPGA pin :  G17    G19    N18    L18   H17    H19    J19    K18
##   signal   :  r[0]   g[0]   b[0]   vs    r[1]   g[1]   b[1]   hs
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]  ;# JA pin 7
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]  ;# JA pin 1
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]  ;# JA pin 8
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]  ;# JA pin 2
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]  ;# JA pin 9
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]  ;# JA pin 3
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { vga_hs }]    ;# JA pin 10
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { vga_vs }]    ;# JA pin 4

## ---------------- Game buttons: each between the pin and GND (internal pull-ups) ----------------
## These stay on the DIP header (not used by the VGA Pmod).
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

## ---------------- Game logic runs once per frame ----------------
## game.vhd only changes its state on the 60 Hz tick; its inputs have been stable for ~420,000
## clocks by then. So the long combinational logic is allowed many clocks. If Vivado says these
## cell patterns match nothing, open the Netlist, find the cells named ...s_reg... inside the
## game instance (instance name "logic" in digger_top) and fix the pattern.
set_multicycle_path -setup 16 -from [get_cells -hier -filter {NAME =~ logic/*}] -to [get_cells -hier -filter {NAME =~ logic/s_reg*}]
set_multicycle_path -hold  15 -from [get_cells -hier -filter {NAME =~ logic/*}] -to [get_cells -hier -filter {NAME =~ logic/s_reg*}]
