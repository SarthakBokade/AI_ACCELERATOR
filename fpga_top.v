

`timescale 1ns / 1ps


module fpga_top (
    // pin declaration
    input  wire        FPGA_CLK1_50,   
    input  wire [1:0]  KEY,          
    output wire [7:0]  LED    
);

    
    //  clk divider (50 MHz -> 1 MHz)
 
    localparam CLK_DIV = 25;         
    reg [5:0]  clk_cnt  = 6'd0;
    reg        cpu_clk  = 1'b0;

    always @(posedge FPGA_CLK1_50) begin
        if (clk_cnt == CLK_DIV - 1) begin
            clk_cnt <= 6'd0;
            cpu_clk <= ~cpu_clk;
        end else begin
            clk_cnt <= clk_cnt + 6'd1;
        end
    end
    // clk = 1MHz


    //switch control
  
    localparam DEBOUNCE_CYCLES = 200_000;

    reg [17:0] db_cnt    = 18'd0;
    reg        key_sync0 = 1'b1;   
    reg        key_sync1 = 1'b1;  
    reg        key_db    = 1'b1;   
    reg        cpu_reset = 1'b1;  

    // double-flop synchroniser to handle metastability
    always @(posedge FPGA_CLK1_50) begin
        key_sync0 <= KEY[0];
        key_sync1 <= key_sync0;
    end


    always @(posedge FPGA_CLK1_50) begin
        if (key_sync1 != key_db) begin
            if (db_cnt == DEBOUNCE_CYCLES - 1) begin
                key_db  <= key_sync1;
                db_cnt  <= 18'd0;
            end else begin
                db_cnt  <= db_cnt + 18'd1;
            end
        end else begin
            db_cnt <= 18'd0;
        end
    end

    // press key -> reset happens
    always @(posedge FPGA_CLK1_50) begin
        cpu_reset <= ~key_db;
    end



    wire [31:0] cpu_pc;
    wire [31:0] cpu_ir;

    // Snooped bus signals from the CPU
    wire        cpu_mem_wr;
    wire [31:0] cpu_alu_addr;
    wire [31:0] cpu_store_data;


    top CPU (
        .clk           (cpu_clk),
        .reset         (cpu_reset),
        .en            (1'b1),
        .IF_ID_en      (1'b1),

        // existing outputs
        .pc            (cpu_pc),
        .IF_ID_IR      (cpu_ir),

        // new outputs (add these ports to dut.v - see guide below)
        .mem_wr_out    (cpu_mem_wr),
        .alu_addr_out  (cpu_alu_addr),
        .store_data_out(cpu_store_data)
    );


    // led snooping
  
    localparam LED_MMIO_ADDR = 32'h6000_0000;

    reg [7:0] led_reg = 8'h00;   // power-on: all LEDs off

    always @(posedge cpu_clk) begin
        if (cpu_reset) begin
            led_reg <= 8'h00;
        end else if (cpu_mem_wr && (cpu_alu_addr == LED_MMIO_ADDR)) begin
            led_reg <= cpu_store_data[7:0];
        end
    end

    assign LED = led_reg;   // Active-high


endmodule