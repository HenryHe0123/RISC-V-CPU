//Instruction Cache
//icache entries: 2^9 = 512
//direct-mapped: valid-tag-data
//pc[10:2]->index, pc[17:11]->tag

`include "defines.v"

module ICache(
        input wire clk, rst, rdy,

        //mctrl
        input wire        mem_valid,
        input wire [31:0] mem_din,  // data(inst) from mctrl
        output reg [31:0] mem_aout, // address to mctrl
        output reg        mem_enable,

        //ifetcher
        input wire        ifetch_valid,
        input wire [31:0] ifetch_pc,   // pc from ifetcher
        output reg [31:0] ifetch_dout, // data(inst) to ifetcher
        output reg        ifetch_enable
    );

    reg  [`ICEntries-1:0] valid;
    reg  [17:11] tag   [`ICEntries-1:0];
    reg  [31:0]  data  [`ICEntries-1:0]; // inst

    wire [31:0] pc = ifetch_pc;
    wire [10:2] index = pc[10:2];
    wire        hit = valid[index] && tag[index] == pc[17:11];

    assign mem_aout = pc;
    assign mem_enable = ifetch_valid && !hit && !mem_valid;

    always @(posedge clk) begin
        if (rst) begin
            valid <= 0;
            ifetch_enable <= `False;
        end

        else if (rdy && ifetch_valid) begin
            if (hit) begin
                ifetch_dout <= data[index];
                ifetch_enable <= `True;
            end
            else begin // miss
                ifetch_enable <= mem_valid;
                ifetch_dout <= mem_din;
            end

            if (mem_valid) begin // update icache
                valid[index] <= `True;
                tag[index] <= pc[17:11];
                data[index] <= mem_din;
            end
        end

        else begin
            ifetch_enable <= `False;
        end
    end

endmodule
