`default_nettype none

module ram
    #(
        parameter WIDTH       = 32, 
        parameter ADDR_WIDTH  = 8
    )
    (
        input  wire                      clk       ,  // Port-A: Clock

        input  wire                      a_wr_en   ,  // Port-A: Write Enable
        input  wire  [ADDR_WIDTH-1:0]    a_addr    ,  // Port-A: Address
        input  wire  [WIDTH-1:0]         a_data_in ,  // Port-A: Input data
        output logic [WIDTH-1:0]         a_data_out,  // Port-A: Output data

        input  wire                      b_wr_en   ,  // Port-B: Write Enable
        input  wire  [ADDR_WIDTH-1:0]    b_addr    ,  // Port-B: Address
        input  wire  [WIDTH-1:0]         b_data_in ,  // Port-B: Input data
        output logic [WIDTH-1:0]         b_data_out   // Port-B: Output data
    );

    localparam DEPTH = 2 ** ADDR_WIDTH;

    /* ram_style:
        block      : Instructs the tool to infer RAMB-type components.
        distributed: Instructs the tool to infer the LUT RAMs.
        registers  : Instructs the tool to infer registers instead of RAMs.
        ultra      : Instructs the tool to use the AMD UltraScale+™ URAM primitives.
        mixed      : Instructs the tool to infer a combination of RAM types designed to minimize the amount of space that is unused.
    */
    (* ram_style = "block" *)
    reg [WIDTH-1:0] mem [DEPTH-1:0];

    // Memory initialization 
    generate
        integer ram_index;
        initial
        for (ram_index = 0; ram_index < DEPTH; ram_index = ram_index + 1)
            mem[ram_index] = {(WIDTH){1'b0}};
    endgenerate

    logic  [WIDTH-1:0]         a_rdata_r;
    logic  [WIDTH-1:0]         b_rdata_r;

    // Port-A:
    always @(posedge(clk)) begin
        if (a_wr_en) begin
            mem[a_addr] <= a_data_in;
            a_rdata_r   <= a_data_in;
        end else begin
            a_rdata_r   <= mem[a_addr];
        end
    end
    // assign a_data_out = a_rdata_r;

    // Port-B:
    always @(posedge(clk)) begin
        if (b_wr_en) begin
            mem[b_addr] <= b_data_in;
            b_rdata_r   <= b_data_in;
        end else begin
            b_rdata_r   <= mem[b_addr];
        end
    end
    // assign b_data_out = b_rdata_r;

    always @(posedge(clk)) begin
        a_data_out <= a_rdata_r;
        b_data_out <= b_rdata_r;
    end

endmodule  // ram

`default_nettype wire