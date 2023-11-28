module ram
    # (
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32
    )
    (
        input  wire                    clk,
        //input  wire                    rd_en,
        input  wire                    wr_en,
        input  wire [DATA_WIDTH/8-1:0] wr_strobe,
        input  wire [ADDR_WIDTH-1:0]   addr,
        input  wire [DATA_WIDTH-1:0]   data_in,
        output wire [DATA_WIDTH-1:0]   data_out
    );

    wire [DATA_WIDTH-1:0] wr_mask;

    genvar i;

    generate
        for (i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
            assign wr_mask[i*8+7:i*8] = wr_strobe[i] ? 8'hff : 8'h00;
        end
    endgenerate

    reg [DATA_WIDTH-1:0] mem[1<<ADDR_WIDTH];

    assign data_out = mem[addr];

    always_ff @(posedge(clk)) begin
        if (wr_en) begin
            mem[addr] <= (data_in & wr_mask) | (mem[addr] & ~wr_mask);
        end
    end
endmodule
