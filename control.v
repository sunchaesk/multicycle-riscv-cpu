

/*
 CYCLE1: Fetch the instruction, increment the program counter
 CYCLE2: decode: decode the instruction that was provided from IR reg
 */

module control (
                input            clk,
                input            reset,
                input            zero_flag, // signal whether to take the branch or not
                input            branch_taken,
                input [6:0]      opcode,
                input [2:0]      funct3,
                input [6:0]      funct7,
                output reg       mem_write,
                output reg       reg_write,
                output reg       ir_write,
                output reg       pc_write,
                output reg       instruction_or_data,
                output reg [1:0] result_src,
                output reg [1:0] alu_src_a,
                output reg [1:0] alu_src_b,
                output reg [2:0] branch_type,
                output reg [3:0] alu_control,
                output [3:0]     current_state
                );

   localparam                    FETCH = 4'b0000;
   localparam                    DECODE = 4'b0001;
   localparam                    MEM_ADR = 4'b0010;
   localparam                    MEM_RD = 4'b0011;
   localparam                    MEM_WB = 4'b0100;
   localparam                    MEM_WR = 4'b0101;
   localparam                    EXECUTE_R = 4'b0110;
   localparam                    ALU_WB = 4'b0111;
   localparam                    EXECUTE_I = 4'b1000;
   localparam                    JUMP = 4'b1001;
   localparam                    BRANCH = 4'b1010;

   localparam                    OP_LW = 7'b0000011;
   localparam                    OP_SW = 7'b0100011;
   localparam                    OP_R = 7'b0110011;
   localparam                    OP_B = 7'b1100011;
   localparam                    OP_I = 7'b0010011;
   localparam                    OP_J = 7'b1101111;

   reg [3:0]                     curr_state, next_state;

   always @(posedge clk or posedge reset) begin
      if (reset) begin
         curr_state <= FETCH;
      end else begin
         curr_state <= next_state;
      end
   end

   always @(*) begin
      case (curr_state)
        FETCH: next_state = DECODE;
        DECODE: case (opcode)
                  OP_LW: next_state = MEM_ADR;
                  OP_SW: next_state = MEM_ADR;
                  OP_R: next_state = EXECUTE_R;
                  OP_I: next_state = EXECUTE_I;
                  OP_J: next_state = JUMP;
                  OP_B: next_state = BRANCH;
                endcase
        MEM_ADR: case (opcode)
                   OP_LW: next_state = MEM_RD;
                   OP_SW: next_state = MEM_WR;
                 endcase
        MEM_RD: next_state = MEM_WB;
        MEM_WR: next_state = FETCH;
        MEM_WB: next_state = FETCH;
        EXECUTE_R: next_state = ALU_WB;
        EXECUTE_I: next_state = ALU_WB;
        JUMP: next_state = ALU_WB;
        ALU_WB: next_state = FETCH;
        BRANCH: next_state = FETCH;
        default: next_state = FETCH;
      endcase
   end

   assign current_state = curr_state;

   always @(*) begin
      mem_write = 1'b0;
      reg_write = 1'b0;
      ir_write = 1'b0;
      pc_write = 1'b0;
      instruction_or_data = 1'b0;
      result_src = 2'b0;
      alu_src_b = 2'b0;
      branch_type = 3'b0;
      alu_control = 4'b0;
      case (curr_state)
        FETCH: begin
           pc_write = 1; // Enable PC write
           ir_write = 1; // Enable IR write
           instruction_or_data = 0; // Accessing instruction memory
           alu_control = 4'b0000; // ALU performs addition
           alu_src_a = 2'b00; // ALU source A is PC
           alu_src_b = 2'b01; // ALU source B is 4
           result_src = 2'b10; //
        end
        DECODE: begin
           // NOTE: during the BRANCH instruction, the decode phase
           // can be used to calculate the target address in the case of
           // BRANCH instruction
           alu_src_a = 2'b10; // old_pc
           alu_src_b = 2'b10; // immediate
           alu_control = 4'b0000; // ALU add : calculate potential branch location
        end
        MEM_ADR: begin
           alu_control = 4'b0000; // ALU performs addition
           alu_src_a = 2'b01; // ALU source A is rs1
           alu_src_b = 2'b10; // ALU source B is immediate
        end
        MEM_RD: begin
           result_src = 2'b00; // alu_out
           instruction_or_data = 1; // Accessing data memory
        end
        MEM_WR: begin // mem_write
           result_src = 2'b00; // alu_out
           instruction_or_data = 1'b1; // accessing data memory
           mem_write = 1'b1; // write to memory
        end
        MEM_WB: begin
           result_src = 2'b01; // Data memory output
           reg_write = 1'b1; // Enable register write
        end
        EXECUTE_R: begin
           alu_src_a = 2'b01; // rs1 data
           alu_src_b = 2'b00; // rs2 data
           alu_control = {funct7[5], funct3}; // add op
        end
        ALU_WB: begin
           result_src = 2'b00; // alu_out reg
           reg_write = 1'b1; // enable regwrite signal
        end
        EXECUTE_I: begin
           alu_src_a = 2'b01; // rs1 data
           alu_src_b = 2'b10; // imm
           alu_control = {funct7[5], funct3}; // add op
        end
        JUMP: begin
           alu_src_a = 2'b10; // old_pc
           alu_src_b = 2'b01; // 4
           alu_control = 4'b0000; // add op to calc old_pc + 4
           result_src = 2'b00; // using alu_out which is jump address calculated previously
           pc_write = 1'b1; // write the jump address calculated in DECODE state to next_pc
        end
        BRANCH: begin
           alu_src_a = 2'b01; // rs1 data
           alu_src_b = 2'b00; // rs2 data
           result_src = 2'b00;
           branch_type = funct3;
           if (branch_taken == 1'b1) begin
              pc_write = 1'b1;
           end
        end
      endcase
   end
endmodule
