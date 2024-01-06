//Arithmetic Logic Unit

`include "defines.v"

module ALU(
        input wire clk, rst, rdy,

        //rs
        input wire             RS_valid,
        input wire [5:0]       RS_op,
        input wire [31:0]      RS_Vj,
        input wire [31:0]      RS_Vk,
        input wire [31:0]      RS_imm,
        input wire [`ROBRange] RS_rdTag,
        input wire [31:0]      RS_pc,

        //cdb-alu
        output reg             bus_enable,
        output reg [31:0]      bus_result, //for br instruction, bus_result = true/false
        output reg [`ROBRange] bus_rdTag,

        //ifetcher (for jalr)
        output reg             jalr_valid,
        output reg [31:0]      jalr_pc
    );

    always @(*) begin
        bus_enable = `False;
        bus_result = 0;
        bus_rdTag = 0;
        jalr_valid = `False;
        jalr_pc = 0;
        if (~rst && rdy && RS_valid && RS_op != `NOP) begin
            bus_enable = `True;
            bus_rdTag = RS_rdTag;
            case (RS_op)
                `LUI:
                    bus_result = RS_imm;
                `AUIPC:
                    bus_result = RS_pc + RS_imm;
                `JAL: begin
                    bus_result = RS_pc + 4;
                end
                `JALR: begin
                    bus_result = RS_pc + 4;
                    jalr_valid = `True;
                    jalr_pc = (RS_Vj + RS_imm) & 32'hFFFFFFFE;
                end
                `BEQ: begin
                    bus_result = RS_Vj == RS_Vk;
                end
                `BNE: begin
                    bus_result = RS_Vj != RS_Vk;
                end
                `BLT: begin
                    bus_result = $signed(RS_Vj) < $signed(RS_Vk);
                end
                `BGE: begin
                    bus_result = $signed(RS_Vj) >= $signed(RS_Vk);
                end
                `BLTU: begin
                    bus_result = RS_Vj < RS_Vk;
                end
                `BGEU: begin
                    bus_result = RS_Vj >= RS_Vk;
                end
                `ADDI:
                    bus_result = RS_Vj + RS_imm;
                `SLTI:
                    bus_result = $signed(RS_Vj) < $signed(RS_imm);
                `SLTIU:
                    bus_result = RS_Vj < RS_imm;
                `XORI:
                    bus_result = RS_Vj ^ RS_imm;
                `ORI:
                    bus_result = RS_Vj | RS_imm;
                `ANDI:
                    bus_result = RS_Vj & RS_imm;
                `SLLI:
                    bus_result = RS_Vj << RS_imm[4:0];
                `SRLI:
                    bus_result = RS_Vj >> RS_imm[4:0];
                `SRAI:
                    bus_result = $signed(RS_Vj) >>> RS_imm[4:0];
                `ADD:
                    bus_result = RS_Vj + RS_Vk;
                `SUB:
                    bus_result = RS_Vj - RS_Vk;
                `SLL:
                    bus_result = RS_Vj <<< RS_Vk[4:0];
                `SLT:
                    bus_result = $signed(RS_Vj) < $signed(RS_Vk) ? 1 : 0;
                `SLTU:
                    bus_result = RS_Vj < RS_Vk ? 1 : 0;
                `XOR:
                    bus_result = RS_Vj ^ RS_Vk;
                `SRL:
                    bus_result = RS_Vj >> RS_Vk[4:0];
                `SRA:
                    bus_result = $signed(RS_Vj) >>> RS_Vk[4:0];
                `OR:
                    bus_result = RS_Vj | RS_Vk;
                `AND:
                    bus_result = RS_Vj & RS_Vk;
            endcase
        end
    end

endmodule
