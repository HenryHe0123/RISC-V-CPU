//Reservation Station

`include "defines.v"

module RS(
        input wire clk, rst, rdy,

        //issue
        input wire             issue_valid,
        input wire [5:0]       issue_op,
        input wire [`ROBRange] issue_Qj,
        input wire [`ROBRange] issue_Qk,
        input wire [31:0]      issue_Vj,
        input wire [31:0]      issue_Vk,
        input wire             issue_Rj,
        input wire             issue_Rk,
        input wire [31:0]      issue_imm,
        input wire [`ROBRange] issue_rdTag,
        input wire [31:0]      issue_pc,

        //alu
        output reg             ALU_enable,
        output reg [5:0]       op_to_ALU,
        output reg [31:0]      Vj_to_ALU,
        output reg [31:0]      Vk_to_ALU,
        output reg [31:0]      imm_to_ALU,
        output reg [`ROBRange] rdTag_to_ALU,
        output reg [31:0]      pc_to_ALU,

        //cdb-alu
        input wire             B_ALU_valid,
        input wire [31:0]      B_ALU_result,
        input wire [`ROBRange] B_ALU_rdTag,

        //cdb-lsb
        input wire             B_LSB_valid,
        input wire [31:0]      B_LSB_result,
        input wire [`ROBRange] B_LSB_rdTag,

        //commit
        input wire             commit_valid,
        input wire [31:0]      commit_rdVal,
        input wire [`ROBRange] commit_rdTag,

        input wire             rollback,
        output reg             RS_full
    );

    reg  [`RSSize - 1:0] busy;
    reg  [5:0]           op    [`RSSize - 1:0];
    reg  [31:0]          Vj    [`RSSize - 1:0];
    reg  [31:0]          Vk    [`RSSize - 1:0];
    reg  [`RSSize - 1:0] Rj;
    reg  [`RSSize - 1:0] Rk;
    reg  [`ROBRange]     Qj    [`RSSize - 1:0];
    reg  [`ROBRange]     Qk    [`RSSize - 1:0];
    reg  [31:0]          imm   [`RSSize - 1:0];
    reg  [`ROBRange]     rdTag [`RSSize - 1:0];
    reg  [31:0]          pc    [`RSSize - 1:0];

    wire [`RSSize - 1:0] ready = Rj & Rk & busy;
    wire [`RSSize - 1:0] ready_pos = ready & (-ready); //only first ready position 1
    wire [`RSSize - 1:0] free_pos = (~busy) & (-(~busy)); //only first free position 1

    integer i;

    always @(posedge clk) begin
        if (rst || rollback) begin
            busy <= 0;
            Rj   <= 0;
            Rk   <= 0;
            RS_full <= `False;
            ALU_enable <= `False;
        end
        else if (rdy) begin
            if (issue_valid) begin
                for (i = 0; i < `RSSize; i = i + 1) begin
                    if (free_pos[i]) begin
                        busy[i]  <= `True;
                        op[i]    <= issue_op;
                        Vj[i]    <= issue_Vj;
                        Vk[i]    <= issue_Vk;
                        Rj[i]    <= issue_Rj;
                        Rk[i]    <= issue_Rk;
                        Qj[i]    <= issue_Qj;
                        Qk[i]    <= issue_Qk;
                        imm[i]   <= issue_imm;
                        rdTag[i] <= issue_rdTag;
                        pc[i]    <= issue_pc;
                    end
                end
            end

            if (ready_pos != 0) begin
                ALU_enable <= `True;
                for (i = 0; i < `RSSize; i = i + 1) begin
                    if (ready_pos[i]) begin
                        busy[i]     <= `False;
                        op_to_ALU   <= op[i];
                        Vj_to_ALU   <= Vj[i];
                        Vk_to_ALU   <= Vk[i];
                        imm_to_ALU  <= imm[i];
                        rdTag_to_ALU<= rdTag[i];
                        pc_to_ALU   <= pc[i];
                    end
                end
            end
            else begin
                ALU_enable <= `False;
            end

            if (B_ALU_valid) begin
                for (i = 0; i < `RSSize; i = i + 1) begin
                    if (busy[i]) begin
                        if (~Rj[i] && Qj[i] == B_ALU_rdTag) begin
                            Rj[i] <= `True;
                            Vj[i] <= B_ALU_result;
                        end
                        if (~Rk[i] && Qk[i] == B_ALU_rdTag) begin
                            Rk[i] <= `True;
                            Vk[i] <= B_ALU_result;
                        end
                    end
                end
            end

            if (B_LSB_valid) begin
                for (i = 0; i < `RSSize; i = i + 1) begin
                    if (busy[i]) begin
                        if (~Rj[i] && Qj[i] == B_LSB_rdTag) begin
                            Rj[i] <= `True;
                            Vj[i] <= B_LSB_result;
                        end
                        if (~Rk[i] && Qk[i] == B_LSB_rdTag) begin
                            Rk[i] <= `True;
                            Vk[i] <= B_LSB_result;
                        end
                    end
                end
            end

            if (commit_valid) begin
                for (i = 0; i < `RSSize; i = i + 1) begin
                    if (busy[i]) begin
                        if (~Rj[i] && Qj[i] == commit_rdTag) begin
                            Rj[i] <= `True;
                            Vj[i] <= commit_rdVal;
                        end
                        if (~Rk[i] && Qk[i] == commit_rdTag) begin
                            Rk[i] <= `True;
                            Vk[i] <= commit_rdVal;
                        end
                    end
                end
            end

            if (free_pos == 0) begin
                RS_full <= `True;
            end
            else begin
                RS_full <= `False;
            end
        end
    end

endmodule
