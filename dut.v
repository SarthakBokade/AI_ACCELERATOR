

`timescale 1ns / 1ps


//`include "mac_engine.v"
//`include "dotp_accelerator.v"


//  PIPO1 - clr + en --------------------------------------------------------------------

module PIPO_clr_en(
    output reg [31:0] data_out,
    input wire [31:0] data_in,
    input wire en,
    input wire clr,
    input wire clk,
    input wire reset
);
    always @(posedge clk) begin
        if (reset || clr)
            data_out <= 32'b0;
        else if (en)
            data_out <= data_in;
    end
endmodule


//  PIPO2 - en only --------------------------------------------------------------------

module PIPO_en(
    output reg [31:0] data_out,
    input  wire [31:0] data_in,
    input  wire en,
    input  wire clk,
    input  wire reset
);
    always @(posedge clk) begin
        if (reset)
            data_out <= 32'b0;
        else if (en)
            data_out <= data_in;
    end
endmodule


//  PIPO3 - clr only --------------------------------------------------------------------
module PIPO_clr(
    output reg  [31:0] data_out,
    input  wire [31:0] data_in,
    input  wire clr,
    input  wire clk,
    input  wire reset
);
    always @(posedge clk) begin
        if (reset || clr)
            data_out <= 32'b0;
        else
            data_out <= data_in;
    end
endmodule


//  PIPO4 - no control --------------------------------------------------------------------

module PIPO_none(
    output reg  [31:0] data_out,
    input  wire [31:0] data_in,
    input  wire clk,
    input  wire reset
);
    always @(posedge clk) begin
        if (reset)
            data_out <= 32'b0;
        else
            data_out <= data_in;
    end
endmodule


//  2-to-1 MUX --------------------------------------------------------------------

module mux2to1(
    output wire [31:0] d_out,
    input  wire [31:0] d_in1,
    input  wire [31:0] d_in2,
    input  wire sel
);
    assign d_out = sel ? d_in2 : d_in1;
endmodule

//--------------------------------------------------------------------

//  ALU
//  0=ADD 1=SUB 2=AND 3=OR 4=SLT 5=MUL
//  6=XOR 7=SRL 8=SRA 9=SLTU

// --------------------------------------------------------------------
module ALU(
    output reg  [31:0] out,
    input  wire [31:0] in1,
    input  wire [31:0] in2,
    input  wire [3:0] alu_op,
    output wire zero
);
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR = 4'd3;
    localparam ALU_SLT = 4'd4;
    localparam ALU_MUL = 4'd5;
    localparam ALU_XOR = 4'd6;
    localparam ALU_SRL = 4'd7;
    localparam ALU_SRA = 4'd8;
    localparam ALU_SLTU = 4'd9;

    always @(*) begin
        case (alu_op)
            ALU_ADD : out = in1 + in2;
            ALU_SUB : out = in1 - in2;
            ALU_AND : out = in1 & in2;
            ALU_OR : out = in1 | in2;
            ALU_SLT : out = ($signed(in1) < $signed(in2)) ? 32'd1 : 32'd0;
            ALU_MUL : out = in1 * in2;
            ALU_XOR : out = in1 ^ in2;
            ALU_SRL : out = in1 >> in2[4:0];
            ALU_SRA : out = $signed(in1) >>> in2[4:0];
            ALU_SLTU : out = (in1 < in2) ? 32'd1 : 32'd0;
            default : out = 32'b0;
        endcase
    end

    assign zero = (out == 32'b0);
endmodule


//  Immediate Generator --------------------------------------------------------------------

module immediate_generator(
    input  wire [31:0] instr,
    output reg [31:0] imm
);
    always @(*) begin
        case (instr[6:0])
            7'b0010011, 7'b0000011, 7'b1100111:
                imm = {{20{instr[31]}}, instr[31:20]};
            7'b0100011:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011:
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b1101111:
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            7'b0110111, 7'b0010111:
                imm = {instr[31:12], 12'b0};
            default: imm = 32'b0;
        endcase
    end
endmodule


//  register file  --------------------------------------------------------------------

module register_control(
    input wire clk,
    input wire reset,
    input wire we,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] reg_mem [31:0];
    integer i;

    assign rd1 = (rs1 == 5'b0) ? 32'b0 : ((we && rs1 == rd) ? wd : reg_mem[rs1]);
    assign rd2 = (rs2 == 5'b0) ? 32'b0 : ((we && rs2 == rd) ? wd : reg_mem[rs2]);

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) reg_mem[i] <= 32'b0;
        end else if (we && rd != 5'b0) begin
            reg_mem[rd] <= wd;
        end
    end

endmodule


//  Data Memory - MAC SPECIFIC

module data_memory(
    input  wire clk,
    // Port A (CPU)
    input  wire  cpu_rd,
    input  wire cpu_wr,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output reg  [31:0] cpu_rdata,
    
    // port B
    input  wire [31:0] mac_addr,
    output reg  [31:0] mac_rdata
);
  
  (* ram_init_file = "dmem.mif" *)  
    reg [31:0] data_mem [1023:0];
  

    // cpu port logic
  
    always @(*) begin
        if (cpu_rd)
            cpu_rdata = data_mem[cpu_addr[11:2]];
        else
            cpu_rdata = 32'b0;
    end

    always @(posedge clk) begin
        if (cpu_wr)
            data_mem[cpu_addr[11:2]] <= cpu_wdata;
    end

    // MAC port logic
  
    always @(*) begin
        mac_rdata = data_mem[mac_addr[11:2]];
    end
endmodule


//  Instruction Memory --------------------------------------------------------------------


module instruction_memory(
    input  wire [31:0] instruction_addr,
    output wire [31:0] instruction_data
);
    (* ram_init_file = "imem.mif" *)   
    reg [31:0] instruction_mem [1023:0];
    assign instruction_data = instruction_mem[instruction_addr[11:2]];
endmodule


//  PC Register --------------------------------------------------------------------

module pc_register(
    input  wire clk,
    input  wire en,
    input  wire reset,
    input  wire [31:0] npc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else if (en)
            pc <= npc;
    end
endmodule


//  PC+4 adder

module pc_update(
    input  wire [31:0] pc,
    output wire [31:0] u_pc
);
    assign u_pc = pc + 32'd4;
endmodule

// --------------------------------------------------------------------
//  Branch Target Adder
//  target = PC + imm  (ID_EX_PC4 is PC+4, so subtracted 4 instead of 1)
// --------------------------------------------------------------------

module target_branch(
    input  wire [31:0] pc4,
    input  wire [31:0] imm,
    output wire [31:0] target
);
    assign target = pc4 - 32'd4 + imm;
endmodule


//  Control Unit --------------------------------------------------------------------

module control_unit(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire funct7,

    output reg alu_src,
    output reg [3:0] alu_op,
    output reg branch,
    output reg mem_rd,
    output reg mem_wr,
    output reg reg_wr,
    output reg mem2reg,
    output reg rd_sel,
    output reg [2:0] branch_type,
    output reg is_jal,
    output reg is_jalr
);
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR = 4'd3;
    localparam ALU_SLT = 4'd4;
    localparam ALU_MUL = 4'd5;
    localparam ALU_XOR = 4'd6;
    localparam ALU_SRL = 4'd7;
    localparam ALU_SRA = 4'd8;
    localparam ALU_SLTU = 4'd9;

    always @(*) begin
        alu_src = 1'b0;
        alu_op = ALU_ADD;
        branch = 1'b0;
        mem_rd = 1'b0;
        mem_wr = 1'b0;
        reg_wr = 1'b0;
        mem2reg = 1'b0;
        rd_sel = 1'b0;
        branch_type = 3'b000;
        is_jal = 1'b0;
        is_jalr = 1'b0;

        case (opcode)
            7'b0110011: begin   // R-type
                reg_wr = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7 ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_MUL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            7'b0010011: begin   // I-type ALU
                reg_wr  = 1'b1;
                alu_src = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            7'b0000011: begin   // LW
                alu_src = 1'b1;
                mem_rd = 1'b1;
                reg_wr = 1'b1;
                mem2reg = 1'b1;
                alu_op = ALU_ADD;
            end
            7'b0100011: begin   // SW
                alu_src = 1'b1;
                mem_wr = 1'b1;
                alu_op = ALU_ADD;
            end
            7'b1100011: begin   // Branch
                branch = 1'b1;
                alu_op = ALU_SUB;
                branch_type = funct3;
            end
            7'b1101111: begin   // JAL
                reg_wr = 1'b1;
                is_jal = 1'b1;
                alu_op = ALU_ADD;
            end
            7'b1100111: begin   // JALR
                reg_wr = 1'b1;
                alu_src = 1'b1;
                is_jalr = 1'b1;
                alu_op  = ALU_ADD;
            end
            7'b0110111: begin   // LUI
                reg_wr = 1'b1;
                alu_src = 1'b1;
                rd_sel = 1'b1;
                alu_op = ALU_ADD;
            end
            7'b0010111: begin   // AUIPC
                reg_wr = 1'b1;
                alu_src = 1'b1;
                rd_sel = 1'b1;
                alu_op = ALU_ADD;
            end
        endcase
    end
endmodule


//  Hazard Detection Unit  --------------------------------------------------------------------

module hazard_detection_unit(
    input wire ID_EX_mem_rd,
    input wire [4:0] ID_EX_dest_reg,
    input wire [4:0] IF_ID_rs,
    input wire [4:0] IF_ID_rt,
    output reg PC_en,
    output reg IF_ID_en,
    output reg ID_EX_flush
);
    always @(*) begin
        PC_en  = 1'b1;
        IF_ID_en  = 1'b1;
        ID_EX_flush = 1'b0;
        if (ID_EX_mem_rd &&
            ((ID_EX_dest_reg == IF_ID_rs) || (ID_EX_dest_reg == IF_ID_rt))) begin
            PC_en = 1'b0;
            IF_ID_en = 1'b0;
            ID_EX_flush = 1'b1;
        end
    end
endmodule


//  Forwarding Unit --------------------------------------------------------------------

module forwarding_unit(
    input wire  EX_MEM_reg_wr,
    input wire [4:0] EX_MEM_dest_reg,
    input wire  MEM_WB_reg_wr,
    input wire [4:0] MEM_WB_dest_reg,
    input wire [4:0] ID_EX_rs,
    input  wire [4:0] ID_EX_rt,
    output reg  [1:0] forwardA,
    output reg  [1:0] forwardB
);
    always @(*) begin
        forwardA = 2'b00;
        forwardB = 2'b00;

        if (EX_MEM_reg_wr && (EX_MEM_dest_reg != 5'b0) &&
            (EX_MEM_dest_reg == ID_EX_rs))
            forwardA = 2'b10;

        if (EX_MEM_reg_wr && (EX_MEM_dest_reg != 5'b0) &&
            (EX_MEM_dest_reg == ID_EX_rt))
            forwardB = 2'b10;

        if (MEM_WB_reg_wr && (MEM_WB_dest_reg != 5'b0) &&
            !(EX_MEM_reg_wr && (EX_MEM_dest_reg != 5'b0) &&
              (EX_MEM_dest_reg == ID_EX_rs)) &&
            (MEM_WB_dest_reg == ID_EX_rs))
            forwardA = 2'b01;

        if (MEM_WB_reg_wr && (MEM_WB_dest_reg != 5'b0) &&
            !(EX_MEM_reg_wr && (EX_MEM_dest_reg != 5'b0) &&
              (EX_MEM_dest_reg == ID_EX_rt)) &&
            (MEM_WB_dest_reg == ID_EX_rt))
            forwardB = 2'b01;
    end
endmodule

// ============================================================
//  TOP MODULE (Corrected)
// ============================================================

module top(
    input  wire clk,
    input  wire  reset,
    input  wire  en,
    input  wire IF_ID_en,
    output wire [31:0] pc,
    output wire [31:0] IF_ID_IR,
    //led glow 
    output wire mem_wr_out,
    output wire [31:0] alu_addr_out,
    output wire [31:0] store_data_out
);
  
  
     
    // MAC Unit Internal Wires----------------------

    wire [31:0] mac_result;
    wire mac_done;
    wire [31:0] mac_mem_addr;
    wire [31:0] mac_mem_rdata;
    wire is_mac_access;
    wire is_led_access; // cc
    wire is_ram_access;
    wire branch_taken; 
    wire EX_MEM_is_jal;
    
    localparam ALU_ADD = 4'd0;

    // ── Stall / flush wires --------------------------------------------------------------------
  
    wire hazard_PC_en;
    wire hazard_IF_ID_en;
    wire hazard_ID_EX_flush;
    
    // control flow change wire to flush IF and ID stages.
    wire control_flow_change; 

    // IF STAGE --------------------------------------------------------------------
    wire [31:0] npc, u_pc, instr;
    wire IF_ID_write_en;

    pc_register PC(
        .clk(clk), .en(en & hazard_PC_en),
        .reset(reset), .npc(npc), .pc(pc)
    );

    pc_update PC_INC( .pc(pc), .u_pc(u_pc) );

    instruction_memory IMEM(
        .instruction_addr(pc),
        .instruction_data(instr)
    );

    assign IF_ID_write_en = IF_ID_en & hazard_IF_ID_en;

    // IF/ID Pipeline Registers --------------------------------------------------------------------
    wire [31:0] IF_ID_PC4;
    
    
    PIPO_clr_en IF_ID_IR_REG(
        .data_out(IF_ID_IR), .data_in(instr),
        .en(IF_ID_write_en), .clr(control_flow_change),
        .clk(clk), .reset(reset)
    );

    PIPO_clr_en IF_ID_PC4_REG(
        .data_out(IF_ID_PC4), .data_in(u_pc),
        .en(IF_ID_write_en), .clr(control_flow_change),
        .clk(clk), .reset(reset)
    );

    //  ID STAGE 
    wire [31:0] rd1, rd2, imm;
    wire [31:0] wb_data;

    // forward declarations
    wire MEM_WB_reg_wr;
    wire [4:0] MEM_WB_dest_reg;

    register_control RF(
        .clk(clk),
        .we(MEM_WB_reg_wr),
        .rs1(IF_ID_IR[19:15]),
        .rs2(IF_ID_IR[24:20]),
        .rd (MEM_WB_dest_reg),
        .wd (wb_data),
        .rd1(rd1),
        .rd2(rd2)
    );

    immediate_generator IMM( .instr(IF_ID_IR), .imm(imm) );

    wire [4:0] id_dest_reg;
    assign id_dest_reg = IF_ID_IR[11:7];

    wire id_alu_src, id_branch, id_mem_rd, id_mem_wr;
    wire id_reg_wr, id_mem2reg, id_rd_sel;
    wire [3:0] id_alu_op;
    wire [2:0] id_branch_type;
    wire id_is_jal, id_is_jalr;

    control_unit CU(
        .opcode (IF_ID_IR[6:0]),
        .funct3 (IF_ID_IR[14:12]),
        .funct7 (IF_ID_IR[30]),
        .alu_src (id_alu_src),
        .alu_op (id_alu_op),
        .branch (id_branch),
        .mem_rd (id_mem_rd),
        .mem_wr (id_mem_wr),
        .reg_wr (id_reg_wr),
        .mem2reg (id_mem2reg),
        .rd_sel  (id_rd_sel),
        .branch_type(id_branch_type),
        .is_jal (id_is_jal),
        .is_jalr (id_is_jalr)
    );

    wire [4:0] IF_ID_rs = IF_ID_IR[19:15];
    wire [4:0] IF_ID_rt = IF_ID_IR[24:20];
    wire [4:0] id_rs = IF_ID_IR[19:15];
    wire [4:0] id_rt = IF_ID_IR[24:20];

    //  ID/EX Pipeline Registers --------------------------------------------------------------------
    wire ID_EX_flush_final;
    
    assign ID_EX_flush_final = hazard_ID_EX_flush | control_flow_change;

    wire [31:0] ID_EX_A, ID_EX_B, ID_EX_Imm, ID_EX_PC4;
    wire [4:0]  ID_EX_rs, ID_EX_rt, ID_EX_dest_reg;

    PIPO_clr_en ID_EX_A_REG(
        .clk(clk), .reset(reset),
        .en(1'b1), .clr(ID_EX_flush_final),
        .data_in(rd1), .data_out(ID_EX_A)
    );
    PIPO_clr_en ID_EX_B_REG(
        .clk(clk), .reset(reset),
        .en(1'b1), .clr(ID_EX_flush_final),
        .data_in(rd2), .data_out(ID_EX_B)
    );
    PIPO_clr_en ID_EX_IMM_REG(
        .clk(clk), .reset(reset),
        .en(1'b1), .clr(ID_EX_flush_final),
        .data_in(imm), .data_out(ID_EX_Imm)
    );
    PIPO_clr_en ID_EX_PC4_REG(
        .clk(clk), .reset(reset),
        .en(1'b1), .clr(ID_EX_flush_final),
        .data_in(IF_ID_PC4), .data_out(ID_EX_PC4)
    );

    // ID/EX control signals
    reg ID_EX_alu_src, ID_EX_branch;
    reg ID_EX_mem_rd,  ID_EX_mem_wr;
    reg ID_EX_reg_wr,  ID_EX_mem2reg, ID_EX_rd_sel;
    reg [3:0] ID_EX_alu_op;
    reg [2:0] ID_EX_branch_type;
    reg ID_EX_is_jal, ID_EX_is_jalr;
    reg [4:0] ID_EX_rs_r, ID_EX_rt_r, ID_EX_dest_reg_r;

    assign ID_EX_rs = ID_EX_rs_r;
    assign ID_EX_rt = ID_EX_rt_r;
    assign ID_EX_dest_reg = ID_EX_dest_reg_r;

    always @(posedge clk) begin
        if (reset || ID_EX_flush_final) begin
            ID_EX_alu_src <= 1'b0;
            ID_EX_branch  <= 1'b0;
            ID_EX_mem_rd  <= 1'b0;
            ID_EX_mem_wr  <= 1'b0;
            ID_EX_reg_wr  <= 1'b0;
            ID_EX_mem2reg <= 1'b0;
            ID_EX_rd_sel <= 1'b0;
            ID_EX_alu_op <= ALU_ADD;
            ID_EX_branch_type <= 3'b000;
            ID_EX_is_jal <= 1'b0;
            ID_EX_is_jalr <= 1'b0;
            ID_EX_rs_r <= 5'b0;
            ID_EX_rt_r <= 5'b0;
            ID_EX_dest_reg_r <= 5'b0;
        end else begin
            ID_EX_alu_src <= id_alu_src;
            ID_EX_branch  <= id_branch;
            ID_EX_mem_rd  <= id_mem_rd;
            ID_EX_mem_wr  <= id_mem_wr;
            ID_EX_reg_wr <= id_reg_wr;
            ID_EX_mem2reg <= id_mem2reg;
            ID_EX_rd_sel <= id_rd_sel;
            ID_EX_alu_op <= id_alu_op;
            ID_EX_branch_type <= id_branch_type;
            ID_EX_is_jal <= id_is_jal;
            ID_EX_is_jalr <= id_is_jalr;
            ID_EX_rs_r <= id_rs;
            ID_EX_rt_r <= id_rt;
            ID_EX_dest_reg_r <= id_dest_reg;
        end
    end

    hazard_detection_unit HDU(
        .ID_EX_mem_rd (ID_EX_mem_rd),
        .ID_EX_dest_reg (ID_EX_dest_reg),
        .IF_ID_rs (IF_ID_rs),
        .IF_ID_rt (IF_ID_rt),
        .PC_en (hazard_PC_en),
        .IF_ID_en (hazard_IF_ID_en),
        .ID_EX_flush (hazard_ID_EX_flush)
    );

    //  EX STAGE --------------------------------------------------------------------
    wire [31:0] alu_in2, alu_out, target;
    wire zero;
    wire [1:0] forwardA, forwardB;

    // EX/MEM wires 
    wire EX_MEM_reg_wr;
    wire [4:0]  EX_MEM_dest_reg;
    wire [31:0] EX_MEM_ALUOut;
    //wire        EX_MEM_is_jal; 

    forwarding_unit FU(
        .EX_MEM_reg_wr  (EX_MEM_reg_wr),
        .EX_MEM_dest_reg(EX_MEM_dest_reg),
        .MEM_WB_reg_wr  (MEM_WB_reg_wr),
        .MEM_WB_dest_reg(MEM_WB_dest_reg),
        .ID_EX_rs (ID_EX_rs),
        .ID_EX_rt (ID_EX_rt),
        .forwardA (forwardA),
        .forwardB (forwardB)
    );

    reg [31:0] ALU_srcA, ALU_srcB_pre;

    always @(*) begin
        case (forwardA)
            2'b10: ALU_srcA = EX_MEM_ALUOut;
            2'b01: ALU_srcA = wb_data;
            default: ALU_srcA = ID_EX_A;
        endcase
    end

    always @(*) begin
        case (forwardB)
            2'b10: ALU_srcB_pre = EX_MEM_ALUOut;
            2'b01: ALU_srcB_pre = wb_data;
            default: ALU_srcB_pre = ID_EX_B;
        endcase
    end

    // LUI: force srcA=0; AUIPC: use PC (ID_EX_PC4-4)
    wire [31:0] final_ALU_srcA;
    assign final_ALU_srcA = ID_EX_rd_sel ? 32'b0 : ALU_srcA;

    mux2to1 alu_ip2_sel_MUX(
        .d_in1(ALU_srcB_pre), .d_in2(ID_EX_Imm),
        .sel(ID_EX_alu_src),  .d_out(alu_in2)
    );

    ALU EXEC(
        .in1(final_ALU_srcA), .in2(alu_in2),
        .alu_op(ID_EX_alu_op), .out(alu_out), .zero(zero)
    );

    target_branch BT( .pc4(ID_EX_PC4), .imm(ID_EX_Imm), .target(target) );

// Branch condition evaluation
    reg branch_condition;
    always @(*) begin
        case (ID_EX_branch_type)
            3'b000: branch_condition = zero;
            3'b001: branch_condition = !zero;
            3'b100: branch_condition = ($signed(ALU_srcA) < $signed(ALU_srcB_pre));
            3'b101: branch_condition = ($signed(ALU_srcA) >= $signed(ALU_srcB_pre));
            3'b110: branch_condition = (ALU_srcA < ALU_srcB_pre);
            3'b111: branch_condition = (ALU_srcA >= ALU_srcB_pre);
            default: branch_condition = 1'b0;
        endcase
    end

    assign branch_taken = ID_EX_branch && branch_condition;

    wire jal_taken  = ID_EX_is_jal;
    // forcing LSB to 0
    wire [31:0] jalr_target = (ALU_srcA + ID_EX_Imm) & 32'hfffffffe; 
    wire jalr_taken  = ID_EX_is_jalr;

    // Connecting control flow wire
    assign control_flow_change = (branch_taken === 1'b1) || 
                             (jal_taken    === 1'b1) || 
                             (jalr_taken   === 1'b1);

    // Next PC: JALR > JAL > branch > PC+4 
  
    assign npc = jalr_taken   ? jalr_target :
                 jal_taken    ? target       :
                 branch_taken ? target       :
                                u_pc;

    // EX/MEM Pipeline Registers --------------------------------------------------------------------
  
    wire [31:0] EX_MEM_B, EX_MEM_PC4;
    wire [4:0] EX_MEM_rt;
    wire EX_MEM_mem_rd, EX_MEM_mem_wr, EX_MEM_mem2reg;

    
    PIPO_en EX_MEM_ALU_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(alu_out), .data_out(EX_MEM_ALUOut)
    );
    PIPO_en EX_MEM_B_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(ALU_srcB_pre), .data_out(EX_MEM_B)
    );
    PIPO_en EX_MEM_PC4_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(ID_EX_PC4), .data_out(EX_MEM_PC4)
    );

    reg EX_MEM_mem_rd_r, EX_MEM_mem_wr_r;
    reg EX_MEM_reg_wr_r, EX_MEM_mem2reg_r;
    reg [4:0] EX_MEM_dest_reg_r, EX_MEM_rt_r;
    reg EX_MEM_is_jal_r;

    assign EX_MEM_mem_rd = EX_MEM_mem_rd_r;
    assign EX_MEM_mem_wr = EX_MEM_mem_wr_r;
    assign EX_MEM_reg_wr = EX_MEM_reg_wr_r;
    assign EX_MEM_mem2reg = EX_MEM_mem2reg_r;
    assign EX_MEM_dest_reg = EX_MEM_dest_reg_r;
    assign EX_MEM_rt = EX_MEM_rt_r;
    assign EX_MEM_is_jal = EX_MEM_is_jal_r; // cc

    
    always @(posedge clk) begin
        if (reset) begin 
            EX_MEM_mem_rd_r <= 1'b0;
            EX_MEM_mem_wr_r <= 1'b0;
            EX_MEM_reg_wr_r <= 1'b0;
            EX_MEM_mem2reg_r <= 1'b0;
            EX_MEM_dest_reg_r <= 5'b0;
            EX_MEM_rt_r <= 5'b0;
            EX_MEM_is_jal_r <= 1'b0;
        end else begin
            EX_MEM_mem_rd_r <= ID_EX_mem_rd;
            EX_MEM_mem_wr_r <= ID_EX_mem_wr;
            EX_MEM_reg_wr_r <= ID_EX_reg_wr;
            EX_MEM_mem2reg_r <= ID_EX_mem2reg;
            EX_MEM_dest_reg_r <= ID_EX_dest_reg;
            EX_MEM_rt_r  <= ID_EX_rt;
            EX_MEM_is_jal_r <= ID_EX_is_jal;
        end
    end

   
// MEM STAGE (Fixed for Duplicates) --------------------------------------------------------------------
    
   
    wire [31:0] read_data;
    wire store_forward;
    wire [31:0] store_data;
    
    assign store_forward = MEM_WB_reg_wr &&
                           (MEM_WB_dest_reg != 5'b0) &&
                           (MEM_WB_dest_reg == EX_MEM_rt);
    assign store_data = store_forward ? wb_data : EX_MEM_B;

    // MMIO adddress decoding --------------------------------------------------------------------

    assign is_mac_access = (EX_MEM_ALUOut[31:16] == 16'h4000); 
    assign is_led_access = (EX_MEM_ALUOut == 32'h6000_0000);  
    assign is_ram_access = !is_mac_access && !is_led_access;   

    // MAC Config Registers 
    reg [31:0] mac_addrA, mac_addrB, mac_length;
    reg        mac_start;

    // MAC writting logic 
    always @(posedge clk) begin
        if (reset) begin
            mac_start  <= 1'b0;
            mac_addrA  <= 32'd0;
            mac_addrB  <= 32'd0;
            mac_length <= 32'd0;
        end else if (EX_MEM_mem_wr && is_mac_access) begin
            case (EX_MEM_ALUOut[7:0])
                8'h00: mac_start  <= store_data[0];
                8'h04: mac_addrA  <= store_data;
                8'h08: mac_addrB  <= store_data;
                8'h0C: mac_length <= store_data;
            endcase
        end else begin
            mac_start <= 1'b0; // start signal
        end
    end

    // MAC read logic 
  
    reg [31:0] mac_read_data; 
    always @(*) begin
        case (EX_MEM_ALUOut[7:0])
            8'h00: mac_read_data = {31'd0, mac_done};
            8'h04: mac_read_data = mac_addrA;
            8'h08: mac_read_data = mac_addrB;
            8'h0C: mac_read_data = mac_length;
            8'h10: mac_read_data = mac_result;
            default: mac_read_data = 32'd0;
        endcase
    end

    // --- accelerator insatance ---
    dotp_accelerator MAC_ACCEL (
        .clk(clk), .rst(reset),
        .start(mac_start), .done(mac_done),
        .addrA(mac_addrA), .addrB(mac_addrB), .length(mac_length),
        .mem_addr(mac_mem_addr), .mem_rdata(mac_mem_rdata),
        .result(mac_result)
    );

    // --- updated Dual Port RAM ---
    wire [31:0] ram_read_data; 
    data_memory DMEM(
        .clk(clk),
        // Port A (CPU)
        .cpu_rd(EX_MEM_mem_rd && is_ram_access),
        .cpu_wr(EX_MEM_mem_wr && is_ram_access),
        .cpu_addr(EX_MEM_ALUOut),
        .cpu_wdata(store_data),
        .cpu_rdata(ram_read_data),
        // Port B (MAC)
        .mac_addr(mac_mem_addr),
        .mac_rdata(mac_mem_rdata)
    );

    // final multiplexer
    assign read_data = is_mac_access ? mac_read_data : ram_read_data;
  
 
    // MEM/WB Pipeline Registers --------------------------------------------------------------------
  
    wire [31:0] MEM_WB_ALUOut, MEM_WB_ReadData, MEM_WB_PC4;
    wire MEM_WB_mem2reg;

    PIPO_en MEM_WB_ALU_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(EX_MEM_ALUOut), .data_out(MEM_WB_ALUOut)
    );
    PIPO_en MEM_WB_DATA_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(read_data), .data_out(MEM_WB_ReadData)
    );
    PIPO_en MEM_WB_PC4_REG(
        .clk(clk), .reset(reset), .en(1'b1),
        .data_in(EX_MEM_PC4), .data_out(MEM_WB_PC4)
    );

    reg MEM_WB_reg_wr_r, MEM_WB_mem2reg_r;
    reg [4:0] MEM_WB_dest_reg_r;
    reg MEM_WB_is_jal_r;

    assign MEM_WB_reg_wr = MEM_WB_reg_wr_r;
    assign MEM_WB_mem2reg  = MEM_WB_mem2reg_r;
    assign MEM_WB_dest_reg = MEM_WB_dest_reg_r;

    always @(posedge clk) begin
        if (reset) begin
            MEM_WB_reg_wr_r <= 1'b0;
            MEM_WB_mem2reg_r <= 1'b0;
            MEM_WB_dest_reg_r <= 5'b0;
            MEM_WB_is_jal_r <= 1'b0;
        end else begin
            MEM_WB_reg_wr_r <= EX_MEM_reg_wr;
            MEM_WB_mem2reg_r <= EX_MEM_mem2reg;
            MEM_WB_dest_reg_r <= EX_MEM_dest_reg;
            MEM_WB_is_jal_r <= EX_MEM_is_jal;
        end
    end

    // WB STAGE --------------------------------------------------------------------
    wire [31:0] alu_or_mem;
    mux2to1 WB_MUX(
        .d_in1(MEM_WB_ALUOut), .d_in2(MEM_WB_ReadData),
        .sel(MEM_WB_mem2reg),  .d_out(alu_or_mem)
    );

    // JAL writting return address
    assign wb_data = MEM_WB_is_jal_r ? MEM_WB_PC4 : alu_or_mem;
  
    assign mem_wr_out = EX_MEM_mem_wr;
    assign alu_addr_out = EX_MEM_ALUOut;
    assign store_data_out = store_data;
  
  

endmodule