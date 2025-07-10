`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.12.2015 18:04:09
// Design Name: 
// Module Name: product_sat
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
/*
###############################################################################
#    pyrpl - DSP servo controller for quantum optics with the RedPitaya
#    Copyright (C) 2014-2016  Leonhard Neuhaus  (neuhaus@spectro.jussieu.fr)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
############################################################################### 
*/


module red_pitaya_product_sat
#( parameter BITS_IN1 = 50,
   parameter BITS_IN2 = 50,
   parameter BITS_OUT = 50,
   parameter SHIFT = 10
)
(
    input clk,
    input signed [BITS_IN1-1:0] factor1_i,
    input signed [BITS_IN2-1:0] factor2_i,
    output signed [BITS_OUT-1:0] product_o,
    output overflow
    );
wire signed [BITS_IN1+BITS_IN2-1:0] product;
//assign product = factor1_i*factor2_i;
// simple saturation added:

reg signed [BITS_IN1+BITS_IN2-1:0] product_reg;

always @(posedge clk) begin
    product_reg <= factor1_i * factor2_i + $signed(1 << (SHIFT-1));
end

reg signed [BITS_OUT-1:0] product_o_reg;
reg overflow_reg;

always @(posedge clk) begin
    if ({product_reg[BITS_IN1+BITS_IN2-1], |product_reg[BITS_IN1+BITS_IN2-2:SHIFT+BITS_OUT-1]} == 2'b01) //positive overflow
        {product_o_reg, overflow_reg} <= {{1'b0,{BITS_OUT-1{1'b1}}}, 1'b1};
    else if ({product_reg[BITS_IN1+BITS_IN2-1], &product_reg[BITS_IN1+BITS_IN2-2:SHIFT+BITS_OUT-1]} == 2'b10) //negative overflow
        {product_o_reg, overflow_reg} <= {{1'b1,{BITS_OUT-1{1'b0}}}, 1'b1};
    else //correct value
        {product_o_reg, overflow_reg} <= {product_reg[SHIFT+BITS_OUT-1:SHIFT], 1'b0};
end

assign product_o = product_o_reg;
assign overflow = overflow_reg;

endmodule
