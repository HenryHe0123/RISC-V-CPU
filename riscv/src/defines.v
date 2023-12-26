`ifndef defines
`define defines

`define True        1'b1
`define False       1'b0

`define ICEntries   512

`define RegWidth    5

`define ROBWidth    4
`define ROBSize     16

`define PredRange   9:3  //7
`define PredSize    128

//opcode

`define LUIOP       7'b0110111
`define AUIPCOP     7'b0010111
`define JALOP       7'b1101111
`define JALROP      7'b1100111
`define BOP         7'b1100011
`define LOP         7'b0000011   //I Load
`define SOP         7'b0100011
`define IOP         7'b0010011
`define ROP         7'b0110011

//optype

`define NOP         6'd0
`define LUI         6'd1                              //      U    Load Upper Immediate
`define AUIPC       6'd2                              //      U    Add Upper Immediate to PC
`define JAL         6'd3                              //      J    Jump & Link
`define JALR        6'd4                              //      I    Jump & Link Register

`define BEQ         6'd5                              //      B    Branch Equal
`define BNE         6'd6                              //      B    Branch Not Equal
`define BLT         6'd7                              //      B    Branch Less Than
`define BGE         6'd8                              //      B    Branch Greater than or Equal
`define BLTU        6'd9                              //      B    Branch Less than Unsigned
`define BGEU        6'd10                             //      B    Branch Greater than or Equal Unsigned

`define LB          6'd11                             //      I    Load Byte
`define LH          6'd12                             //      I    Load Halfword
`define LW          6'd13                             //      I    Load Word
`define LBU         6'd14                             //      I    Load Byte Unsigned
`define LHU         6'd15                             //      I    Load Halfword Unsigned
`define SB          6'd16                             //      S    Store Byte
`define SH          6'd17                             //      S    Store Halfword
`define SW          6'd18                             //      S    Store Word

`define ADDI        6'd19                             //      I    ADD Immediate
`define SLTI        6'd20                             //      I    Set Less than Immediate
`define SLTIU       6'd21                             //      I    Set Less than Immediate Unsigned
`define XORI        6'd22                             //      I    XOR Immediate
`define ORI         6'd23                             //      I    OR Immediate
`define ANDI        6'd24                             //      I    AND Immediate
`define SLLI        6'd25                             //      I    Shift Left Immediate
`define SRLI        6'd26                             //      I    Shift Right Immediate
`define SRAI        6'd27                             //      I    Shift Right Arith Immediate

`define ADD         6'd28                             //      R    ADD
`define SUB         6'd29                             //      R    SUBtract
`define SLL         6'd30                             //      R    Shift Left
`define SLT         6'd31                             //      R    Set Less than
`define SLTU        6'd32                             //      R    Set Less than Unsigned
`define XOR         6'd33                             //      R    XOR
`define SRL         6'd34                             //      R    Shift Right
`define SRA         6'd35                             //      R    Shift Right Arithmetic
`define OR          6'd36                             //      R    OR
`define AND         6'd37                             //      R    AND

`endif
