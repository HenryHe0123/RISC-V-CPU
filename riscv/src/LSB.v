//Load Store Buffer
//FIFO, apply entry when issue, execute in order (store wait until ROB commit)
//rollback: clear all entries after last commit store

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
        input wire             ROB_commit_store,
        input wire [`ROBRange] ROB_commitTag,
        input wire [`ROBRange] ROB_topTag,

        //mctrl
        input wire        mem_valid,
        input wire [31:0] mem_dout,     // data from mem
        output reg        mem_enable,
        output reg        wr_to_mem,    // 0: read, 1: write
        output reg [31:0] addr_to_mem,
        output reg [31:0] data_to_mem,  // data to be stored
        output reg [2:0]  len_to_mem,   // 1, 2, 4

        //cdb-alu
        input wire             B_ALU_valid,
        input wire [31:0]      B_ALU_result,
        input wire [`ROBRange] B_ALU_rdTag,

        //cdb-lsb (load result)
        output reg             B_LSB_valid,
        output reg [31:0]      B_LSB_result,
        output reg [`ROBRange] B_LSB_rdTag,

        input  wire            rollback,
        output wire            LSB_full
    );

    reg                  busy  [`LSBSize - 1:0]; // valid
    reg  [5:0]           op    [`LSBSize - 1:0];
    reg  [31:0]          Vj    [`LSBSize - 1:0];
    reg  [31:0]          Vk    [`LSBSize - 1:0];
    reg                  Rj    [`LSBSize - 1:0];
    reg                  Rk    [`LSBSize - 1:0];
    reg  [`ROBRange]     Qj    [`LSBSize - 1:0];
    reg  [`ROBRange]     Qk    [`LSBSize - 1:0];
    reg  [31:0]          imm   [`LSBSize - 1:0];
    reg  [`ROBRange]     rdTag [`LSBSize - 1:0];
    reg                  committed [`LSBSize - 1:0]; // for store

    reg  [`LSBRange]     head, tail; // top = head + 1, last = tail
    reg  [`LSBRange]     last_commit; // last commit store
    reg                  isWaitingMem;

    wire [`LSBRange]     top = (head + 1) & (`LSBSize - 1);
    wire [`LSBRange]     next = (tail + 1) & (`LSBSize - 1); // tail + 1
    wire [31:0]          top_addr = Vj[top] + imm[top];
    wire                 top_ready = Rj[top] && Rk[top] && busy[top];
    wire                 top_load = op[top] < `SB;
    wire                 top_Input = (top_addr[17:16] == 2'b11) && top_load; // read from input
    wire                 isEmpty = (head == tail);

    assign LSB_full = (next == head);

    integer i;

    always @(posedge clk) begin
        if (rst || (rollback && last_commit == head)) begin
            head <= 0;
            tail <= 0;
            last_commit <= 0;
            isWaitingMem <= `False;
            mem_enable <= `False;
            for (i = 0; i < `LSBSize; i = i + 1) begin
                busy[i] <= 0;
                Rj[i] <= 0;
                Rk[i] <= 0;
                committed[i] <= 0;
            end
        end
        else if (rdy) begin
            if (rollback) begin
                tail <= last_commit;
                for (i = 0; i < `LSBSize; i = i + 1) begin
                    //clear uncommitted entries
                    if (~committed[i]) begin
                        busy[i] <= 0;
                        Rj[i] <= 0;
                        Rk[i] <= 0;
                    end
                end

                if (isWaitingMem && mem_valid) begin // top entry finished
                    mem_enable <= `False;
                    isWaitingMem <= `False;
                    //retire top entry
                    busy[top] <= 0;
                    Rj[top] <= 0;
                    Rk[top] <= 0;
                    committed[top] <= 0;
                    head <= top;
                    if (last_commit == head)
                        last_commit <= top;
                end
            end
            else begin
                // update
                if (issue_valid) begin
                    // LSB shouldn't be full at this time
                    busy[next] <= `True;
                    op[next] <= issue_op;
                    Vj[next] <= issue_Vj;
                    Vk[next] <= issue_Vk;
                    Rj[next] <= issue_Rj;
                    Rk[next] <= issue_Rk;
                    Qj[next] <= issue_Qj;
                    Qk[next] <= issue_Qk;
                    imm[next] <= issue_imm;
                    rdTag[next] <= issue_rdTag;
                    tail <= next;
                end

                if (B_ALU_valid) begin
                    for (i = 0; i < `LSBSize; i = i + 1) begin
                        if (busy[i]) begin
                            if (~Rj[i] && Qj[i] == B_ALU_rdTag) begin
                                Vj[i] <= B_ALU_result;
                                Rj[i] <= `True;
                            end
                            if (~Rk[i] && Qk[i] == B_ALU_rdTag) begin
                                Vk[i] <= B_ALU_result;
                                Rk[i] <= `True;
                            end
                        end
                    end
                end

                if (B_LSB_valid) begin
                    for (i = 0; i < `LSBSize; i = i + 1) begin
                        if (busy[i]) begin
                            if (~Rj[i] && Qj[i] == B_LSB_rdTag) begin
                                Vj[i] <= B_LSB_result;
                                Rj[i] <= `True;
                            end
                            if (~Rk[i] && Qk[i] == B_LSB_rdTag) begin
                                Vk[i] <= B_LSB_result;
                                Rk[i] <= `True;
                            end
                        end
                    end
                end

                if (ROB_commit_store) begin
                    for (i = 0; i < `LSBSize; i = i + 1) begin
                        if (busy[i] && rdTag[i] == ROB_commitTag) begin
                            committed[i] <= `True;
                            last_commit <= i;
                        end
                    end
                end

                // execute
                if (isWaitingMem) begin
                    if (mem_valid) begin // top entry executed
                        if (top_load) begin //broadcast
                            B_LSB_valid <= `True;
                            B_LSB_rdTag <= rdTag[top];
                            case (op[top])
                                `LB:
                                    B_LSB_result <= {{24{mem_dout[7]}}, mem_dout[7:0]};
                                `LBU:
                                    B_LSB_result <= {{24{1'b0}}, mem_dout[7:0]};
                                `LH:
                                    B_LSB_result <= {{16{mem_dout[15]}}, mem_dout[15:0]};
                                `LHU:
                                    B_LSB_result <= {{16{1'b0}}, mem_dout[15:0]};
                                `LW:
                                    B_LSB_result <= mem_dout;
                            endcase
                        end
                        mem_enable <= `False;
                        isWaitingMem <= `False;
                        //retire top entry
                        busy[top] <= 0;
                        Rj[top] <= 0;
                        Rk[top] <= 0;
                        committed[top] <= 0;
                        head <= top;
                        if (last_commit == head)
                            last_commit <= top;
                    end
                end
                else begin
                    // try execute top entry
                    // Input wait until it becomes ROB top
                    if (~isEmpty && top_ready && (!top_Input || rdTag[top] == ROB_topTag)) begin
                        case (op[top])
                            `LB, `LBU: begin
                                mem_enable <= `True;
                                wr_to_mem <= 0; // 0: read
                                addr_to_mem <= top_addr;
                                len_to_mem <= 1;
                                isWaitingMem <= `True;
                            end
                            `LH, `LHU: begin
                                mem_enable <= `True;
                                wr_to_mem <= 0; // 0: read
                                addr_to_mem <= top_addr;
                                len_to_mem <= 2;
                                isWaitingMem <= `True;
                            end
                            `LW: begin
                                mem_enable <= `True;
                                wr_to_mem <= 0; // 0: read
                                addr_to_mem <= top_addr;
                                len_to_mem <= 4;
                                isWaitingMem <= `True;
                            end
                            `SB: begin
                                if (committed[top]) begin
                                    mem_enable <= `True;
                                    wr_to_mem <= 1; // 1: write
                                    addr_to_mem <= top_addr;
                                    data_to_mem <= Vk[top];
                                    len_to_mem <= 1;
                                    isWaitingMem <= `True;
                                end
                            end
                            `SH: begin
                                if (committed[top]) begin
                                    mem_enable <= `True;
                                    wr_to_mem <= 1; // 1: write
                                    addr_to_mem <= top_addr;
                                    data_to_mem <= Vk[top];
                                    len_to_mem <= 2;
                                    isWaitingMem <= `True;
                                end
                            end
                            `SW: begin
                                if (committed[top]) begin
                                    mem_enable <= `True;
                                    wr_to_mem <= 1; // 1: write
                                    addr_to_mem <= top_addr;
                                    data_to_mem <= Vk[top];
                                    len_to_mem <= 4;
                                    isWaitingMem <= `True;
                                end
                            end
                        endcase
                    end
                end
            end
        end
    end

endmodule
