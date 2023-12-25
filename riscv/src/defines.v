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

`define LUIOP       7'b0110111
`define AUIPCOP     7'b0010111
`define JALOP       7'b1101111
`define JALROP      7'b1100111
`define BROP        7'b1100011
`define LOP         7'b0000011
`define SOP         7'b0100011
`define IOP         7'b0010011
`define ROP         7'b0110011

`endif
