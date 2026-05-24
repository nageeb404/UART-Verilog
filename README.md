# UART RTL Implementation in Verilog

**Universal Asynchronous Receiver-Transmitter — Register Transfer Level Design**

**Author:** Ahmed Ahmed Nageeb Elbermawy  
**Institution:** Menofia University, Faculty of Engineering  
**Tool:** Xilinx Vivado (behavioral simulation)  
**Language:** Verilog HDL  

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Basic Concepts of UART](#2-basic-concepts-of-uart)
3. [Design Methodology](#3-design-methodology)
4. [Project Structure](#4-project-structure)
5. [Component Breakdown](#5-component-breakdown)
   - [Baud Rate Generator](#51-baud-rate-generator)
   - [UART Transmitter](#52-uart-transmitter)
   - [UART Receiver](#53-uart-receiver)
   - [UART Top-Level](#54-uart-top-level-wrapper)
6. [ASMD Charts](#6-asmd-charts)
7. [Testbenches & Simulation](#7-testbenches--simulation)
8. [How to Simulate](#8-how-to-simulate)
9. [References](#9-references)

---

## 1. Introduction

UART (Universal Asynchronous Receiver-Transmitter) is one of the most widely used serial communication protocols in digital systems. It enables data exchange between two devices over just two wires — TX (transmit) and RX (receive) — without requiring a shared clock signal. This makes it simple, low-cost, and compatible with virtually every microcontroller, FPGA, and embedded system in existence.

This project presents a complete RTL implementation of a UART transceiver written in Verilog HDL. The design was built from the ground up using a modular, hierarchical approach and covers the full UART frame format including start bit, configurable parity, and stop bit. The receiver uses **16× oversampling** to reliably sample incoming data without a shared clock reference.

**Key features of this implementation:**

- Parameterized design — data bits (`DBITS`) and stop-bit duration (`SB_TICK`) are configurable at elaboration time
- Full parity support — even, odd, or none, selectable at runtime via a 2-bit input
- Parity error detection — flags a mismatch between the received and expected parity bit
- Frame error detection — flags a missing stop bit (stop bit sampled as logic 0)
- **2-FF input synchronizer** on the RX line — prevents metastability from propagating into the FSM
- Clean FSM structure — separate present-state and next-state always blocks throughout
- Two testbenches — standalone TX verification and full TX→RX loopback with automated PASS/FAIL checking

The design process follows RTL best practices: each module is self-contained, verified independently through a testbench, and then integrated into a top-level wrapper.

---

## 2. Basic Concepts of UART

### Asynchronous Communication

UART is asynchronous — the transmitter and receiver share no clock. Synchronization is achieved entirely through the **frame structure**: a start bit tells the receiver when a new frame begins, and one or more stop bits mark its end. Both sides must be pre-configured to the same baud rate and frame format before communication begins.

### UART Frame Format

A standard UART frame on the wire looks like this:

```
Idle  Start  D0  D1  D2  D3  D4  D5  D6  D7  [Parity]  Stop  Idle
 1      0    lsb                              msb   P       1
```

| Field | Value | Description |
|---|---|---|
| Idle | 1 | Line rests high when no data is being sent |
| Start bit | 0 | Always logic low — signals start of frame |
| Data bits | D0–D7 | Sent LSB first; typically 8 bits |
| Parity bit | optional | Error detection — even, odd, or omitted |
| Stop bit | 1 | Always logic high — marks end of frame |

### Baud Rate

The baud rate defines the number of bits transmitted per second (bps). Both devices must use the same baud rate. Common values: **9600, 19200, 38400, 57600, 115200 bps**.

With a 100 MHz system clock and 16× oversampling, the Baud Rate Generator divider value is:

$$\text{FINAL\_VALUE} = \frac{F_{clk}}{16 \times \text{BaudRate}} - 1$$

| Baud Rate | FINAL_VALUE (100 MHz clock) | BRG_BITS needed |
|---|---|---|
| 9600 | 651 | 10 |
| 19200 | 325 | 9 |
| 38400 | 162 | 8 |
| 57600 | 108 | 7 |
| 115200 | 54 | 6 |

### Parity

An optional parity bit appended to the data provides single-bit error detection:

- **Even parity:** parity bit = XOR of all data bits (total number of 1s, including parity, is even)
- **Odd parity:** parity bit = NXOR of all data bits (total number of 1s is odd)
- **None:** parity bit omitted entirely

---

## 3. Design Methodology

### 16× Oversampling

Because UART is asynchronous, the receiver has no clock edge to tell it when each bit starts. Instead, the Baud Rate Generator produces a **sampling tick (s_tick) at 16× the baud rate**. The receiver counts these ticks to estimate the centre of each bit, where the signal is most stable.

The procedure for each received frame:

1. Wait for `rx` to go low — this is the falling edge of the start bit.
2. Count **7 s_ticks** — this positions the sampling point at the middle of the start bit. Confirm `rx` is still low (guards against noise spikes).
3. Count **16 s_ticks** — now at the middle of data bit 0. Sample `rx` and shift into the data register.
4. Repeat step 3 for each remaining data bit (7 more times for 8-bit data).
5. If parity is enabled, repeat step 3 once to sample the parity bit.
6. Count through the stop bit period and verify `rx` is high; assert `rx_done_tick`.

```
         start bit                  D0 bit
            |<--- 8 ticks --->|<--- 16 ticks --->|
 ___         _________________ _________
    |_______|                 X         X ...
            ^                 ^
         detect             sample
         (tick 0)           (tick 15)
```

This technique tolerates a clock frequency mismatch of up to ±1/16 (6.25%) between the transmitter and receiver — far more than typical crystal oscillator tolerances.

### Input Synchronization

The `rx` line arrives from an external device and is therefore **asynchronous** to the FPGA's clock domain. Sampling it directly risks **metastability** — a flip-flop entering an undefined voltage state that can propagate unpredictable values through the logic.

The solution is a **2-FF synchronizer**: two back-to-back flip-flops clocked by the system clock. The first FF may go metastable, but it has a full clock period to resolve before the second FF samples it. The output of the second FF (`rx_sync`) is then used everywhere in the FSM.

```
  rx (async) --> [FF1] rx_meta --> [FF2] rx_sync --> FSM
                 (may go         (stable,
                 metastable)     safe to use)
```

Both FFs reset to `1` (the UART idle level) to prevent a false start-bit detection on power-up.

---

## 4. Project Structure

```
├── README.md
├── .gitignore
├── UART.xpr                         — Vivado project file
├── UART_loopback_tb_behav.wcfg      — waveform configuration
├── UART.srcs/
│   ├── sources_1/new/
│   │   ├── Baud_Rate_Generator.v    — parameterized modulo-N counter
│   │   ├── UART_tx.v                — transmitter FSM (5 states)
│   │   ├── UART_rx.v                — receiver FSM (5 states) + 2-FF sync
│   │   └── UART_top.v               — top-level wrapper
│   └── sim_1/new/
│       ├── UART_tx_tb.v             — standalone transmitter testbench
│       └── UART_loopback_tb.v       — full TX→RX loopback testbench
└── docs/
    ├── UART_Documentation.docx      — full project report (Word)
    ├── generate_doc.py              — script that regenerates the report
    ├── figures/                     — diagram images embedded in the report
    └── screenshots/                 — Vivado simulation waveform captures
```

---

## 5. Component Breakdown

### 5.1 Baud Rate Generator

**File:** `Baud_Rate_Generator.v`

A parameterized modulo-N counter that divides the system clock down to produce a single-cycle pulse (`done`) at 16× the target baud rate. This pulse — referred to as `s_tick` in the TX and RX modules — is the sole timing reference for the entire UART system.

#### Parameters

| Parameter | Default | Description |
|---|---|---|
| `BITS` | 4 | Width of the internal counter and `FINAL_VALUE` input |

#### Ports

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `reset_n` | Input | Active-low asynchronous reset |
| `en` | Input | Counter enable — holds count when low |
| `FINAL_VALUE` | Input | `[BITS-1:0]` — counter rolls over at this value |
| `done` | Output | High for one clock cycle when count == FINAL_VALUE |

#### Operation

The counter increments on every rising clock edge while `en` is high. When the count reaches `FINAL_VALUE`, `done` is asserted for exactly one cycle and the counter resets to zero on the next clock edge.

```
Count:  0  1  2  3  4  5  6  7  0  1  2 ...
done:   0  0  0  0  0  0  0  1  0  0  0 ...
              (FINAL_VALUE = 7)
```

For simulation purposes, `FINAL_VALUE = 0` makes `done` fire every clock cycle, dramatically speeding up testbench runtime.

---

### 5.2 UART Transmitter

**File:** `UART_tx.v`

Converts an 8-bit parallel word into a serial UART frame. Controlled by a 5-state Algorithmic State Machine with Datapath (ASMD).

#### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DBITS` | 8 | Number of data bits per frame |
| `SB_TICK` | 16 | Stop-bit duration in s_ticks (16 = 1 stop bit, 32 = 2 stop bits) |

#### Ports

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `reset_n` | Input | Active-low asynchronous reset |
| `s_tick` | Input | 16× baud rate sampling tick from Baud Rate Generator |
| `tx_start` | Input | Assert high for one cycle to initiate a transmission |
| `parity_select` | Input | `[1:0]` — `2'b00`=none, `2'b01`=even, `2'b10`=odd |
| `tx_din` | Input | `[DBITS-1:0]` — parallel data to transmit |
| `tx_done_tick` | Output | Pulses high for one cycle when the frame is complete |
| `tx` | Output | Serial data output line |

#### State Machine

| State | TX line | Action |
|---|---|---|
| **idle** | 1 | Wait for `tx_start`. On assertion: load `tx_din` into shift register, pre-compute parity bit. |
| **start** | 0 | Drive start bit. Count 16 s_ticks, then move to `data`. |
| **data** | b_reg[0] | Shift out data bits LSB-first, one bit per 16 s_ticks. After last bit, go to `parity` (if enabled) or `stop`. |
| **parity** | p_reg | Transmit pre-computed parity bit for 16 s_ticks, then go to `stop`. |
| **stop** | 1 | Drive stop bit(s) for `SB_TICK` ticks. Assert `tx_done_tick`, return to `idle`. |

**Parity pre-computation:** The parity bit is calculated in the `idle` state when `tx_start` is asserted — before data shifting begins — and stored in `p_reg`. This is necessary because the data shift register `b_reg` is destroyed during the data state.

```
Even parity:  p = ^tx_din       (XOR of all bits)
Odd  parity:  p = ~(^tx_din)    (NXOR of all bits)
```

---

### 5.3 UART Receiver

**File:** `UART_rx.v`

Recovers an 8-bit parallel word from an incoming serial UART frame using 16× oversampling. Includes a 2-FF input synchronizer, parity checking, and frame error detection.

#### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DBITS` | 8 | Number of data bits per frame |
| `SB_TICK` | 16 | Stop-bit duration in s_ticks |

#### Ports

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `reset_n` | Input | Active-low asynchronous reset |
| `rx` | Input | Raw serial data input (asynchronous — passes through synchronizer) |
| `s_tick` | Input | 16× baud rate sampling tick from Baud Rate Generator |
| `parity_select` | Input | `[1:0]` — `2'b00`=none, `2'b01`=even, `2'b10`=odd |
| `rx_dout` | Output | `[DBITS-1:0]` — recovered parallel data |
| `rx_done_tick` | Output | Pulses high for one cycle when a complete frame is received |
| `parity_error` | Output | Pulses high (same cycle as `rx_done_tick`) on parity mismatch |
| `frame_error` | Output | Pulses high (same cycle as `rx_done_tick`) when stop bit is logic 0 |

#### 2-FF Synchronizer

Before entering the FSM, `rx` passes through two flip-flops:

```verilog
always @(posedge clk, negedge reset_n)
    if (~reset_n) { rx_sync, rx_meta } <= 2'b11;
    else          { rx_sync, rx_meta } <= { rx_meta, rx };
```

All FSM logic operates on `rx_sync`.

#### State Machine

| State | Condition to advance | Action |
|---|---|---|
| **idle** | `rx_sync == 0` | Start bit detected. Reset tick counter, go to `start`. |
| **start** | `s_tick` && `s_reg == 7` | Sampled at centre of start bit. Reset counters, go to `data`. |
| **data** | `s_tick` && `s_reg == 15` | Sample `rx_sync`, right-shift into `b_reg`. Repeat for all `DBITS`. Then go to `parity` or `stop`. |
| **parity** | `s_tick` && `s_reg == 15` | Latch `rx_sync` into `p_reg`. Go to `stop`. |
| **stop** | `s_tick` && `s_reg == SB_TICK-1` | Check stop bit and parity. Assert `rx_done_tick`. Return to `idle`. |

#### Error Checking (in `stop` state)

```
frame_error  = ~rx_sync                             // stop bit must be 1
parity_error = (^b_reg) != p_reg    [even parity]
parity_error = (~^b_reg) != p_reg   [odd  parity]
```

Both error signals are combinational and valid on the same clock cycle as `rx_done_tick`.

---

### 5.4 UART Top-Level Wrapper

**File:** `UART_top.v`

Integrates the three sub-modules into a complete full-duplex UART transceiver. The Baud Rate Generator's `done` output is distributed to both TX and RX as their shared `s_tick`.

#### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DBITS` | 8 | Data bits per frame |
| `SB_TICK` | 16 | Stop-bit duration in s_ticks |
| `BRG_BITS` | 4 | Counter width of the Baud Rate Generator |
| `BRG_FINAL` | 7 | Counter limit — set per baud rate formula above |

#### Ports

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `reset_n` | Input | Active-low asynchronous reset |
| `tx_start` | Input | Initiate a transmission |
| `tx_din` | Input | `[DBITS-1:0]` — data to transmit |
| `tx_done_tick` | Output | Transmission complete |
| `tx` | Output | Serial output line |
| `rx` | Input | Serial input line |
| `rx_dout` | Output | `[DBITS-1:0]` — received data |
| `rx_done_tick` | Output | Reception complete |
| `parity_error` | Output | Parity mismatch flag |
| `frame_error` | Output | Missing stop bit flag |
| `parity_select` | Input | `[1:0]` — parity mode (shared by TX and RX) |

#### Internal Block Diagram

```
                         UART_top
 ┌─────────────────────────────────────────────────────┐
 │                                                     │
 │   ┌─────────────────┐      s_tick                   │
 │   │ Baud_Rate_       ├──────────────┐               │
 │   │ Generator        │             │               │
 │   └─────────────────┘             │               │
 │                               ┌───┴──────────┐    │
 │  tx_din ──────────────────────►              ├────► tx
 │  tx_start ────────────────────► UART_tx      │    │
 │  parity_select ───────────────►              ├────► tx_done_tick
 │                               └─────────────┘    │
 │                               ┌─────────────┐    │
 │  rx ──────────────────────────► UART_rx      ├────► rx_dout
 │  parity_select ───────────────►              ├────► rx_done_tick
 │                               │              ├────► parity_error
 │                               └─────────────┘────► frame_error
 │                                                     │
 └─────────────────────────────────────────────────────┘
```

---

## 6. ASMD Charts

### Transmitter ASMD

```
        ┌─────────────────────────────────────────────────────┐
        │                        idle                          │
        │                      tx ← 1                         │
        └────────────────────────┬────────────────────────────┘
                                 │ tx_start == 1
                          s ← 0, b ← tx_din, p ← parity(tx_din)
                                 ▼
        ┌─────────────────────────────────────────────────────┐
        │                       start                          │
        │                      tx ← 0                         │
        └────────────────────────┬────────────────────────────┘
                     s_tick ─────┤
                          s==15? │ Yes → s←0, n←0
                                 ▼
        ┌─────────────────────────────────────────────────────┐
        │                        data                          │
        │                    tx ← b_reg[0]                     │
        └────────────────────────┬────────────────────────────┘
                     s_tick ─────┤
                          s==15? │ Yes → s←0, b←b>>1
                         n==DBITS-1? ─── No → n←n+1
                                 │ Yes
                    parity_select != 0?
                         Yes ────┼──── No
                          ▼               ▼
                       parity           stop
                     tx ← p_reg       tx ← 1
                     (16 ticks)  ─── (SB_TICK ticks)
                                          │ s==SB_TICK-1
                                   tx_done_tick ← 1
                                          ▼
                                        idle
```

### Receiver ASMD

```
        ┌─────────────────────────────────────────────────────┐
        │                        idle                          │
        └────────────────────────┬────────────────────────────┘
                                 │ rx_sync == 0 (start bit)
                              s ← 0
                                 ▼
        ┌─────────────────────────────────────────────────────┐
        │                       start                          │
        └────────────────────────┬────────────────────────────┘
                     s_tick ─────┤
                          s==7?  │ Yes → s←0, n←0  (centre of start bit)
                                 ▼
        ┌─────────────────────────────────────────────────────┐
        │                        data                          │
        └────────────────────────┬────────────────────────────┘
                     s_tick ─────┤
                          s==15? │ Yes → s←0, b←{rx_sync, b[DBITS-1:1]}
                         n==DBITS-1? ─── No → n←n+1
                                 │ Yes
                    parity_select != 0?
                         Yes ────┼──── No
                          ▼               ▼
                        parity           stop
                    sample rx_sync    check stop bit
                    → p_reg        frame_error ← ~rx_sync
                    (16 ticks)  parity_error ← check(b_reg, p_reg)
                                   rx_done_tick ← 1
                                          ▼
                                        idle
```

---

## 7. Testbenches & Simulation

### 7.1 Transmitter Testbench (`UART_tx_tb.v`)

Tests the transmitter module in isolation. The Baud Rate Generator runs with `FINAL_VALUE = 7` (s_tick every 8 clock cycles) for faster simulation. The testbench sends 7 bytes across three parity configurations and observes `tx_done_tick` after each frame.

| # | Data | Parity | Description |
|---|---|---|---|
| 1 | `0xE5` | None | 8N1 baseline |
| 2 | `0x3C` | None | 8N1 |
| 3 | `0xF0` | None | 8N1 |
| 4 | `0xA5` | Even | 8E1 |
| 5 | `0x55` | Even | 8E1 — all alternating bits |
| 6 | `0xAA` | Odd  | 8O1 — all alternating bits |
| 7 | `0xFF` | Odd  | 8O1 — all ones |

Observe the `tx` waveform to verify: start bit (low), 8 data bits LSB-first, parity bit (if enabled), stop bit (high).

### 7.2 Loopback Testbench (`UART_loopback_tb.v`)

Connects the TX output directly to the RX input, testing the complete data path end-to-end. The BRG runs with `FINAL_VALUE = 0` (tick every cycle) for maximum simulation speed. Each test case automatically checks `rx_dout`, `parity_error`, and `frame_error` and prints PASS or FAIL to the console.

| # | Data | Parity | Expected Result |
|---|---|---|---|
| 1 | `0xA5` | None | `rx_dout = 0xA5`, no errors |
| 2 | `0x55` | Even | `rx_dout = 0x55`, no errors |
| 3 | `0xAA` | Odd  | `rx_dout = 0xAA`, no errors |
| 4 | `0xF0` | None | `rx_dout = 0xF0`, no errors |
| 5 | `0x3C` | Even | `rx_dout = 0x3C`, no errors |
| 6 | `0xE5` | Odd  | `rx_dout = 0xE5`, no errors |

Expected console output:
```
--- Test 1: 8N1 (no parity) ---
  PASS | data=0xa5  parity_sel=00  parity_error=0  frame_error=0
--- Test 2: 8E1 (even parity, correct) ---
  PASS | data=0x55  parity_sel=01  parity_error=0  frame_error=0
--- Test 3: 8O1 (odd parity, correct) ---
  PASS | data=0xaa  parity_sel=10  parity_error=0  frame_error=0
...
Simulation complete.
```

---

## 8. How to Simulate

### In Xilinx Vivado

1. Open or create a project and add all `.v` files from `UART.srcs/sources_1/new/` as design sources.
2. Add the testbench files from `UART.srcs/sim_1/new/` as simulation sources.
3. Set the desired testbench as the top simulation module.
4. Click **Run Simulation → Run Behavioral Simulation**.
5. In the Tcl console, type `run all` to run to `$stop`.

### Transmitter testbench

Set `UART_tx_tb` as the simulation top. Observe the `tx` signal on the waveform — you should see a start bit (low) followed by 8 data bits LSB-first, an optional parity bit, then a stop bit (high).

### Loopback testbench

Set `UART_loopback_tb` as the simulation top. The Tcl console will print PASS/FAIL for each test case. On the waveform, compare `tx_din` against `rx_dout` — they should match after each transmission completes.

---

## 9. References

- Chu, P. P. (2008). *FPGA Prototyping by Verilog Examples: Xilinx Spartan-3 Version*. Wiley-Interscience.
- Anas Salah Eddin. *ECE 3300 — Digital Circuit Design Using Verilog*. YouTube playlist.
- Xilinx / AMD. *Vivado Design Suite User Guide: Logic Simulation (UG900)*.
