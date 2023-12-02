module ram
    # (
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32
    )
    (
        input  wire                    clk,
        // port A
        input  wire                    a_wr_en,
        input  wire [DATA_WIDTH/8-1:0] a_wr_strobe,
        input  wire [ADDR_WIDTH-1:0]   a_addr,
        input  wire [DATA_WIDTH-1:0]   a_data_in,
        output wire [DATA_WIDTH-1:0]   a_data_out,
        // port B
        input  wire                    b_wr_en,
        input  wire [DATA_WIDTH/8-1:0] b_wr_strobe,
        input  wire [ADDR_WIDTH-1:0]   b_addr,
        input  wire [DATA_WIDTH-1:0]   b_data_in,
        output wire [DATA_WIDTH-1:0]   b_data_out
    );

    wire [DATA_WIDTH-1:0] a_wr_mask;
    wire [DATA_WIDTH-1:0] b_wr_mask;

    genvar i;
    generate
        for (i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
            assign a_wr_mask[i*8+7:i*8] = a_wr_strobe[i] ? 8'hff : 8'h00;
            assign b_wr_mask[i*8+7:i*8] = b_wr_strobe[i] ? 8'hff : 8'h00;
        end
    endgenerate

    reg [DATA_WIDTH-1:0] mem[1<<ADDR_WIDTH];

    assign a_data_out = mem[a_addr];
    assign b_data_out = mem[b_addr];

    always_ff @(posedge(clk)) begin
        if (b_wr_en) begin
            mem[b_addr] <= (b_data_in & b_wr_mask) | (mem[b_addr] & ~b_wr_mask);
        end
        // Port A take priority in case same address is used for both ports
        if (a_wr_en) begin
            mem[a_addr] <= (a_data_in & a_wr_mask) | (mem[a_addr] & ~a_wr_mask);
        end
    end

endmodule
