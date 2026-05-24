`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2026 10:50:03 PM
// Design Name: 
// Module Name: Baud_Rate_Generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Baud_Rate_Generator #(parameter BITS = 4) (

    input reset_n,
    input en,
    input clk,
    input [ BITS-1 : 0 ]FINAL_VALUE,
    output done

    );
    
    // Present State Logic
    
      reg [BITS-1:0] Q_reg,Q_next;
      
   always @(posedge clk, negedge reset_n)
   
        if (~reset_n)
            Q_reg <= 'b0;
        else if (en)
            Q_reg <= Q_next;
        else
            Q_reg <= Q_reg;
                    
    // Next State Logic
    
        assign done = Q_reg == FINAL_VALUE;
        
        always @(*)
            Q_next = done? 'b0 : Q_reg + 1;
        
    
    
    
endmodule
