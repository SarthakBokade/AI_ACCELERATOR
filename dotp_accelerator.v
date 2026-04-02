`timescale 1ns / 1ps



module dotp_accelerator (
    input wire clk,
    input wire rst,

    input  wire start,
    output reg  done,

    input wire [31:0] addrA,
    input wire [31:0] addrB,
    input wire [31:0] length,

    output reg  [31:0] mem_addr,
    input  wire [31:0] mem_rdata,

    output wire [31:0] result
);

  //FSM
  localparam IDLE = 3'd0;
  localparam READ_A = 3'd1;
  localparam READ_B = 3'd2;
  localparam MAC = 3'd3;
  localparam DONE = 3'd4;

  reg [2:0] state;
  reg [31:0] index;
  reg [31:0] a_data;
  reg [31:0] b_data;

  // --- MAC engine control Signals ---
  reg mac_clear;
  reg mac_enable;

  // --- Instantiatiation of MAC engine ---
  mac_engine u_mac (
      .clk    (clk),
      .rst    (rst),
      .clear  (mac_clear),
      .enable (mac_enable),
      .a_in   (a_data),
      .b_in   (b_data),
      .acc_out(result)
  );

  // ---------------- FSM SEQUENTIAL LOGIC ----------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state  <= IDLE;
      index  <= 32'd0;
      done   <= 1'b0;
      a_data <= 32'd0;
      b_data <= 32'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            done  <= 1'b0;  
            index <= 32'd0;
            state <= READ_A;
          end
        end

        READ_A: begin
          a_data <= mem_rdata;
          state  <= READ_B;
        end

        READ_B: begin
          b_data <= mem_rdata;
          state  <= MAC;
        end

        MAC: begin
          index <= index + 1;
          if (index + 1 >= length) state <= DONE;
          else state <= READ_A;
        end

        DONE: begin
          done  <= 1'b1;
          state <= IDLE;  
        end

        default: state <= IDLE;
      endcase
    end
  end

  // ---------------- DATAPATH CONTROL & ADDRESS GEN ----------------
  always @(*) begin
    
    mac_clear  = 1'b0;
    mac_enable = 1'b0;
    mem_addr   = 32'd0;

    case (state)
      IDLE: begin
        if (start) mac_clear = 1'b1;  // clearing accumulator on new run
      end

      READ_A: mem_addr = addrA + (index << 2);

      READ_B: mem_addr = addrB + (index << 2);

      MAC: begin
        // calculating next addr in advance here 
        mem_addr   = addrA + ((index + 1) << 2);
        mac_enable = 1'b1; 
      end

      DONE: mem_addr = 32'd0;

      default: mem_addr = 32'd0;
    endcase
  end

endmodule