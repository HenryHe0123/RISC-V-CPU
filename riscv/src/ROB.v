//Reorder Buffer

`include "defines.v"

module ROB(
        input wire clk, rst, rdy,

        //issue
        input  wire             issue_valid,
        input  wire [5:0]       issue_op,
        input  wire [4:0]       issue_rd,
        input  wire [31:0]      issue_pc,
        input  wire [31:0]      issue_imm,
        input  wire             issue_predict,
        output wire [`ROBRange] ROB_nextTag,

        //ifetch
        output reg [31:0]       ROB_reset_pc, // reset pc for rollback
        output reg              ROB_predict_updFlag,
        output reg              ROB_branch_updResult, // 0: not taken, 1: taken (the true result)
        output reg [31:0]       ROB_branch_updPC, // the pc of the branch instruction

        //reg (commit)
        output reg              commit_valid,
        output reg  [4:0]       commit_rd,
        output reg  [`ROBRange] commit_rdTag,
        output reg  [31:0]      commit_rdVal,

        //lsb
        output reg              commit_store,
        output wire [`ROBRange] ROB_topTag,

        //cdb-alu
        input wire             B_ALU_valid,
        input wire [31:0]      B_ALU_result,
        input wire [`ROBRange] B_ALU_rdTag,

        //cdb-lsb
        input wire             B_LSB_valid,
        input wire [31:0]      B_LSB_result,
        input wire [`ROBRange] B_LSB_rdTag,

        output reg             rollback,
        output wire            ROB_full
    );

    reg [`ROBSize - 1:0] ready;
    reg [5:0]            op      [`ROBSize - 1:0];
    reg [4:0]            rd      [`ROBSize - 1:0];
    reg [31:0]           value   [`ROBSize - 1:0]; // 0/1 for br instruction (true result)
    reg [31:0]           resetPC [`ROBSize - 1:0];
    reg [31:0]           pc      [`ROBSize - 1:0];
    reg                  predict [`ROBSize - 1:0]; // 0: not taken, 1: taken

    reg  [`ROBRange]  head, tail; // top = head + 1, last = tail

    wire [`ROBRange]  top = (head + 1) & (`ROBSize - 1);
    wire [`ROBRange]  next = (tail + 1) & (`ROBSize - 1);
    wire              isEmpty = (head == tail);
    wire              top_is_store = (op[top] >= `SB && op[top] <= `SW);
    wire              top_is_branch = (op[top] >= `BEQ && op[top] <= `BGEU);
    wire              top_predict_wrong = (predict[top] != value[top][0]);

    assign ROB_topTag = top;
    assign ROB_nextTag = next;
    assign ROB_full = tail >= head
           ? tail - head + 2 >= `ROBSize
           : tail + 2 >= head;

    integer i;

    always @(posedge clk) begin
        if (rst || rollback) begin
            head <= 0;
            tail <= 0;
            ready <= 0;
            for (i = 0; i < `ROBSize; i = i + 1) begin
                //ready[i] <= 0;
                rd[i] <= 0;
                value[i] <= 0;
            end
            rollback <= `False;
            commit_valid <= `False;
            commit_store <= `False;
            ROB_predict_updFlag <= `False;
        end
        else if (rdy) begin
            if (issue_valid) begin
                ready[next] <= (issue_op >= `BEQ && issue_op <= `BGEU) ? 0 : (issue_rd == 0);
                // debug: ready for S, unready for Branch!
                op[next] <= issue_op;
                rd[next] <= issue_rd;
                resetPC[next] <= issue_pc + (issue_predict? 4: issue_imm); //different with prediction
                pc[next] <= issue_pc;
                predict[next] <= issue_predict;
                tail <= next;
            end

            if (B_ALU_valid) begin
                ready[B_ALU_rdTag] <= `True;
                value[B_ALU_rdTag] <= B_ALU_result;
            end
            if (B_LSB_valid) begin
                ready[B_LSB_rdTag] <= `True;
                value[B_LSB_rdTag] <= B_LSB_result;
            end

            rollback <= `False;
            commit_valid <= `False;
            commit_store <= `False;
            ROB_predict_updFlag <= `False;

            //commit
            if (~isEmpty && ready[top]) begin
                commit_valid <= `True;
                commit_rd <= rd[top];
                commit_rdTag <= top;
                commit_rdVal <= value[top];

                if (top_is_store) begin
                    commit_store <= `True;
                end
                else if (top_is_branch) begin
                    ROB_predict_updFlag <= `True;
                    ROB_branch_updResult <= value[top][0];
                    ROB_branch_updPC <= pc[top];

                    if (top_predict_wrong) begin
                        rollback <= `True;
                        ROB_reset_pc <= resetPC[top];
                    end
                end
                //retire
                head <= top;
                ready[top] <= `False;
            end
        end
    end

endmodule
