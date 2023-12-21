`default_nettype none

module top
    # (
        parameter ADDR_WIDTH = 8,
        parameter START_ADDR = 32'h10000
    )
    (
        input  wire                    clk,
        input  wire                    reset_n,
        // ram port
        input  wire                    a_wr_en,
        input  wire [4-1:0]            a_wr_strobe,
        input  wire [ADDR_WIDTH-1:0]   a_addr,
        input  wire [32-1:0]           a_data_in,
        output wire [32-1:0]           a_data_out,
        output wire [3:0]              core_fault
    );

    wire                    b_wr_en;
    wire [4-1:0]            b_wr_strobe;
    wire [ADDR_WIDTH-1:0]   b_addr;
    wire [32-1:0]           b_data_in;
    wire [32-1:0]           b_data_out;

    // Adding byte-strobes for RAM inputs:
    // -----------------------------------
    wire [32-1:0]  a_wr_mask;
    wire [32-1:0]  b_wr_mask;
    wire [32-1:0]  a_data_in_masked;
    wire [32-1:0]  b_data_in_masked;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            assign a_wr_mask[i*8+7:i*8] = a_wr_strobe[i] ? 8'hff : 8'h00;
            assign b_wr_mask[i*8+7:i*8] = b_wr_strobe[i] ? 8'hff : 8'h00;
        end
    endgenerate
    assign a_data_in_masked = (a_data_in & a_wr_mask) | (a_data_in_masked & ~a_wr_mask);
    assign b_data_in_masked = (b_data_in & b_wr_mask) | (b_data_in_masked & ~b_wr_mask);
    // -----------------------------------

    ram
    #(
        .ADDR_WIDTH  ( ADDR_WIDTH         )
    )
    ram_inst
    (
        .clk         ( clk                ),
        .a_wr_en     ( a_wr_en            ),
        .a_addr      ( a_addr             ),
        .a_data_in   ( a_data_in_masked   ),
        .a_data_out  ( a_data_out         ),
        .b_wr_en     ( b_wr_en            ),
        .b_addr      ( b_addr             ),
        .b_data_in   ( b_data_in_masked   ),
        .b_data_out  ( b_data_out         )
    );

    rv32_core
    #(
        .ADDR_WIDTH ( ADDR_WIDTH ),
        .START_ADDR ( START_ADDR )
    )
    rv32_inst
    (
        .clk           ( clk         ),
        .reset_n       ( reset_n     ),
        .ram_wr_en     ( b_wr_en     ),
        .ram_wr_strobe ( b_wr_strobe ),
        .ram_addr      ( b_addr      ),
        .ram_data_in   ( b_data_in   ),
        .ram_data_out  ( b_data_out  ),
        .core_fault    ( core_fault  )
    );

endmodule
