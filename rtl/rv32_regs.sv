module rv32_regs
    (
        input  wire           clk,
        input  wire           reset_n,
        // src A
        input  wire [5-1:0]   a_addr,
        output wire [32-1:0]  a_data_out,
        // src B
        input  wire [5-1:0]   b_addr,
        output wire [32-1:0]  b_data_out,
        // dst
        input  wire           dst_wr_en,
        input  wire [5-1:0]   dst_addr,
        input  wire [32-1:0]  dst_wr_data
    );

    reg [32-1:0] mem[32];
    
    assign a_data_out = mem[a_addr];
    assign b_data_out = mem[b_addr];

    always_ff @(posedge(clk)) begin
        if (!reset_n) begin
            mem <= '{default: '0};
        end else if (dst_wr_en && dst_addr != 0) begin
            mem[dst_addr] <= dst_wr_data;
        end
    end

endmodule
