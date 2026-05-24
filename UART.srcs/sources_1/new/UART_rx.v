`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Ahmed Ahmed Nageeb Elbermawy
// Institution:  Menofia University, Faculty of Engineering
//
// Module Name:  UART_rx
// Description:  UART Receiver FSM.
//               Uses 16x oversampling to recover serial data into an 8-bit word.
//               Samples the start bit centre at tick 7, each data bit at tick 15.
//               Optionally checks an even or odd parity bit.
//
//               The raw rx input passes through a 2-FF synchronizer before
//               entering the FSM to prevent metastability from propagating.
//
// Parameters:
//   DBITS   - Number of data bits (default 8)
//   SB_TICK - Stop-bit duration in s_ticks (16 = 1 stop bit)
//
// Inputs:
//   parity_select - 2'b00: none | 2'b01: even | 2'b10: odd
//
// Outputs:
//   rx_done_tick - pulses high for one cycle when a complete frame is received
//   parity_error - pulses high (same cycle as rx_done_tick) on a parity mismatch
//   frame_error  - pulses high (same cycle as rx_done_tick) when the stop bit is 0
//////////////////////////////////////////////////////////////////////////////////

module UART_rx
#(parameter DBITS   = 8,
            SB_TICK = 16)
(
    input  wire              clk, reset_n,
    input  wire              rx, s_tick,
    input  wire [1:0]        parity_select,
    output wire [DBITS-1:0]  rx_dout,
    output reg               rx_done_tick,
    output reg               parity_error,
    output reg               frame_error
);

    localparam [2:0] idle   = 3'd0,
                     start  = 3'd1,
                     data   = 3'd2,
                     parity = 3'd3,
                     stop   = 3'd4;

    // -----------------------------------------------------------------------
    // 2-FF synchronizer — prevents metastability on the asynchronous rx input
    // Both FFs reset to 1 (UART idle line is logic high)
    // -----------------------------------------------------------------------
    reg rx_meta, rx_sync;

    always @(posedge clk, negedge reset_n)
        if (~reset_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end

    // -----------------------------------------------------------------------
    // State and datapath registers
    // -----------------------------------------------------------------------
    reg [2:0]             state_reg,  state_next;
    reg [3:0]             s_reg,      s_next;
    reg [$clog2(DBITS):0] n_reg,      n_next;
    reg [DBITS-1:0]       b_reg,      b_next;
    reg                   p_reg,      p_next;   // received parity bit

    always @(posedge clk, negedge reset_n)
        if (~reset_n) begin
            state_reg <= idle;
            s_reg     <= 0;
            n_reg     <= 0;
            b_reg     <= 0;
            p_reg     <= 1'b0;
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            p_reg     <= p_next;
        end

    // -----------------------------------------------------------------------
    // Next-state / output combinational logic
    // All FSM inputs use rx_sync, not the raw rx port
    // -----------------------------------------------------------------------
    always @(*) begin
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        p_next       = p_reg;
        rx_done_tick = 1'b0;
        parity_error = 1'b0;
        frame_error  = 1'b0;

        case (state_reg)

            idle: begin
                if (~rx_sync) begin            // start bit: falling edge on synchronised rx
                    s_next     = 0;
                    state_next = start;
                end
            end

            start:
                if (s_tick)
                    if (s_reg == 7) begin      // centre of start bit
                        s_next     = 0;
                        n_next     = 0;
                        b_next     = 0;
                        state_next = data;
                    end else
                        s_next = s_reg + 1;

            data:
                if (s_tick)
                    if (s_reg == 15) begin     // centre of each data bit
                        s_next = 0;
                        b_next = {rx_sync, b_reg[DBITS-1:1]};  // right-shift in
                        if (n_reg == DBITS-1)
                            state_next = (parity_select != 2'b00) ? parity : stop;
                        else
                            n_next = n_reg + 1;
                    end else
                        s_next = s_reg + 1;

            parity:
                if (s_tick)
                    if (s_reg == 15) begin     // centre of parity bit
                        s_next     = 0;
                        p_next     = rx_sync;  // latch received parity bit
                        state_next = stop;
                    end else
                        s_next = s_reg + 1;

            stop:
                if (s_tick)
                    if (s_reg == SB_TICK-1) begin
                        rx_done_tick = 1'b1;
                        // frame error: stop bit must be logic 1
                        frame_error  = ~rx_sync;
                        // parity check (only valid when no frame error)
                        if (parity_select == 2'b01)
                            parity_error = ((^b_reg) != p_reg);
                        else if (parity_select == 2'b10)
                            parity_error = ((~^b_reg) != p_reg);
                        state_next = idle;
                        s_next     = 0;
                    end else
                        s_next = s_reg + 1;

            default: state_next = idle;

        endcase
    end

    // -----------------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------------
    assign rx_dout = b_reg;

endmodule
