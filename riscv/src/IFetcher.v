//Instruction Fetcher

`include "defines.v"
`include "predictor.v"

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
        output reg         predict_to_issue,

        //rob
        input wire        ROB_full,
        input wire        ROB_jump_flag, //1: jalr/jal/branch(wrong)
        input wire [31:0] ROB_target_pc, //target pc when jump flag is true

        //predict
        input wire ROB_predict_flag,   //1: branch
        input wire ROB_branch_result,  //0: not taken, 1: taken (the true result)
        input wire [31:0] ROB_branch_pc,  //the pc of the branch instruction
    
        //other
        input wire LSB_full,
        input wire RS_full
    );

    reg [31:0] pc, next_pc;

    predictor predict(
        .clk(clk),
        .rst(rst),
        .rdy(rdy),
        .pc(pc),
        .update_flag(ROB_predict_flag),
        .update_pc(ROB_branch_pc),
        .update_result(ROB_branch_result),
    );

    assign inst_to_issue = icache_inst;
    //todo

endmodule
