//Load Store Buffer

`include "defines.v"

module LSB(
        input wire clk, rst, rdy,

        //issue
        input wire             issue_valid,
        input wire [5:0]       issue_op,
        input wire [`ROBRange] issue_Qj,
        input wire [`ROBRange] issue_Qk,
        input wire [31:0]      issue_Vj,
        input wire [31:0]      issue_Vk,
        input wire             issue_Rj,
        input wire             issue_Rk,
        input wire [31:0]      issue_imm,
        input wire [`ROBRange] issue_rdTag,

        //rob
        input wire             ROB_committed,
        //input wire [`ROBRange] rob_RobId,
        input wire [`ROBRange] ROB_topTag,

        //mctrl
        input wire        mem_valid,
        input wire [31:0] mem_dout,  // data from mem
        output reg        mem_enable,
        output reg        wr_to_mem,    // 0: read, 1: write
        output reg [31:0] addr_to_mem,  
        output reg [31:0] data_to_mem,  // data to be stored
        
        //cdb-alu
        input wire             B_ALU_valid,
        input wire [31:0]      B_ALU_result,
        input wire [`ROBRange] B_ALU_rdTag,

        //cdb-lsb
        output reg             B_LSB_valid,
        output reg [31:0]      B_LSB_result,
        output reg [`ROBRange] B_LSB_rdTag,

        input wire             rollback,
        output reg             LSB_full
    );



endmodule
