`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Ahmed Ahmed Nageeb Elbermawy
// Institution:  Menofia University, Faculty of Engineering
//
// Module Name:  UART_tx_tb
// Description:  Transmitter-only testbench.
//               Sends multiple bytes across three parity modes and observes the
//               TX waveform and tx_done_tick handshake.
//
// BRG_FINAL = 7: s_tick fires every 8 clock cycles (fast simulation)
//////////////////////////////////////////////////////////////////////////////////

module UART_tx_tb();

    parameter DBITS   = 8;
    parameter SB_TICK = 16;
    parameter BITS    = 4;

    reg              clk;
    reg              reset_n;
    reg              tx_start;
    reg  [DBITS-1:0] tx_din;
    reg  [1:0]       parity_select;

    wire             tx_done_tick;
    wire             tx;
    wire             s_tick;

    // ------------------------------------------------------------------
    // Instantiations
    // ------------------------------------------------------------------
    Baud_Rate_Generator #(.BITS(BITS)) uut0 (
        .reset_n     (reset_n),
        .en          (1'b1),
        .clk         (clk),
        .FINAL_VALUE (4'd7),
        .done        (s_tick)
    );

    UART_tx #(.DBITS(DBITS), .SB_TICK(SB_TICK)) uut1 (
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
    // Clock
    // ------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------
    // Task: assert tx_start for one cycle then wait for tx_done_tick
    // ------------------------------------------------------------------
    task send_byte;
        input [7:0] data;
        input [1:0] par_sel;
        begin
            @(posedge clk);
            tx_din        <= data;
            parity_select <= par_sel;
            tx_start      <= 1'b1;

            @(posedge clk);
            tx_start <= 1'b0;

            wait(tx_done_tick);
        end
    endtask

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    initial begin
        reset_n       = 1'b0;
        tx_start      = 1'b0;
        tx_din        = 8'd0;
        parity_select = 2'b00;

        #50;
        reset_n = 1'b1;
        #50;

        // No parity
        send_byte(8'hE5, 2'b00);
        send_byte(8'h3C, 2'b00);
        send_byte(8'hF0, 2'b00);

        // Even parity
        send_byte(8'hA5, 2'b01);
        send_byte(8'h55, 2'b01);

        // Odd parity
        send_byte(8'hAA, 2'b10);
        send_byte(8'hFF, 2'b10);

        #200;
        $display("Simulation completed successfully.");
        $stop;
    end

endmodule
