//Instruction Cache
//icache entries: 2^8 = 256
//direct-mapped: valid-tag-data
//pc[9:2]->index, pc[17:10]->tag

`include "defines.v"

module ICache(
        input wire clk, rst, rdy,

        //mctrl
        input  wire        mem_valid,
        input  wire [31:0] mem_din,  // data(inst) from mctrl
        output  reg [31:0] mem_aout, // address to mctrl
        output  reg        mem_enable, // let mctrl ifetch

        //ifetcher
        input  wire [31:0] ifetch_pc,   // pc from ifetcher (wire), always valid
        output wire [31:0] ifetch_dout, // data(inst) to ifetcher
        output wire        ifetch_enable
    );

    reg  [`ICEntries - 1:0] valid;
    reg  [`ICTGRange]       tag   [`ICEntries - 1:0];
    reg  [31:0]             data  [`ICEntries - 1:0]; // inst

    wire [31:0]       pc = ifetch_pc;
    wire [`ICIDRange] index = pc[`ICIDRange];
    wire [`ICIDRange] pre_index = mem_aout[`ICIDRange]; // debug: pc will be changed in ifetcher when accessing mem
    wire              hit = valid[index] && tag[index] == pc[17:11];

    assign ifetch_enable = hit || (mem_valid && mem_aout == pc);
    assign ifetch_dout = hit ? data[index] : mem_din;

    reg busy; // icache is busy loading missing data

    always @(posedge clk) begin
        if (rst) begin
            busy <= `False;
            valid <= 0;
            mem_enable <= `False;
        end
        else if (rdy) begin
            if (busy) begin
                //wait for mem_valid
                if (mem_valid) begin
                    valid[pre_index] <= `True;
                    tag[pre_index] <= mem_aout[17:11];
                    data[pre_index] <= mem_din;
                    mem_enable <= `False;
                    busy <= `False;
                end
            end
            else begin
                //if cache miss, start loading data from mem
                if (~hit) begin
                    mem_aout <= pc;
                    mem_enable <= `True;
                    busy <= `True;
                end
            end
        end
    end

endmodule
