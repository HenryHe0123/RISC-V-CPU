//Instruction Fetcher
//including predictor and decoder

`include "predictor.v"
`include "decoder.v"

module IFetcher(
        input wire clk, rst, rdy

        //icache
        input  wire        icache_valid,
        input  wire [31:0] icache_inst,
        output wire        icache_enable,
        output wire [31:0] pc_to_icache,

        //issue
        output reg         issue_enable,
        output wire [31:0] inst_to_issue,
        output reg  [31:0] pc_to_issue,
        output wire        predict_to_issue,

        //decode
        output reg [5:0]  optype_to_issue,
        output reg [4:0]  rs1_to_issue,
        output reg [4:0]  rs2_to_issue,
        output reg [4:0]  rd_to_issue,
        output reg [31:0] imm_to_issue,

        //rob
        input wire        ROB_full,
        input wire        ROB_jump_flag, //1: jalr/branch(wrong)
        input wire [31:0] ROB_target_pc, //target pc when jump flag is true

        //predict
        input wire ROB_predict_flag,     //1: branch
        input wire ROB_branch_result,    //0: not taken, 1: taken (the true result)
        input wire [31:0] ROB_branch_pc, //the pc of the branch instruction

        //other
        input wire LSB_full,
        input wire RS_full
    );

    reg [31:0] pc;
    reg        stall; //stall ifetch when meet jalr
    wire       predict;

    assign pc_to_icache = pc;
    assign predict_to_issue = predict;
    assign inst_to_issue = icache_inst;
    assign icache_enable = ~(stall || ROB_full || LSB_full || RS_full);

    predictor _predictor(
                  .clk(clk),
                  .rst(rst),
                  .rdy(rdy),
                  .pc(pc),
                  .predict(predict),
                  .update_flag(ROB_predict_flag),
                  .update_pc(ROB_branch_pc),
                  .update_result(ROB_branch_result),
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
            if (ROB_jump_flag) begin
                pc <= target_pc;
                stall <= `False;
                issue_enable <= `False;
            end
            else if (stall || ROB_full || LSB_full || RS_full) begin
                issue_enable <= `False; //stall issue and ifetch
            end
            else begin
                if (icache_valid) begin
                    issue_enable <= `True;
                    //prepare to issue
                    pc_to_issue <= pc;
                    optype_to_issue <= optype;
                    rs1_to_issue <= rs1;
                    rs2_to_issue <= rs2;
                    rd_to_issue <= rd;
                    imm_to_issue <= imm;
                    //update pc or stall for jalr
                    if ((opcode == `BOP && predict) || opcode == `JAL) begin
                        pc <= pc + imm; //branch taken or jal
                    end
                    else if(opcode == `JALR) begin
                        stall <= `True;
                    end
                    else begin
                        pc <= pc + 4;
                    end
                end
                else begin
                    issue_enable <= `False;
                end
            end
        end
    end

endmodule
