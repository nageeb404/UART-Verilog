`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:     Ahmed Ahmed Nageeb Elbermawy
// Institution:  Menofia University, Faculty of Engineering
//
// Module Name:  UART_loopback_tb
// Description:  Full loopback testbench — TX output wired directly to RX input.
//               Verifies data integrity and parity detection across the complete
//               TX-to-RX path under multiple configurations.
//
// BRG_FINAL = 0: s_tick fires every clock cycle (fast simulation, not real baud rate)
//////////////////////////////////////////////////////////////////////////////////

module UART_loopback_tb();

    parameter DBITS   = 8;
    parameter SB_TICK = 16;
    parameter BITS    = 4;

    reg              clk;
    reg              reset_n;
    reg              tx_start;
    reg  [DBITS-1:0] tx_din;
    reg  [1:0]       parity_select;

    wire             tx_done_tick;
    wire             rx_done_tick;
    wire             tx;
    wire [DBITS-1:0] rx_dout;
    wire             parity_error;
    wire             frame_error;
    wire             s_tick;

    // ------------------------------------------------------------------
    // Instantiations
    // ------------------------------------------------------------------
    Baud_Rate_Generator #(.BITS(BITS)) uut0 (
        .reset_n     (reset_n),
        .en          (1'b1),
        .clk         (clk),
        .FINAL_VALUE (4'd0),      // tick every cycle — fast simulation
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

    UART_rx #(.DBITS(DBITS), .SB_TICK(SB_TICK)) uut2 (
        .clk          (clk),
        .reset_n      (reset_n),
        .rx           (tx),       // loopback
        .s_tick       (s_tick),
        .parity_select(parity_select),
        .rx_dout      (rx_dout),
        .rx_done_tick (rx_done_tick),
        .parity_error (parity_error),
        .frame_error  (frame_error)
    );

    // ------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------------
    // Task: send one byte and verify reception
    //   In a clean loopback, frame_error and parity_error are always expected 0
    // ------------------------------------------------------------------
    task send_and_verify;
        input [7:0]  data;
        input [1:0]  par_sel;
        input [7:0]  exp_data;
        input        exp_parity_err;
        begin
            @(posedge clk);
            tx_din        <= data;
            parity_select <= par_sel;
            tx_start      <= 1'b1;

            @(posedge clk);
            tx_start <= 1'b0;

            wait(rx_done_tick);
            @(posedge clk);   // let combinational outputs settle

            if (rx_dout === exp_data && parity_error === exp_parity_err && frame_error === 1'b0)
                $display("  PASS | data=0x%02h  parity_sel=%02b  parity_error=%b  frame_error=%b",
                          rx_dout, par_sel, parity_error, frame_error);
            else
                $display("  FAIL | expected data=0x%02h parity_err=%b frame_err=0  |  got data=0x%02h parity_err=%b frame_err=%b",
                          exp_data, exp_parity_err, rx_dout, parity_error, frame_error);

            #100;
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
        #100;

        $display("--- Test 1: 8N1 (no parity) ---");
        send_and_verify(8'hA5, 2'b00, 8'hA5, 1'b0);

        $display("--- Test 2: 8E1 (even parity, correct) ---");
        send_and_verify(8'h55, 2'b01, 8'h55, 1'b0);

        $display("--- Test 3: 8O1 (odd parity, correct) ---");
        send_and_verify(8'hAA, 2'b10, 8'hAA, 1'b0);

        $display("--- Test 4: 8N1 (no parity, different byte) ---");
        send_and_verify(8'hF0, 2'b00, 8'hF0, 1'b0);

        $display("--- Test 5: 8E1 (even parity, 0x3C) ---");
        send_and_verify(8'h3C, 2'b01, 8'h3C, 1'b0);

        $display("--- Test 6: 8O1 (odd parity, 0xE5) ---");
        send_and_verify(8'hE5, 2'b10, 8'hE5, 1'b0);

        #200;
        $display("Simulation complete.");
        $stop;
    end

endmodule
