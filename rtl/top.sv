module top
    # (
        parameter ADDR_WIDTH = 16,
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

    ram
    #(
        .ADDR_WIDTH ( 16 )
    )
    ram_inst
    (
        .clk         ( clk         ),
        .a_wr_en     ( a_wr_en     ),
        .a_wr_strobe ( a_wr_strobe ),
        .a_addr      ( a_addr      ),
        .a_data_in   ( a_data_in   ),
        .a_data_out  ( a_data_out  ),
        .b_wr_en     ( b_wr_en     ),
        .b_wr_strobe ( b_wr_strobe ),
        .b_addr      ( b_addr      ),
        .b_data_in   ( b_data_in   ),
        .b_data_out  ( b_data_out  )
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
