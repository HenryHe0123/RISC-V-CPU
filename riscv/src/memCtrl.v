//Memory Controller

`include "defines.v"

module memCtrl(
        input wire clk, rst, rdy,

        //ram
        input wire [ 7:0] mem_din,
        output reg [ 7:0] mem_dout,
        output reg [31:0] mem_a,   // address bus (only 17:0 is used)
        output reg mem_wr,         // 0: read, 1: write

        input wire io_buffer_full, // 1 if uart buffer is full

        //icache
        input wire        ic_valid,
        input wire [31:0] ic_ain,  // address from icache
        output reg        ic_enable,
        output reg [31:0] ic_dout,  // data(inst) to icache

        //lsb
        input wire        lsb_valid,
        input wire        lsb_wr,   // 0: read, 1: write
        input wire [31:0] lsb_ain,  // address from lsb
        input wire [31:0] lsb_din,  // data(to be stored) from lsb
        output reg        lsb_enable,
        output reg [31:0] lsb_dout  // data to lsb
    );

    parameter IDLE = 0, IFETCH = 1, LOAD = 2, STORE = 3;

    reg [1:0] status;
    reg [2:0] pos; // position in a word, 0 for null

    always @(posedge clk) begin
        if (rst) begin
            mem_a <= 0;
            mem_wr <= 0; // read
            status <= IDLE;
            pos <= 0;
            ic_enable <= `False;
            lsb_enable <= `False;
        end
        else if (~rdy) begin // pause
            mem_a <= 0;
            mem_wr <= 0;
            ic_enable <= `False;
            lsb_enable <= `False;
        end
        else begin
            //todo: unfinished
            case(status)
                IDLE: begin
                    if (ic_valid) begin
                        mem_a <= ic_ain;
                        mem_wr <= 0;
                        ic_enable <= `True;
                        status <= IFETCH;
                    end
                    else if (lsb_valid) begin
                        mem_a <= lsb_ain;
                        mem_wr <= lsb_wr;
                        lsb_enable <= `True;
                        status <= (lsb_wr)? STORE: LOAD;
                    end
                end
                IFETCH: begin
                    if (ic_enable) begin
                        ic_enable <= `False;
                        ic_dout <= mem_dout;
                        status <= IDLE;
                    end
                end
                LOAD: begin
                    if (lsb_enable) begin
                        lsb_enable <= `False;
                        lsb_dout <= mem_dout;
                        status <= IDLE;
                    end
                end
                STORE: begin
                    if (lsb_enable) begin
                        lsb_enable <= `False;
                        status <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
