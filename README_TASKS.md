# Dig-and-pump game on the Cmod A7-35T: team task guide (3 people)

A VGA game with a digger, enemies, rocks and a pump, built from scratch in VHDL. Each person
owns separate files, so you can work at the same time without editing each other's code.

## 1. Who does what

| | Person A: Hardware & Video | Person B: Graphics & Level | Person C: Game Logic |
|---|---|---|---|
| Files owned | `clk_gen.vhd`, `vga_timing.vhd`, `input_sync.vhd`, `test_pattern.vhd`, `digger_top.vhd`, `digger.xdc`, `ai_pkg.vhd` | `sprite_pkg.vhd`, `renderer.vhd`, `level_pkg.vhd`, `demo_pkg.vhd` | `game.vhd`, `tb_game.vhd` |
| Job 1 | Get a stable picture on the monitor (clock, timing, wiring) | Draw the art and the renderer | Player movement + digging, then pump |
| Job 2 | Enemy movement function (`enemy_step`) | Design the starting level | Rocks, death/respawn, win/lose |
| Hardware | Builds the VGA resistor ladder and the 5 buttons | none until integration | none until integration |
| Test alone with | `USE_TEST_PATTERN` (color bars) | `USE_DEMO_STATE` (fake frozen state) | `tb_game.vhd` (simulation) |

**Shared, finished, do not edit alone:** `digger_pkg.vhd`. It holds the game-state record and
helper functions that connect everyone's code. If you need to change it, tell the other two first.

Work split roughly by effort: C has the most code, B has the most creative work, A has the
most hands-on hardware (and finishes the quickest, so A also takes the enemy AI).

## 2. How the pieces connect

```
sysclk 12 MHz -> clk_gen (A) -> 25 MHz pixel clock
                                   |
buttons -> input_sync (A) -> game (C) --game_state_t--> renderer (B) -> VGA pins
                                  ^                          ^
                                  +--- tick -- vga_timing (A) -- px, py, hs, vs, active
```

- `game.vhd` updates once per frame (the `tick` pulse) and publishes `gs`.
- `renderer.vhd` reads `gs` and decides each pixel's color as the beam sweeps the screen.
- `game.vhd` calls `ai_pkg.enemy_step` (A) and starts from `level_pkg.make_init` (B).

## 3. The interfaces (agree on these in the first 15 minutes)

1. **`game_state_t`** in `digger_pkg.vhd`. Read every field's comment together.
2. **`enemy_step(st, i) -> (nx, ny, ghost)`** in `ai_pkg.vhd`: pure function, reads the state, returns the enemy's new cell and ghost timer. C calls it, A writes it.
3. **`make_init`** in `level_pkg.vhd`: returns the starting state. B writes it, C uses it.
4. **`sprite_px(kind, sx, sy)`** in `sprite_pkg.vhd`: returns one sprite pixel. B writes it, B's renderer uses it.
5. **Cell coordinates:** x = column 0..19, y = row 0..14. Row 0 is the sky/HUD strip; the playable area is rows 1..14. Directions: 0 up, 1 right, 2 down, 3 left.

## 4. Milestones (do them in this order)

| # | Goal | A | B | C |
|---|---|---|---|---|
| M0 | Everyone ready | Make a shared git repo; copy `starter/` in | Read the contract with the others | Same |
| M1 | Picture | Clock + VGA timing + color bars on the monitor | Sprite art + background layer (waits for A's picture; sketch art meanwhile) | Player movement + digging in the testbench |
| M2 | Artwork | Input debounce; breadboard buttons tested with LEDs | All layers working with `USE_DEMO_STATE` | Pump in the testbench |
| M3 | First integration | Combine real files: player visible and moving on the screen | Fix any rendering glitches seen with real data | Fix any logic glitches |
| M4 | Enemies | `enemy_step` working, integrated into `game.vhd` | Level layout tuned for the enemies | Call `enemy_step`; enemies deflate/die |
| M5 | Full rules | Hardware tidy-up | HUD and polish | Rocks, death/respawn, win/lose |
| M6 | Play-test | All three play it and tune the constants (speeds, level) | | |

**Dependencies:** A's picture (M1) unblocks B's visual testing and C's on-screen testing. Until it
works, B and C use `USE_DEMO_STATE` and `tb_game.vhd` respectively. C's game logic can be tested
completely in simulation without any hardware.

## 5. Git rules (avoids painful merge conflicts)

- Each person edits only their own files (table above).
- Commit often with clear messages ("renderer: draw enemies").
- Before changing `digger_pkg.vhd`, message the group. Everyone pulls right after.
- Pull before you start working and before you push.
- Don't commit Vivado's generated folders (`*.runs`, `*.cache`, `*.hw`, `*.sim`). Only the source files.

## 6. Hardware wiring (Person A)

The Cmod A7 has no VGA port, so you build the connection on a breadboard. Each color channel
uses two pins with different resistors, joined into one node going to the VGA connector.

| Channel | Pin via 390 ohm (MSB) | Pin via 820 ohm (LSB) | VGA connector pin |
|---|---|---|---|
| Red | pio01 | pio02 | 1 |
| Green | pio03 | pio04 | 2 |
| Blue | pio05 | pio06 | 3 |

- HSYNC: pio07 straight to VGA pin 13 (optionally through ~100 ohm).
- VSYNC: pio08 straight to VGA pin 14 (optionally through ~100 ohm).
- GND: tie VGA pins 5, 6, 7, 8 and 10 to the Cmod's GND.
- Do not connect VGA pin 9 (+5 V). The FPGA pins are 3.3 V only.
- Use a VGA breakout board or cut open an old VGA cable and identify the wires with a multimeter.

Game buttons (each wired between the pin and GND; the constraints enable internal pull-ups, so
no resistors are needed):

| Button | Pin |
|---|---|
| Up | pio09 |
| Down | pio10 |
| Left | pio11 |
| Right | pio12 |
| Pump (hold) | pio13 |

Onboard: BTN0 = reset, BTN1 = restart after game over / win, LED0 = clock locked, LED1 = playing.
The silkscreen shows which header holes are GND.

## 7. Common problems

- **Blank screen:** is LED0 on (clock locked)? Then check HSYNC/VSYNC wiring and that `active` goes low outside the picture.
- **Picture rolls or shakes:** `vga_timing` counts or sync windows are wrong. Re-check the table in that file.
- **Wrong colors:** a resistor ladder pin is swapped. Test with the color bars one channel at a time.
- **Simulation error "value out of range":** an integer assigned outside its range (for example `px = 20`). Check the bounds before assigning.
- **A signal never changes in the waveform:** you read it before the tick, or forgot to assign `s <= v` at the end.
- **Buttons seem stuck or flaky:** the debouncer isn't implemented, or `ACTIVE_LOW` is wrong for that button.

## 8. Definition of done

- The monitor shows the full picture steadily.
- The player moves and digs with the buttons.
- Pumping inflates and pops enemies.
- Enemies chase the player, sometimes as ghosts through the dirt.
- Rocks wobble, fall, and crush enemies and the player.
- The HUD shows lives and enemies left; game over and win states work; BTN1 restarts.
- All three of you can explain every file you didn't write. Swap and explain each other's files at the end.
