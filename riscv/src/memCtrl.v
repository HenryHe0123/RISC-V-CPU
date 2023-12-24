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
    reg [1:0] pos; // position in a word
    wire      lsb_io = (lsb_ain[17:16] == 2'b11);
    wire      io_fail = lsb_io && io_buffer_full;

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
            case(status)
                IDLE: begin
                    ic_enable <= `False;
                    lsb_enable <= `False;
                    pos <= 0;
                    if (ic_valid) begin
                        mem_a <= ic_ain;
                        mem_wr <= 0;
                        status <= IFETCH;
                    end
                    else if (lsb_valid) begin
                        mem_wr <= lsb_wr;
                        mem_a <= lsb_ain;
                        if(lsb_wr) begin // write
                            status <= STORE;
                        end
                        else begin // read
                            status <= LOAD;
                        end
                    end
                end
                IFETCH: begin
                    if(ic_valid) begin
                        case (pos)
                            2'd0:
                                ic_dout[7:0] <= mem_din;
                            2'd1:
                                ic_dout[15:8] <= mem_din;
                            2'd2:
                                ic_dout[23:16] <= mem_din;
                            2'd3:
                                ic_dout[31:24] <= mem_din;
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            ic_enable <= `True;
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
                    if (lsb_valid) begin
                        case (pos)
                            2'd0:
                                lsb_dout[7:0] <= mem_din;
                            2'd1:
                                lsb_dout[15:8] <= mem_din;
                            2'd2:
                                lsb_dout[23:16] <= mem_din;
                            2'd3:
                                lsb_dout[31:24] <= mem_din;
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            lsb_enable <= `True;
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
                    if (lsb_valid && ~io_fail) begin
                        case (pos)
                            2'd0:
                                mem_dout <= lsb_din[7:0];
                            2'd1:
                                mem_dout <= lsb_din[15:8];
                            2'd2:
                                mem_dout <= lsb_din[23:16];
                            2'd3:
                                mem_dout <= lsb_din[31:24];
                        endcase
                        if (pos == 2'd3) begin
                            status <= IDLE;
                            lsb_enable <= `True;
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
