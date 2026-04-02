`timescale 1ns / 1ps


module mac_engine (
    input wire clk,
    input wire rst,
    input wire clear,  
    input wire enable,  
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    output wire [31:0] acc_out
);

  reg [31:0] accumulator;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      accumulator <= 32'd0;
    end else if (clear) begin
      accumulator <= 32'd0;
    end else if (enable) begin
      accumulator <= accumulator + (a_in * b_in);
    end
  end

  assign acc_out = accumulator;

endmodule