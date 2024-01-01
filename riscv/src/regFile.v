//Register File
//combinational logic for Q, V, R query (controlled by issue_valid)
//sequential logic for rename and commit/rollback

`include "defines.v"

module regFile(
        input wire clk, rst, rdy,

        //issue
        input wire              issue_valid,
        input wire  [4:0]       issue_rs1,   //reg index
        input wire  [4:0]       issue_rs2,
        input wire  [4:0]       issue_rd,    

        output wire [`ROBRange] issue_Qj,
        output wire [`ROBRange] issue_Qk,
        output wire [31:0]      issue_Vj,
        output wire [31:0]      issue_Vk,
        output wire             issue_Rj,
        output wire             issue_Rk,

        //rename
        input wire              rename_valid, //controlled by dispatcher
        input wire  [`ROBRange] issue_rdTag,  //ROB dependency of rd, from dispatcher

        //ROB
        input wire              commit_valid, //from ROB
        input wire  [4:0]       ROB_rd,
        input wire  [`ROBRange] ROB_rdTag,
        input wire  [31:0]      ROB_rdVal,

        input wire              rollback   //predict wrong
    );

    parameter REG_NUM = 32;

    reg [31:0]      regVal  [REG_NUM - 1:0];
    reg [`ROBRange] regTag  [REG_NUM - 1:0];
    reg             regBusy [REG_NUM - 1:0];

    assign issue_Qj = issue_valid ? regTag[issue_rs1] : 0;
    assign issue_Qk = issue_valid ? regTag[issue_rs2] : 0;

    assign issue_Vj = (issue_valid && ~regBusy[issue_rs1]) ? regVal[issue_rs1] : 0;
    assign issue_Vk = (issue_valid && ~regBusy[issue_rs2]) ? regVal[issue_rs2] : 0;

    assign issue_Rj = (issue_valid && ~regBusy[issue_rs1]) ? `True : `False; //true: ready (unbusy)
    assign issue_Rk = (issue_valid && ~regBusy[issue_rs2]) ? `True : `False;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < REG_NUM; i = i + 1) begin
                regVal[i] <= 0;
                regTag[i] <= 0;
                regBusy[i] <= `False;
            end
        end
        else if (rdy) begin
            if (rollback) begin
                for (i = 0; i < REG_NUM; i = i + 1) begin
                    regTag[i] <= 0;
                    regBusy[i] <= `False;
                end
            end
            else begin
                if (commit_valid && ROB_rd != 0) begin //commit
                    regVal[ROB_rd] <= ROB_rdVal;
                    if (regBusy[ROB_rd] && ROB_rdTag == regTag[ROB_rd]) begin
                        regTag[ROB_rd] <= 0;
                        regBusy[ROB_rd] <= `False;
                    end
                end
                
                if (rename_valid && IQ_rd != 0) begin //rename
                    regTag[IQ_rd] <= issue_rdTag;
                    regBusy[IQ_rd] <= `True;
                end
            end
        end
    end

endmodule
