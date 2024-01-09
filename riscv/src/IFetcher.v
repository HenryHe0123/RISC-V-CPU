//Instruction Fetcher
//including predictor and decoder

`include "predictor.v"
`include "decoder.v"

module IFetcher(
        input wire clk, rst, rdy,

        //icache
        input  wire        icache_hit,
        input  wire [31:0] icache_inst,
        output wire [31:0] pc_to_icache,

        //issue (to several modules)
        //issue_rdTag/Q/V/R are also controlled by issue_valid signal
        output reg         issue_valid,
        output wire [31:0] issue_inst, 
        output reg  [31:0] issue_pc,
        output wire        issue_predict,

        //decode
        output reg [5:0]  issue_optype,
        output reg [4:0]  issue_rs1,
        output reg [4:0]  issue_rs2,
        output reg [4:0]  issue_rd,
        output reg [31:0] issue_imm,

        //alu
        input wire        jalr_valid, // jalr compute finished at ALU
        input wire [31:0] jalr_pc,

        //rob
        input wire        ROB_full,
        input wire        rollback, // ROB branch wrong
        input wire [31:0] ROB_reset_pc, // reset pc for rollback

        //predict update
        input wire ROB_predict_updFlag,
        input wire ROB_branch_updResult,    // 0: not taken, 1: taken (the true result)
        input wire [31:0] ROB_branch_updPC, // the pc of the branch instruction

        //other
        input wire LSB_full,
        input wire RS_full
    );

    reg [31:0] pc;
    reg        stall; //stall ifetch when meet jalr
    wire       predict;

    assign pc_to_icache = pc;
    assign issue_predict = predict;
    assign issue_inst = icache_inst;

    predictor _predictor(
                  .clk(clk),
                  .rst(rst),
                  .rdy(rdy),
                  .pc(pc),
                  .predict(predict),
                  .update_flag(ROB_predict_updFlag),
                  .update_pc(ROB_branch_updPC),
                  .update_result(ROB_branch_updResult)
              );

    wire [6:0]  opcode = icache_inst[6:0];
    wire [5:0]  optype;
    wire [4:0]  rs1, rs2, rd;
    wire [31:0] imm;

    decoder _decoder(
                .inst(icache_inst),
                .optype(optype),
                .rs1(rs1),
                .rs2(rs2),
                .rd(rd),
                .imm(imm)
            );

    always @(posedge clk) begin
        if (rst) begin
            pc <= 0;
            stall <= `False;
        end
        else if (rdy) begin
            if (rollback) begin
                pc <= ROB_reset_pc;
                stall <= `False;
                issue_valid <= `False;
            end
            else if(jalr_valid) begin
                pc <= jalr_pc;
                stall <= `False;
                issue_valid <= `False;
            end
            else if (stall || ROB_full || LSB_full || RS_full) begin
                issue_valid <= `False; //stall issue and ifetch
            end
            else begin
                if (icache_hit) begin
                    issue_valid <= `True;
                    //prepare to issue
                    issue_pc <= pc;
                    issue_optype <= optype;
                    issue_rs1 <= rs1;
                    issue_rs2 <= rs2;
                    issue_rd <= rd;
                    issue_imm <= imm;
                    //update pc or stall for jalr
                    if ((opcode == `BOP && predict) || opcode == `JALOP) begin
                        pc <= pc + imm; //branch taken or jal
                    end
                    else if(opcode == `JALROP) begin
                        stall <= `True;
                    end
                    else begin
                        pc <= pc + 4;
                    end
                end
                else begin
                    issue_valid <= `False;
                end
            end
        end
    end

endmodule
