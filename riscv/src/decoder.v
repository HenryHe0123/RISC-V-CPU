//Decoder

`include "defines.v"

module decoder(
        input wire [31:0] inst,
        output reg [5:0]  optype,
        output reg [4:0]  rs1, rs2, rd,
        output reg [31:0] imm
        //for slli/srli/srai, shamt = imm[4:0]
    );

    wire [6:0] opcode = inst[6:0];
    wire [2:0] func3 = inst[14:12];
    wire [6:0] func7 = inst[31:25];

    always @(*) begin
        optype = `NOP;
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = 0;
        imm = 0;
        case (opcode)
            `LUIOP: begin
                optype = `LUI;
                rs1 = 0;
                imm = inst[31:12] << 12;
            end
            `AUIPCOP: begin
                optype = `AUIPC;
                rs1 = 0;
                imm = inst[31:12] << 12;
            end
            `JALOP: begin
                optype = `JAL;
                rs1 = 0;
                imm = { {12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0 };
            end
            `JALROP: begin
                optype = `JALR;
                imm = { {21{inst[31]}}, inst[30:20] };
            end
            `ROP: begin
                rs2 = inst[24:20];
                case (func3)
                    3'b000: begin
                        case (func7)
                            7'b0000000:
                                optype = `ADD;
                            7'b0100000:
                                optype = `SUB;
                        endcase
                    end
                    3'b001:
                        optype = `SLL;
                    3'b010:
                        optype = `SLT;
                    3'b011:
                        optype = `SLTU;
                    3'b100:
                        optype = `XOR;
                    3'b101: begin
                        case (func7)
                            7'b0000000:
                                optype = `SRL;
                            7'b0100000:
                                optype = `SRA;
                        endcase
                    end
                    3'b110:
                        optype = `OR;
                    3'b111:
                        optype = `AND;
                endcase
            end
            `IOP: begin
                imm = { {21{inst[31]}}, inst[30:20] };
                case (func3)
                    3'b000:
                        optype = `ADDI;
                    3'b001:
                        optype = `SLLI;
                    3'b010:
                        optype = `SLTI;
                    3'b011:
                        optype = `SLTIU;
                    3'b100:
                        optype = `XORI;
                    3'b101: begin
                        case (func7)
                            7'b0000000:
                                optype = `SRLI;
                            7'b0100000:
                                optype = `SRAI;
                        endcase
                    end
                    3'b110:
                        optype = `ORI;
                    3'b111:
                        optype = `ANDI;
                endcase
            end
            `LOP: begin
                imm = { {21{inst[31]}}, inst[30:20] };
                case (func3)
                    3'b000:
                        optype = `LB;
                    3'b001:
                        optype = `LH;
                    3'b010:
                        optype = `LW;
                    3'b100:
                        optype = `LBU;
                    3'b101:
                        optype = `LHU;
                endcase
            end
            `SOP: begin
                rd = 0;
                rs2 = inst[24:20];
                imm = { {21{inst[31]}}, inst[30:25], inst[11:7] };
                case (func3)
                    3'b000:
                        optype = `SB;
                    3'b001:
                        optype = `SH;
                    3'b010:
                        optype = `SW;
                endcase
            end
            `BOP: begin
                rd = 0;
                rs2 = inst[24:20];
                imm = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
                case (func3)
                    3'b000:
                        optype = `BEQ;
                    3'b001:
                        optype = `BNE;
                    3'b100:
                        optype = `BLT;
                    3'b101:
                        optype = `BGE;
                    3'b110:
                        optype = `BLTU;
                    3'b111:
                        optype = `BGEU;
                endcase
            end
        endcase
    end

endmodule
