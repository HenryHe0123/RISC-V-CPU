// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "memCtrl.v"
`include "ICache.v"
`include "IFetcher.v"
`include "dispatcher.v"
`include "regFile.v"
`include "RS.v"
`include "ALU.v"
`include "ROB.v"
`include "LSB.v"

module cpu(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					rdy_in,			// ready signal, pause cpu when low

        input  wire [ 7:0]          mem_din,		// data input bus
        output wire [ 7:0]          mem_dout,		// data output bus
        output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
        output wire                 mem_wr,			// write/read signal (1 for write)

        input  wire                 io_buffer_full, // 1 if uart buffer is full

        output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
    );

    // implementation goes here

    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    wire                  valid_ic_to_mem;
    wire [31:0]           addr_ic_to_mem;
    wire                  valid_mem_to_ic;
    wire [31:0]           data_mem_to_ic;

    wire                  valid_lsb_to_mem;
    wire                  wr_lsb_to_mem;
    wire [31:0]           addr_lsb_to_mem;
    wire [31:0]           data_lsb_to_mem;
    wire [2:0]            len_lsb_to_mem;
    wire                  valid_mem_to_lsb;
    wire [31:0]           data_mem_to_lsb;

    wire                  io_buffer_full_sim = 0;

    memCtrl u_memCtrl(
                .clk            	( clk_in          ),
                .rst            	( rst_in          ),
                .rdy            	( rdy_in          ),
                .mem_din        	( mem_din         ),
                .mem_dout       	( mem_dout        ),
                .mem_a          	( mem_a           ),
                .mem_wr         	( mem_wr          ),
                .io_buffer_full 	( io_buffer_full_sim  ),
                .icache_valid   	( valid_ic_to_mem ),
                .icache_ain     	( addr_ic_to_mem  ),
                .icache_enable  	( valid_mem_to_ic ),
                .icache_dout    	( data_mem_to_ic  ),
                .LSB_valid      	( valid_lsb_to_mem ),
                .LSB_wr         	( wr_lsb_to_mem   ),
                .LSB_ain        	( addr_lsb_to_mem ),
                .LSB_din        	( data_lsb_to_mem ),
                .LSB_len        	( len_lsb_to_mem  ),
                .LSB_enable     	( valid_mem_to_lsb ),
                .LSB_dout       	( data_mem_to_lsb )
            );

    wire [31:0]           pc_ifetch_to_ic;
    wire                  valid_ic_to_ifetch;
    wire [31:0]           inst_ic_to_ifetch;

    ICache u_ICache(
               .clk            	( clk_in          ),
               .rst            	( rst_in          ),
               .rdy            	( rdy_in          ),
               .mem_valid      	( valid_mem_to_ic ),
               .mem_din        	( data_mem_to_ic  ),
               .mem_aout       	( addr_ic_to_mem  ),
               .mem_enable     	( valid_ic_to_mem ),
               .ifetch_pc      	( pc_ifetch_to_ic ),
               .ifetch_dout    	( inst_ic_to_ifetch ),
               .ifetch_enable  	( valid_ic_to_ifetch )
           );

    wire                 issue_valid; //ifetcher issue valid
    wire [31:0]          issue_pc;
    wire                 issue_predict;
    wire [5:0]           issue_optype;
    wire [4:0]           issue_rs1;
    wire [4:0]           issue_rs2;
    wire [4:0]           issue_rd;
    wire [31:0]          issue_imm;

    wire                 jalr_valid;
    wire [31:0]          jalr_pc;

    wire                 rollback;
    wire                 ROB_full;
    wire                 LSB_full;
    wire                 RS_full;

    wire [31:0]          ROB_reset_pc;
    wire                 ROB_predict_updFlag;
    wire                 ROB_branch_updResult;
    wire [31:0]          ROB_branch_updPC;

    IFetcher u_IFetcher(
                 .clk            	( clk_in          ),
                 .rst            	( rst_in          ),
                 .rdy            	( rdy_in          ),
                 .icache_hit   	    ( valid_ic_to_ifetch ),
                 .icache_inst    	( inst_ic_to_ifetch ),
                 .pc_to_icache      ( pc_ifetch_to_ic ),
                 .issue_valid 	    ( issue_valid ),
                 .issue_pc       	( issue_pc    ),
                 .issue_predict  	( issue_predict ),
                 .issue_optype   	( issue_optype  ),
                 .issue_rs1      	( issue_rs1     ),
                 .issue_rs2      	( issue_rs2     ),
                 .issue_rd       	( issue_rd      ),
                 .issue_imm      	( issue_imm     ),
                 .jalr_valid     	( jalr_valid      ),
                 .jalr_pc        	( jalr_pc         ),
                 .ROB_full       	( ROB_full        ),
                 .rollback       	( rollback        ),
                 .ROB_reset_pc   	( ROB_reset_pc    ),
                 .ROB_predict_updFlag  ( ROB_predict_updFlag  ),
                 .ROB_branch_updResult ( ROB_branch_updResult ),
                 .ROB_branch_updPC     ( ROB_branch_updPC     ),
                 .LSB_full       	( LSB_full        ),
                 .RS_full        	( RS_full         )
             );

    wire                 reg_rename_valid;
    wire [`ROBRange]     issue_rdTag;
    wire [`ROBRange]     ROB_nextTag;
    wire                 ROB_issue_valid;
    wire                 RS_issue_valid;
    wire                 LSB_issue_valid;

    dispatcher u_dispatcher(
                   .clk            	( clk_in          ),
                   .rst            	( rst_in          ),
                   .rdy            	( rdy_in          ),
                   .ifetch_valid   	( issue_valid  ),
                   .ifetch_optype  	( issue_optype ),
                   .reg_rename_enable	( reg_rename_valid ),
                   .issue_rdTag    	( issue_rdTag ),
                   .ROB_full       	( ROB_full        ),
                   .ROB_nextTag    	( ROB_nextTag     ),
                   .ROB_enable     	( ROB_issue_valid ),
                   .RS_full        	( RS_full         ),
                   .RS_enable      	( RS_issue_valid ),
                   .LSB_full       	( LSB_full        ),
                   .LSB_enable     	( LSB_issue_valid )
               );

    wire [`ROBRange]      issue_Qj;
    wire [`ROBRange]      issue_Qk;
    wire [31:0]           issue_Vj;
    wire [31:0]           issue_Vk;
    wire                  issue_Rj;
    wire                  issue_Rk;

    wire                  ROB_commit_valid;
    wire [4:0]            ROB_commit_rd;
    wire [`ROBRange]      ROB_commit_rdTag;
    wire [31:0]           ROB_commit_rdVal;

    regFile u_regFile(
                .clk            	( clk_in          ),
                .rst            	( rst_in          ),
                .rdy            	( rdy_in          ),
                .issue_valid    	( issue_valid     ),
                .issue_rs1      	( issue_rs1       ),
                .issue_rs2      	( issue_rs2       ),
                .issue_rd       	( issue_rd        ),
                .issue_Qj       	( issue_Qj        ),
                .issue_Qk       	( issue_Qk        ),
                .issue_Vj       	( issue_Vj        ),
                .issue_Vk       	( issue_Vk        ),
                .issue_Rj       	( issue_Rj        ),
                .issue_Rk       	( issue_Rk        ),
                .rename_valid   	( reg_rename_valid ),
                .issue_rdTag    	( issue_rdTag     ),
                .commit_valid   	( ROB_commit_valid ),
                .ROB_rd      	    ( ROB_commit_rd    ),
                .ROB_rdTag   	    ( ROB_commit_rdTag ),
                .ROB_rdVal   	    ( ROB_commit_rdVal ),
                .rollback       	( rollback        )
            );

    wire                  RS_enable_ALU;
    wire [5:0]            RS_op_to_ALU;
    wire [31:0]           RS_Vj_to_ALU;
    wire [31:0]           RS_Vk_to_ALU;
    wire [31:0]           RS_imm_to_ALU;
    wire [`ROBRange]      RS_rdTag_to_ALU;
    wire [31:0]           RS_pc_to_ALU;

    //CDB
    wire                  B_ALU_valid;
    wire [31:0]           B_ALU_result;
    wire [`ROBRange]      B_ALU_rdTag;
    wire                  B_LSB_valid;
    wire [31:0]           B_LSB_result;
    wire [`ROBRange]      B_LSB_rdTag;

    RS u_RS(
           .clk            	( clk_in          ),
           .rst            	( rst_in          ),
           .rdy            	( rdy_in          ),
           .issue_valid    	( RS_issue_valid  ),
           .issue_op   	    ( issue_optype    ),
           .issue_Qj       	( issue_Qj        ),
           .issue_Qk       	( issue_Qk        ),
           .issue_Vj       	( issue_Vj        ),
           .issue_Vk       	( issue_Vk        ),
           .issue_Rj       	( issue_Rj        ),
           .issue_Rk       	( issue_Rk        ),
           .issue_imm      	( issue_imm       ),
           .issue_rdTag    	( issue_rdTag     ),
           .issue_pc       	( issue_pc        ),
           .ALU_enable     	( RS_enable_ALU   ),
           .op_to_ALU      	( RS_op_to_ALU    ),
           .Vj_to_ALU      	( RS_Vj_to_ALU    ),
           .Vk_to_ALU      	( RS_Vk_to_ALU    ),
           .imm_to_ALU     	( RS_imm_to_ALU   ),
           .rdTag_to_ALU   	( RS_rdTag_to_ALU ),
           .pc_to_ALU      	( RS_pc_to_ALU    ),
           .B_ALU_valid    	( B_ALU_valid     ),
           .B_ALU_result   	( B_ALU_result    ),
           .B_ALU_rdTag    	( B_ALU_rdTag     ),
           .B_LSB_valid    	( B_LSB_valid     ),
           .B_LSB_result   	( B_LSB_result    ),
           .B_LSB_rdTag    	( B_LSB_rdTag     ),
           .commit_valid   	( ROB_commit_valid ),
           .commit_rdVal   	( ROB_commit_rdVal ),
           .commit_rdTag   	( ROB_commit_rdTag ),
           .rollback       	( rollback        ),
           .RS_full        	( RS_full         )
       );

    ALU u_ALU(
            .clk            	( clk_in          ),
            .rst            	( rst_in          ),
            .rdy            	( rdy_in          ),
            .RS_valid       	( RS_enable_ALU   ),
            .RS_op          	( RS_op_to_ALU    ),
            .RS_Vj          	( RS_Vj_to_ALU    ),
            .RS_Vk          	( RS_Vk_to_ALU    ),
            .RS_imm         	( RS_imm_to_ALU   ),
            .RS_rdTag       	( RS_rdTag_to_ALU ),
            .RS_pc          	( RS_pc_to_ALU    ),
            .bus_enable     	( B_ALU_valid     ),
            .bus_result     	( B_ALU_result    ),
            .bus_rdTag      	( B_ALU_rdTag     ),
            .jalr_valid     	( jalr_valid      ),
            .jalr_pc        	( jalr_pc         )
        );

    wire                ROB_commit_store;
    wire [`ROBRange]    ROB_topTag;

    ROB u_ROB(
            .clk            	( clk_in          ),
            .rst            	( rst_in          ),
            .rdy            	( rdy_in          ),
            .issue_valid    	( ROB_issue_valid ),
            .issue_op       	( issue_optype    ),
            .issue_rd       	( issue_rd        ),
            .issue_pc       	( issue_pc        ),
            .issue_imm      	( issue_imm       ),
            .issue_predict  	( issue_predict   ),
            .ROB_nextTag    	( ROB_nextTag     ),
            .ROB_reset_pc   	( ROB_reset_pc    ),
            .ROB_predict_updFlag  ( ROB_predict_updFlag  ),
            .ROB_branch_updResult ( ROB_branch_updResult ),
            .ROB_branch_updPC     ( ROB_branch_updPC     ),
            .commit_valid   	( ROB_commit_valid ),
            .commit_rd      	( ROB_commit_rd    ),
            .commit_rdTag   	( ROB_commit_rdTag ),
            .commit_rdVal   	( ROB_commit_rdVal ),
            .commit_store   	( ROB_commit_store ),
            .ROB_topTag     	( ROB_topTag      ),
            .B_ALU_valid    	( B_ALU_valid     ),
            .B_ALU_result   	( B_ALU_result    ),
            .B_ALU_rdTag    	( B_ALU_rdTag     ),
            .B_LSB_valid    	( B_LSB_valid     ),
            .B_LSB_result   	( B_LSB_result    ),
            .B_LSB_rdTag    	( B_LSB_rdTag     ),
            .rollback       	( rollback        ),
            .ROB_full       	( ROB_full        )
        );

    LSB u_LSB(
            .clk            	( clk_in          ),
            .rst            	( rst_in          ),
            .rdy            	( rdy_in          ),
            .issue_valid    	( LSB_issue_valid ),
            .issue_op       	( issue_optype    ),
            .issue_Qj       	( issue_Qj        ),
            .issue_Qk       	( issue_Qk        ),
            .issue_Vj       	( issue_Vj        ),
            .issue_Vk       	( issue_Vk        ),
            .issue_Rj       	( issue_Rj        ),
            .issue_Rk       	( issue_Rk        ),
            .issue_imm      	( issue_imm       ),
            .issue_rdTag    	( issue_rdTag     ),
            .ROB_commit_store   ( ROB_commit_store ),
            .ROB_commitTag      ( ROB_commit_rdTag ),
            .ROB_topTag     	( ROB_topTag      ),
            .ROB_commit_valid   ( ROB_commit_valid ),
            .ROB_commitVal      ( ROB_commit_rdVal ),
            .mem_valid      	( valid_mem_to_lsb ),
            .mem_dout      	    ( data_mem_to_lsb  ),
            .mem_enable     	( valid_lsb_to_mem ),
            .wr_to_mem          ( wr_lsb_to_mem   ),
            .addr_to_mem        ( addr_lsb_to_mem ),
            .data_to_mem        ( data_lsb_to_mem ),
            .len_to_mem         ( len_lsb_to_mem  ),
            .B_ALU_valid    	( B_ALU_valid     ),
            .B_ALU_result   	( B_ALU_result    ),
            .B_ALU_rdTag    	( B_ALU_rdTag     ),
            .B_LSB_valid    	( B_LSB_valid     ),
            .B_LSB_result   	( B_LSB_result    ),
            .B_LSB_rdTag    	( B_LSB_rdTag     ),
            .rollback       	( rollback        ),
            .LSB_full       	( LSB_full        )
        );

endmodule
