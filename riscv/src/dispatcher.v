//Dispatcher
//combinational logic

`include "defines.v"

module dispatcher(
        input wire clk, rst, rdy,

        //ifetcher
        input wire              ifetch_valid,
        input wire [5:0]        ifetch_optype,

        //regfile
        output reg              reg_rename_enable,
        output wire [`ROBRange] issue_rdTag,

        //rob
        input  wire             ROB_full,
        input  wire [`ROBRange] ROB_nextTag,
        output reg              ROB_enable,

        //rs
        input  wire             RS_full,
        output reg              RS_enable,

        //lsb
        input  wire             LSB_full,
        output reg              LSB_enable // load/store instruction
    );

    assign issue_rdTag = (ifetch_valid && ~ROB_full) ? ROB_nextTag : 0;

    always @(*) begin
        ROB_enable = `False;
        reg_rename_enable = `False;
        RS_enable  = `False;
        LSB_enable = `False;

        if (~rst && rdy && ifetch_valid) begin
            ROB_enable = `True;
            reg_rename_enable = ~ROB_full;
            if (ifetch_optype >= `LB && ifetch_optype <= `SW)
                LSB_enable = ~LSB_full;
            else
                RS_enable = ~RS_full;
        end
    end

endmodule
