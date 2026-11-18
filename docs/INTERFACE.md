# INTERFACE.md: FPGA Mixed-Signal Oscilloscope

Shared contract between the analog half (anita) and the digital half (Kyle).
Change this file only when both of us agree.

## 1. Global

| Item | Value |
|---|---|
| Board | DE1-SoC |
| System clock | `CLOCK_50` (50 MHz) for all logic |
| Reset | `resetn` = `KEY[0]`, active-low, shared by everything |
| Display | Course VGA adapter, **320 × 240**, **9-bit colour** (3 bits per channel) |
| Coordinates | `x` = 9 bits (0–319), `y` = 8 bits (0–239), origin top-left |

Use the course adapter's own parameter names for resolution and colour depth.

## 2. Screen regions

| Region | Owner | Rows |
|---|---|---|
| Analog waveform | Anita | y = 0–119 |
| Digital channels + decoded bytes + status line | Kyle | y = 120–239 |

**Rule:** each module only ever plots inside its own rows, including when erasing.
(Kyle's testbench will check this with an assertion.)

## 3. Drawing modules

Each half provides one drawing module with these ports:

```
input            clk,       // CLOCK_50
input            resetn,
input            grant,     // 1 = I own the screen this cycle
output           req,       // 1 = I want the screen (hold for the whole frame)
output [8:0]     x,
output [7:0]     y,
output [8:0]     colour,    // RRRGGGBBB
output           plot       // 1 = write (x, y, colour) this cycle
```

Handshake (request/grant, same pattern as the course VGA "animate" example):
1. Raise `req` when you want to draw a frame (erase + redraw).
2. Wait until `grant` is 1. Only advance your pixel counters and assert `plot` while `grant` is 1.
3. Drop `req` when the frame is done, so the other module gets a turn.

Don't hold `req` forever, or the other half never gets drawn.

## 4. Write arbiter (owned by Kyle, in `scope_core`)

- The adapter has one write port, so only one module may draw at a time.
- Request/grant arbiter (pattern from the course VGA "animate" example):
  when idle, grant whichever module is requesting; that module keeps `grant`
  until it drops `req`, then the arbiter returns to idle.
- It forwards the granted module's `x`, `y`, `colour`, `plot` to the adapter.
- Until the arbiter exists, `scope_core` ties `digital_view`'s `grant` to 1.

## 5. Inputs on the board

| Input | Owner | Use |
|---|---|---|
| `KEY[0]` | Shared | Reset |
| `SW[0]` | Kyle | Mode: live GPIO / self-test |
| `SW[3:1]` | Kyle | Bug injection |
| `KEY[1]` | Kyle | Clear counters / send test byte |
| `SW[9:5]` | Anita | Time/div, trigger edge, trigger level |
| `KEY[3:2]` | Anita | Trigger level up/down or freeze |
| `SW[4]` | Spare | |
| `GPIO_0[3:0]` | Kyle | Digital channels CH0–CH3 (3.3 V only) |
| ADC header | Anita | Analog input |
| `HEX`, `LEDR` | Kyle | Harness pass/fail counts (unless we agree otherwise) |

## 6. Repo layout

```
rtl/analog/     Anita's modules
rtl/digital/    Kyle's modules
rtl/top/        scope_core (whole project, arbiter) + course VGA adapters (Kyle)
desim/          DESim wrapper (top.v), tb, compile scripts
sim/            ModelSim testbenches, one folder per module
docs/           this file, block diagrams, milestone write-ups
```

Each person works in their own folder; changes to `rtl/top/` or this file are discussed first.

## 7. Integration checkpoints

| When | What |
|---|---|
| Before Milestone 1 | Course `vga_demo` runs on our board. Each drawing module fills its own region with a test pattern, and both run together through the arbiter. |
| Milestone 2 | Test patterns replaced by the real views: triggered analog waveform on top, live digital trace + decoded UART bytes on the bottom. |
| Presentation | Measurements, self-checking harness, shared-signal demo. |

## 8. Open questions

- [ ] Confirm the board's ADC chip and input range (LTC2308: 0–4.096 V unipolar).
- [x] Confirm the adapter's memory use at 320 × 240 × 9 bits leaves room for our capture RAMs.
      (691,200 bits ≈ 68 of 446 on-chip RAM blocks, about 15%.)
- [ ] Who presents which slides.
