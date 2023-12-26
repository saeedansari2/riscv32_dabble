`default_nettype none

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
        op_auipc         = 7'b0010111,
        op_jal           = 7'b1101111,
        op_jalr          = 7'b1100111,
        op_b_x           = 7'b1100011,
        op_load          = 7'b0000011,
        op_arith         = 7'b0110011,
        op_arith_i       = 7'b0010011,
        op_store         = 7'b0100011,
        op_fence         = 7'b0001111,
        op_esys_csr      = 7'b1110011
    } opcode_val;

    opcode_val opcode;
    wire [4:0] rd;
    wire [2:0] func3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] func7;
    wire [31:0] imm_i;
    wire [31:0] imm_s;
    wire [31:0] imm_b;
    wire [31:0] imm_u;
    wire [31:0] imm_j;

    wire [31:0] store_addr_comb;


    wire [31:0] instruction;

    assign opcode = opcode_val'(instruction[6 : 0]);

    assign store_addr_comb = rs1_data + imm_s;

    assign     rd = instruction[11: 7];
    assign  func3 = instruction[14:12];
    assign    rs1 = instruction[19:15];
    assign    rs2 = instruction[24:20];
    assign  func7 = instruction[31:25];
    assign  imm_i = {{21{instruction[31]}}, instruction[30:20]};
    assign  imm_s = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    assign  imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign  imm_u = {instruction[31:12], {12{1'b0}}};
    assign  imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    reg [31:0]  pc;
    reg         core_hault;
    reg [31:0]  prev_inst;
    // verilator lint_off UNUSEDSIGNAL
    reg [31:0]  load_store_addr;
    // verilator lint_on UNUSEDSIGNAL
    assign ram_addr    = core_hault ? load_store_addr[ADDR_WIDTH-1+2:2] : pc[ADDR_WIDTH-1+2:2];
    assign instruction = core_hault ? prev_inst : ram_data_out;


    typedef enum logic [3:0] {
        fault_ok             = 4'd0,
        fault_decode_err     = 4'd1,
        fault_illegal_access = 4'd2
    } core_fault_state;

    reg [32-1:0] regs[32];
    
    wire [32-1:0]   rs1_data;
    wire [32-1:0]   rs2_data;

    assign rs1_data = (rs1 == 0) ? 32'd0 : regs[rs1];
    assign rs2_data = (rs2 == 0) ? 32'd0 : regs[rs2];

    wire [64-1:0]   mul_res_uu;
    wire signed [64-1:0]   mul_res_su;
    wire signed [64-1:0]   mul_res_ss;

    assign mul_res_uu  = $unsigned(rs1_data) * $unsigned(rs2_data);
    assign mul_res_su  = $signed(rs1_data)   * $unsigned(rs2_data);
    assign mul_res_ss  = $signed(rs1_data)   * $signed(rs2_data);

    reg [63:0] rdcycle;
    reg [63:0] rdtime;
    reg [63:0] rdinstret;

    typedef enum logic [2:0] {
        arith_add   = 3'b000,
        arith_sll   = 3'b001,
        arith_slt   = 3'b010,
        arith_sltu  = 3'b011,
        arith_xor   = 3'b100,
        arith_sr    = 3'b101,
        arith_or    = 3'b110,
        arith_and   = 3'b111
    } arith_val;

    typedef enum logic [2:0] {
        arith_mul     = 3'b000,
        arith_mulh    = 3'b001,
        arith_mulhsu  = 3'b010,
        arith_mulhu   = 3'b011,
        arith_div     = 3'b100,
        arith_divu    = 3'b101,
        arith_rem     = 3'b110,
        arith_remu    = 3'b111
    } arith_val_m;

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
            rdcycle         <= '0;
            rdtime          <= '0;
            rdinstret       <= '0;
            regs            <= '{default: '0};
        end else begin
            pc        <= core_hault ? pc : pc + 32'd4;
            prev_inst <= instruction;
            ram_wr_en <= 1'b0;
            rdcycle   <= rdcycle + 1'b1;
            rdtime    <= rdtime + 1'b1;
            if (!core_hault) begin
                rdinstret   <= rdinstret + 1'b1;
            end
            case (opcode)
                default: begin
                    pc         <= pc;
                    core_fault <= fault_decode_err;
                end
                op_lui: begin // load upper immidiate
                    regs[rd] <= imm_u;
                end
                op_auipc: begin
                    regs[rd] <= pc + imm_u;
                end
                op_jal: begin
                    regs[rd] <= pc + 4;
                    pc       <= pc + imm_j;
                end
                op_jalr: begin
                    regs[rd] <= pc + 4;
                    pc       <= rs1_data + imm_i;
                end
                op_b_x: begin
                    case (func3)
                        default:
                            begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        3'b000:
                            begin
                                if (rs1_data == rs2_data) begin
                                    pc <= pc + imm_b;
                                end
                            end
                        3'b001:
                            begin
                                if (rs1_data != rs2_data) begin
                                    pc <= pc + imm_b;
                                end
                            end
                        3'b100:
                            begin
                                if ($signed(rs1_data) < $signed(rs2_data)) begin
                                    pc <= pc + imm_b;
                                end
                            end
                        3'b101:
                            begin
                                if ($signed(rs1_data) >= $signed(rs2_data)) begin
                                    pc <= pc + imm_b;
                                end
                            end
                        3'b110:
                            begin
                                if ($unsigned(rs1_data) < $unsigned(rs2_data)) begin
                                    pc <= pc + imm_b;
                                end
                            end
                        3'b111:
                            begin
                                if ($unsigned(rs1_data) >= $unsigned(rs2_data)) begin
                                    pc <= pc + imm_b;
                                end
                            end
                    endcase
                end
                op_arith_i: begin
                    case (func3)
                        default: begin
                            pc         <= pc;
                            core_fault <= fault_decode_err;
                        end
                        arith_add: begin
                            regs[rd]   <= rs1_data + imm_i;
                        end
                        arith_slt: begin
                            if ($signed(rs1_data) < $signed(imm_i)) begin
                                regs[rd]   <= 32'd1;
                            end else begin
                                regs[rd]   <= 32'd0;
                            end
                        end
                        arith_sltu: begin
                            if ($unsigned(rs1_data) < $unsigned(imm_i)) begin
                                regs[rd]   <= 32'd1;
                            end else begin
                                regs[rd]   <= 32'd0;
                            end
                        end
                        arith_xor: begin
                            regs[rd]   <= rs1_data ^ imm_i;
                        end
                        arith_or: begin
                            regs[rd]   <= rs1_data | imm_i;
                        end
                        arith_and: begin
                            regs[rd]   <= rs1_data & imm_i;
                        end
                        arith_sll: begin
                            if (func7==7'b0000000) begin
                                regs[rd]   <= rs1_data << imm_i[4:0];
                            end else begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        end
                        arith_sr: begin
                            if (func7==7'b0000000) begin
                                regs[rd]   <= rs1_data >> imm_i[4:0];
                            end else if (func7==7'b0100000) begin
                                regs[rd]   <= $signed(rs1_data) >>> imm_i[4:0];
                            end else begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        end
                    endcase
                end
                op_arith: begin
                    case (func7)
                        default: begin
                            case (func3)
                                default: begin
                                    pc         <= pc;
                                    core_fault <= fault_decode_err;
                                end
                                arith_add: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data + rs2_data;
                                    end else if (func7==7'b0100000) begin
                                        regs[rd]   <= rs1_data - rs2_data;
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_sll: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data << rs2_data[4:0];
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_slt: begin
                                    if (func7==7'b0000000) begin
                                        if ($signed(rs1_data) < $signed(rs2_data)) begin
                                            regs[rd]   <= 32'd1;
                                        end else begin
                                            regs[rd]   <= 32'd0;
                                        end
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_sltu: begin
                                    if (func7==7'b0000000) begin
                                        if ($unsigned(rs1_data) < $unsigned(rs2_data)) begin
                                            regs[rd]   <= 32'd1;
                                        end else begin
                                            regs[rd]   <= 32'd0;
                                        end
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_xor: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data ^ rs2_data;
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_sr: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data >> rs2_data[4:0];
                                    end else if (func7==7'b0100000) begin
                                        regs[rd]   <= $signed(rs1_data) >>> rs2_data[4:0];
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_or: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data | rs2_data;
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                                arith_and: begin
                                    if (func7==7'b0000000) begin
                                        regs[rd]   <= rs1_data & rs2_data;
                                    end else begin
                                        pc         <= pc;
                                        core_fault <= fault_decode_err;
                                    end
                                end
                            endcase
                        end
                        7'b0000001: begin
                            case (func3)
                                default: begin
                                    pc         <= pc;
                                    core_fault <= fault_decode_err;
                                end
                                arith_mul: begin
                                    regs[rd]   <= mul_res_uu[32-1:0];
                                end
                                arith_mulh: begin
                                    regs[rd]   <= mul_res_ss[64-1:32] | (mul_res_ss[32-1:0] & 32'd0);
                                end
                                arith_mulhsu: begin
                                    regs[rd]   <= mul_res_su[64-1:32] | (mul_res_su[32-1:0] & 32'd0);
                                end
                                arith_mulhu: begin
                                    regs[rd]   <= mul_res_uu[64-1:32];
                                end
                                /*
                                * The Division and Remainder are slow and big, p.s. they are as widely used as
                                * some other operations. Hence, we do not implement them here to keep our core
                                * as small as possible while still functional.
                                * They can be simply added to the next few lines if one wants to support them.
                                */
                                arith_div: begin
                                    regs[rd]   <= '0;
                                end
                                arith_divu: begin
                                    regs[rd]   <= '0;
                                end
                                arith_rem: begin
                                    regs[rd]   <= '0;
                                end
                                arith_remu: begin
                                    regs[rd]   <= '0;
                                end
                            endcase
                        end
                    endcase
                end
                op_fence: begin
                    // this is a NOP until we have muti-core or caching
                end
                op_esys_csr: begin
                    case (func3)
                        default: begin
                            pc         <= pc;
                            core_fault <= fault_decode_err;
                        end
                        3'b000: begin
                            if (rs1 == 5'b00000 && rd==5'b00000 && func7 == '0 && rs2 == '0) begin 
                                // ecall
                            end else if (rs1 == 5'b00000 && rd==5'b00000 && func7 == '0 && rs2 == 5'b00001) begin
                                // ebreak
                            end else begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                        end
                        3'b001, 3'b101: begin // csrrw or csrrwi
                            core_fault <= fault_illegal_access;
                            pc         <= pc;
                        end
                        3'b010, 3'b011, 3'b110, 3'b111: begin // csrrs or csrrc / csrrsi or csrrci
                            if (rs1 != 0) begin
                                core_fault <= fault_illegal_access;
                                pc         <= pc;
                            end else begin
                                case (imm_i[11:0])
                                    default: begin
                                        core_fault <= fault_illegal_access;
                                        pc         <= pc;
                                    end
                                    12'hc00: begin
                                        regs[rd]      <= rdcycle[31:0];
                                    end
                                    12'hc01: begin
                                        regs[rd]      <= rdtime[31:0];
                                    end
                                    12'hc02: begin
                                        regs[rd]      <= rdinstret[31:0];
                                    end
                                    12'hc80: begin
                                        regs[rd]      <= rdcycle[63:32];
                                    end
                                    12'hc81: begin
                                        regs[rd]      <= rdtime[63:32];
                                    end
                                    12'hc82: begin
                                        regs[rd]      <= rdinstret[63:32];
                                    end
                                endcase
                            end
                        end
                    endcase
                end
                op_load: begin
                    if (!core_hault) begin
                        if (func3 == 3'b010 || func3 == 3'b001 ||
                                func3 == 3'b000 || func3 == 3'b101 ||
                                func3 == 3'b100) begin
                            core_hault      <= 1'b1;
                            load_store_addr <= rs1_data + imm_i;
                        end else begin
                            pc              <= pc;
                            core_fault      <= fault_decode_err;
                        end
                    end else begin
                        core_hault  <= 1'b0;
                        case (func3)
                            default: begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                            end
                            3'b010: begin
                                regs[rd]   <= ram_data_out;
                            end
                            3'b001: begin
                                if (load_store_addr[1]) begin
                                    regs[rd] <= {{16{ram_data_out[31]}}, ram_data_out[31:16]};
                                end else begin
                                    regs[rd] <= {{16{ram_data_out[15]}}, ram_data_out[15:0]};
                                end
                            end
                            3'b000: begin
                                case (load_store_addr[1:0])
                                    2'b00: begin
                                        regs[rd] <= {{24{ram_data_out[7]}}, ram_data_out[7:0]};
                                    end
                                    2'b01: begin
                                        regs[rd] <= {{24{ram_data_out[15]}}, ram_data_out[15:8]};
                                    end
                                    2'b10: begin
                                        regs[rd] <= {{24{ram_data_out[23]}}, ram_data_out[23:16]};
                                    end
                                    2'b11: begin
                                        regs[rd] <= {{24{ram_data_out[31]}}, ram_data_out[31:24]};
                                    end
                                endcase
                            end
                            3'b101: begin
                                if (load_store_addr[1]) begin
                                    regs[rd] <= {16'd0, ram_data_out[31:16]};
                                end else begin
                                    regs[rd] <= {16'd0, ram_data_out[15:0]};
                                end
                            end
                            3'b100: begin
                                case (load_store_addr[1:0])
                                    2'b00: begin
                                        regs[rd] <= {24'd0, ram_data_out[7:0]};
                                    end
                                    2'b01: begin
                                        regs[rd] <= {24'd0, ram_data_out[15:8]};
                                    end
                                    2'b10: begin
                                        regs[rd] <= {24'd0, ram_data_out[23:16]};
                                    end
                                    2'b11: begin
                                        regs[rd] <= {24'd0, ram_data_out[31:24]};
                                    end
                                endcase
                            end
                        endcase
                    end
                end
                op_store: begin
                    if (!core_hault) begin
                        core_hault      <= 1'b1;
                        load_store_addr <= store_addr_comb;
                        ram_wr_en       <= 1'b1;
                        case (func3)
                            3'b010: begin
                                ram_wr_strobe <= 4'b1111;
                                ram_data_in   <= rs2_data;
                            end
                            3'b001: begin
                                case (store_addr_comb[1])
                                    0: begin
                                        ram_wr_strobe <= 4'b0011;
                                        ram_data_in   <= rs2_data;
                                    end
                                    1: begin
                                        ram_wr_strobe      <= 4'b1100;
                                        ram_data_in[31:16] <= rs2_data[15:0];
                                    end
                                endcase
                            end
                            3'b000: begin
                                case (store_addr_comb[1:0])
                                    2'b00: begin
                                        ram_wr_strobe <= 4'b0001;
                                        ram_data_in   <= rs2_data;
                                    end
                                    2'b01: begin
                                        ram_wr_strobe     <= 4'b0010;
                                        ram_data_in[15:8] <= rs2_data[7:0];
                                    end
                                    2'b10: begin
                                        ram_wr_strobe      <= 4'b0100;
                                        ram_data_in[23:16] <= rs2_data[7:0];
                                    end
                                    2'b11: begin
                                        ram_wr_strobe      <= 4'b1000;
                                        ram_data_in[31:24] <= rs2_data[7:0];
                                    end
                                endcase
                            end
                            default: begin
                                pc         <= pc;
                                core_fault <= fault_decode_err;
                                core_hault <= 1'b0;
                                ram_wr_en  <= 1'b0;
                            end
                        endcase
                    end else begin
                        core_hault  <= 1'b0;
                    end
                end
            endcase
        end
    end


endmodule
