//Register File

`include "defines.v"

module regFile(
        input wire clk, rst, rdy,

        //IQueue
        input wire IQ_valid,
        input wire [`RegWidth - 1:0] IQ_rs1,
        input wire [`RegWidth - 1:0] IQ_rs2,
        input wire [`RegWidth - 1:0] IQ_rd,    //reg index, 4:0
        input wire [`ROBWidth - 1:0] IQ_rdTag, //ROB dependency of rd, also 4:0

        output wire [`ROBWidth - 1:0] Qj_to_IQ,
        output wire [`ROBWidth - 1:0] Qk_to_IQ,
        output wire [31:0] Vj_to_IQ,
        output wire [31:0] Vk_to_IQ,

        //ROB
        input wire ROB_valid,
        input wire [`RegWidth - 1:0] ROB_rd,
        input wire [`ROBWidth - 1:0] ROB_rdTag,
        input wire [31:0] ROB_rdVal,

        input wire rollback //predict wrong
    );

    parameter REG_NUM = 32;

    reg [31:0]            regVal  [REG_NUM - 1:0];
    reg [`ROBWidth - 1:0] regTag  [REG_NUM - 1:0];
    reg                   regBusy [REG_NUM - 1:0];

    assign Qj_to_IQ = IQ_valid ? regTag[IQ_rs1] : 0;
    assign Qk_to_IQ = IQ_valid ? regTag[IQ_rs2] : 0;

    assign Vj_to_IQ = (IQ_valid && ~regBusy[IQ_rs1]) ? regVal[IQ_rs1] : 0;
    assign Vk_to_IQ = (IQ_valid && ~regBusy[IQ_rs2]) ? regVal[IQ_rs2] : 0;

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
            if (rollback) begin //no rd for branch instruction
                for (i = 0; i < REG_NUM; i = i + 1) begin
                    regTag[i] <= 0;
                    regBusy[i] <= `False;
                end
            end
            else if (ROB_valid && ROB_rd != 0) begin //commit
                regVal[ROB_rd] <= ROB_rdVal;
                if (regBusy[ROB_rd] && ROB_rdTag == regTag[ROB_rd]) begin
                    regTag[ROB_rd] <= 0;
                    regBusy[ROB_rd] <= `False;
                end
            end
            else if (IQ_valid && IQ_rd != 0) begin //set dependency
                regTag[IQ_rd] <= IQ_rdTag;
                regBusy[IQ_rd] <= `True;
            end
        end
    end

endmodule
