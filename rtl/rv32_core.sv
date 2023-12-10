module rv32_core
    # (
        parameter ADDR_WIDTH = 16,
        parameter START_ADDR = 32'h10000
    )
    (
        input  wire                     clk,
        input  wire                     reset_n,
        // ram interface
        output reg                      ram_wr_en,
        output reg   [4-1:0]            ram_wr_strobe,
        output wire  [ADDR_WIDTH-1:0]   ram_addr,
        output reg   [32-1:0]           ram_data_in,
        input  wire  [32-1:0]           ram_data_out,
        output reg   [3:0]              core_fault
    );

    typedef enum logic [6:0] {
        op_lui           = 7'b0110111,
        op_load          = 7'b0000011,
        op_arith         = 7'b0110011,
        op_store         = 7'b0100011,
        op_jal           = 7'b1101111
    } opcode_val;

    opcode_val opcode;
    wire [4:0] rd;
    wire [2:0] func3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] func7;
    wire [31:0] imm_i;
    wire [31:0] imm_s;
    // wire [31:0] imm_b;
    wire [31:0] imm_u;
    wire [31:0] imm_j;

    wire [31:0] instruction;

    assign opcode = opcode_val'(instruction[6 : 0]);

    assign     rd = instruction[11: 7];
    assign  func3 = instruction[14:12];
    assign    rs1 = instruction[19:15];
    assign    rs2 = instruction[24:20];
    assign  func7 = instruction[31:25];
    assign  imm_i = {{21{instruction[31]}}, instruction[30:20]};
    assign  imm_s = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    // assign  imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign  imm_u = {instruction[31:12], {12{1'b0}}};
    assign  imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    reg [31:0]  pc;
    reg         core_hault;
    reg [31:0]  prev_inst;
    // verilator lint_off UNUSEDSIGNAL
    reg [31:0]  load_store_addr;
    // verilator lint_on UNUSEDSIGNAL
    assign ram_addr     = core_hault ? load_store_addr[ADDR_WIDTH-1+2:2] : pc[ADDR_WIDTH-1+2:2];
    assign instruction = core_hault ? prev_inst : ram_data_out;


    typedef enum logic [3:0] {
        fault_ok         = 4'd0,
        fault_decode_err = 4'd1
    } core_fault_state;

    reg [32-1:0] regs[32];
    
    wire [32-1:0]   rs1_data;
    wire [32-1:0]   rs2_data;

    assign rs1_data = (rs1 == 0) ? 32'd0 : regs[rs1];
    assign rs2_data = (rs2 == 0) ? 32'd0 : regs[rs2];

    always_ff @(posedge(clk)) begin
        if (!reset_n) begin
            pc              <= START_ADDR;
            core_fault      <= '0;
            ram_wr_en       <= '0;
            ram_wr_strobe   <= '1;
            ram_data_in     <= '0;
            core_hault      <= '0;
            prev_inst       <= '0;
            load_store_addr <= '0;
            ram_wr_en       <= 1'b0;
            regs            <= '{default: '0};
        end else begin
            pc        <= core_hault ? pc : pc + 32'd4;
            prev_inst <= instruction;
            ram_wr_en <= 1'b0;
            case (opcode)
                default:
                    begin
                        pc         <= pc;
                        core_fault <= fault_decode_err;
                    end
                op_lui: // load upper immidiate
                    begin
                        regs[rd] <= imm_u;
                    end
                op_arith:
                    begin
                        if (func3==3'b000 && func7==7'b0000000) begin // add instaruction
                            regs[rd] <= rs1_data + rs2_data;
                        end else begin
                            pc         <= pc;
                            core_fault <= fault_decode_err;
                        end
                    end
                op_jal:
                    begin
                       regs[rd] <= pc + 4;
                       pc <= pc + imm_j; // TODO: verify if this should take a + 4 byte offset 
                    end
                op_load:
                    begin
                        if (!core_hault) begin
                            if (func3 == 3'b010) begin
                                core_hault      <= 1'b1;
                                load_store_addr <= rs1_data + imm_i;
                            end else begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        end else begin
                            core_hault  <= 1'b0;
                            regs[rd] <= ram_data_out;
                        end
                    end
                op_store:
                    begin
                        if (!core_hault) begin
                            if (func3 == 3'b010) begin
                                core_hault      <= 1'b1;
                                load_store_addr <= rs1_data + imm_s;
                                ram_wr_en       <= 1'b1;
                                ram_data_in     <= rs2_data;
                            end else begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        end else begin
                            core_hault  <= 1'b0;
                        end
                    end
            endcase
        end
    end


endmodule
