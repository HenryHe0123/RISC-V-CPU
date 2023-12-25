//Predictor
//2-bit saturating counter

`include "defines.v"

module predictor(
        input wire clk, rst, rdy,

        input wire [31:0] pc,
        output wire predict, //0: not taken, 1: taken

        input wire        update_flag,
        input wire [31:0] update_pc,
        input wire        update_result //0: not taken, 1: taken
    );

    reg [1:0] counter[`PredSize - 1:0];

    // assign predict = 1'b1;
    assign predict = counter[pc[`PredRange]][1];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `PredSize; i = i + 1) begin
                counter[i] <= 2'b01; //weak not taken
            end
        end
        else if (rdy && update_flag) begin
            if (update_result && counter[update_pc[`PredRange]] < 2'b11)
                counter[update_pc[`PredRange]] <= counter[update_pc[`PredRange]] + 1;
            else if (~update_result && counter[update_pc[`PredRange]] > 2'b00)
                counter[update_pc[`PredRange]] <= counter[update_pc[`PredRange]] - 1;
        end
    end

endmodule
