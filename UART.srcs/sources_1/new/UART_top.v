`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Ahmed Ahmed Nageeb Elbermawy
// Institution:  Menofia University, Faculty of Engineering
//
// Module Name:  UART_top
// Description:  Top-level UART transceiver.
//               Instantiates the Baud Rate Generator, Transmitter, and Receiver
//               and connects them into a complete full-duplex UART system.
//
// Parameters:
//   DBITS     - Data bits per frame (default 8)
//   SB_TICK   - Stop-bit duration in s_ticks (16 = 1 stop bit)
//   BRG_BITS  - Counter width of the Baud Rate Generator
//   BRG_FINAL - Counter limit for the BRG.
//               Formula: BRG_FINAL = (F_clk / (16 * BaudRate)) - 1
//               Examples (100 MHz clock):
//                 9600   baud -> BRG_FINAL = 651  (BRG_BITS >= 10)
//                 115200 baud -> BRG_FINAL = 54   (BRG_BITS >= 6)
//                 Fast sim    -> BRG_FINAL = 0    (BRG_BITS = 4, tick every cycle)
//
// parity_select: 2'b00 = none | 2'b01 = even | 2'b10 = odd
//////////////////////////////////////////////////////////////////////////////////

module UART_top
#(parameter DBITS     = 8,
            SB_TICK   = 16,
            BRG_BITS  = 4,
            BRG_FINAL = 4'd7)
(
    input  wire              clk,
    input  wire              reset_n,

    // Transmitter interface
    input  wire              tx_start,
    input  wire [DBITS-1:0]  tx_din,
    output wire              tx_done_tick,
    output wire              tx,

    // Receiver interface
    input  wire              rx,
    output wire [DBITS-1:0]  rx_dout,
    output wire              rx_done_tick,
    output wire              parity_error,
    output wire              frame_error,

    // Shared configuration
    input  wire [1:0]        parity_select
);

    wire s_tick;

    // ------------------------------------------------------------------
    // Baud Rate Generator
    // ------------------------------------------------------------------
    Baud_Rate_Generator #(.BITS(BRG_BITS)) brg_inst (
        .clk         (clk),
        .reset_n     (reset_n),
        .en          (1'b1),
        .FINAL_VALUE (BRG_FINAL),
        .done        (s_tick)
    );

    // ------------------------------------------------------------------
    // Transmitter
    // ------------------------------------------------------------------
    UART_tx #(.DBITS(DBITS), .SB_TICK(SB_TICK)) tx_inst (
        .clk          (clk),
        .reset_n      (reset_n),
        .s_tick       (s_tick),
        .tx_start     (tx_start),
        .parity_select(parity_select),
        .tx_din       (tx_din),
        .tx_done_tick (tx_done_tick),
        .tx           (tx)
    );

    // ------------------------------------------------------------------
    // Receiver
    // ------------------------------------------------------------------
    UART_rx #(.DBITS(DBITS), .SB_TICK(SB_TICK)) rx_inst (
        .clk          (clk),
        .reset_n      (reset_n),
        .rx           (rx),
        .s_tick       (s_tick),
        .parity_select(parity_select),
        .rx_dout      (rx_dout),
        .rx_done_tick (rx_done_tick),
        .parity_error (parity_error),
        .frame_error  (frame_error)
    );

endmodule
