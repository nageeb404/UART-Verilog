`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Ahmed Ahmed Nageeb Elbermawy
// Institution:  Menofia University, Faculty of Engineering
//
// Module Name:  UART_tx
// Description:  UART Transmitter FSM.
//               Serializes an 8-bit parallel word into a UART frame:
//               [start bit | data bits LSB-first | optional parity bit | stop bit(s)]
//
// Parameters:
//   DBITS   - Number of data bits (default 8)
//   SB_TICK - Stop-bit duration in s_ticks (16 = 1 stop bit, 24 = 1.5, 32 = 2)
//
// Inputs:
//   parity_select - 2'b00: none | 2'b01: even | 2'b10: odd
//////////////////////////////////////////////////////////////////////////////////

module UART_tx
#(parameter DBITS   = 8,
            SB_TICK = 16)
(
    input  wire              clk, reset_n,
    input  wire              s_tick, tx_start,
    input  wire [1:0]        parity_select,
    input  wire [DBITS-1:0]  tx_din,
    output reg               tx_done_tick,
    output wire              tx
);

    localparam [2:0] idle   = 3'd0,
                     start  = 3'd1,
                     data   = 3'd2,
                     parity = 3'd3,
                     stop   = 3'd4;

    reg [2:0]        state_reg,  state_next;
    reg [3:0]        s_reg,      s_next;
    reg [DBITS-1:0]  b_reg,      b_next;
    reg [$clog2(DBITS):0] n_reg, n_next;
    reg              tx_reg,     tx_next;
    reg              p_reg,      p_next;   // pre-computed parity bit

    // -----------------------------------------------------------------------
    // Present-state registers
    // -----------------------------------------------------------------------
    always @(posedge clk, negedge reset_n)
        if (~reset_n) begin
            state_reg <= idle;
            s_reg     <= 0;
            n_reg     <= 0;
            b_reg     <= 0;
            tx_reg    <= 1'b1;
            p_reg     <= 1'b0;
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            tx_reg    <= tx_next;
            p_reg     <= p_next;
        end

    // -----------------------------------------------------------------------
    // Next-state / output combinational logic
    // -----------------------------------------------------------------------
    always @(*) begin
        // default: hold current values
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        tx_next      = tx_reg;
        p_next       = p_reg;
        tx_done_tick = 1'b0;

        case (state_reg)

            idle: begin
                tx_next = 1'b1;
                if (tx_start) begin
                    s_next     = 0;
                    b_next     = tx_din;
                    // compute parity before shifting starts
                    p_next     = (parity_select == 2'b10) ? ~(^tx_din) : (^tx_din);
                    state_next = start;
                end
            end

            start: begin
                tx_next = 1'b0;            // start bit = logic 0
                if (s_tick)
                    if (s_reg == 15) begin
                        s_next     = 0;
                        n_next     = 0;
                        state_next = data;
                    end else
                        s_next = s_reg + 1;
            end

            data: begin
                tx_next = b_reg[0];        // LSB first
                if (s_tick)
                    if (s_reg == 15) begin
                        s_next = 0;
                        b_next = {1'b0, b_reg[DBITS-1:1]};
                        if (n_reg == DBITS-1)
                            state_next = (parity_select != 2'b00) ? parity : stop;
                        else
                            n_next = n_reg + 1;
                    end else
                        s_next = s_reg + 1;
            end

            parity: begin
                tx_next = p_reg;           // transmit pre-computed parity bit
                if (s_tick)
                    if (s_reg == 15) begin
                        s_next     = 0;
                        state_next = stop;
                    end else
                        s_next = s_reg + 1;
            end

            stop: begin
                tx_next = 1'b1;            // stop bit = logic 1
                if (s_tick)
                    if (s_reg == SB_TICK-1) begin
                        tx_done_tick = 1'b1;
                        state_next   = idle;
                    end else
                        s_next = s_reg + 1;
            end

            default: state_next = idle;

        endcase
    end

    // -----------------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------------
    assign tx = tx_reg;

endmodule
