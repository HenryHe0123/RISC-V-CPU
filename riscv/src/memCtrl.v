//Memory Controller

`include "defines.v"

module memCtrl(
        input wire clk, rst, rdy,

        //ram
        input wire [ 7:0] mem_din,
        output reg [ 7:0] mem_dout,
        output reg [31:0] mem_a,   // address bus (only 17:0 is used)
        output reg mem_wr,         // 0: read, 1: write

        input wire io_buffer_full, // 1 if uart buffer is full, io invalid now

        //icache
        input wire        icache_valid,
        input wire [31:0] icache_ain,  // address from icache
        output reg        icache_enable,
        output reg [31:0] icache_dout,  // data(inst) to icache

        //lsb
        input wire        LSB_valid,
        input wire        LSB_wr,   // 0: read, 1: write
        input wire [31:0] LSB_ain,  // address from lsb
        input wire [31:0] LSB_din,  // data(to be stored) from lsb
        output reg        LSB_enable,
        output reg [31:0] LSB_dout  // data to lsb
    );

    parameter IDLE = 0, IFETCH = 1, LOAD = 2, STORE = 3;

    reg [1:0] status;
    reg [1:0] pos; // position in a word
    wire      LSB_io = (LSB_ain[17:16] == 2'b11);
    wire      io_fail = LSB_io && io_buffer_full;

    always @(posedge clk) begin
        if (rst) begin
            mem_a <= 0;
            mem_wr <= 0; // read
            status <= IDLE;
            pos <= 0;
            icache_enable <= `False;
            LSB_enable <= `False;
        end
        else if (~rdy) begin // pause
            mem_a <= 0;
            mem_wr <= 0;
            icache_enable <= `False;
            LSB_enable <= `False;
        end
        else begin
            case(status)
                IDLE: begin
                    icache_enable <= `False;
                    LSB_enable <= `False;
                    pos <= 0;
                    if (icache_valid) begin
                        mem_a <= icache_ain;
                        mem_wr <= 0;
                        status <= IFETCH;
                    end
                    else if (LSB_valid) begin
                        mem_wr <= LSB_wr;
                        mem_a <= LSB_ain;
                        if(LSB_wr) begin // write
                            status <= STORE;
                        end
                        else begin // read
                            status <= LOAD;
                        end
                    end
                end
                IFETCH: begin
                    if(icache_valid) begin
                        case (pos)
                            2'd0:
                                icache_dout[7:0] <= mem_din;
                            2'd1:
                                icache_dout[15:8] <= mem_din;
                            2'd2:
                                icache_dout[23:16] <= mem_din;
                            2'd3:
                                icache_dout[31:24] <= mem_din;
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            icache_enable <= `True;
                        end
                        else begin
                            pos <= pos + 1;
                            mem_a <= mem_a + 1;
                        end
                    end
                    else begin
                        status <= IDLE;
                    end
                end
                LOAD: begin
                    if (LSB_valid) begin
                        case (pos)
                            2'd0:
                                LSB_dout[7:0] <= mem_din;
                            2'd1:
                                LSB_dout[15:8] <= mem_din;
                            2'd2:
                                LSB_dout[23:16] <= mem_din;
                            2'd3:
                                LSB_dout[31:24] <= mem_din;
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            LSB_enable <= `True;
                        end
                        else begin
                            pos <= pos + 1;
                            mem_a <= mem_a + 1;
                        end
                    end
                    else begin
                        status <= IDLE;
                    end
                end
                STORE: begin
                    if (LSB_valid && ~io_fail) begin
                        case (pos)
                            2'd0:
                                mem_dout <= LSB_din[7:0];
                            2'd1:
                                mem_dout <= LSB_din[15:8];
                            2'd2:
                                mem_dout <= LSB_din[23:16];
                            2'd3:
                                mem_dout <= LSB_din[31:24];
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            LSB_enable <= `True;
                        end
                        else begin
                            pos <= pos + 1;
                            mem_a <= mem_a + 1;
                        end
                    end
                    else begin
                        status <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
