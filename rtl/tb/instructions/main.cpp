//------------------------------------------------------------------------------
// Test bench for individual operations
// Note: This simulation relies on serveral core internals in order to simplify
//       testing. It will need to be updated anytime the execution state or
//       register access changes for the core
//------------------------------------------------------------------------------
#include "Vrv32_core.h"
#include "Vrv32_core___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <functional>
#include <queue>
#include <system_error>
#include <fstream>
#include <string>

#define FG_RED "\033[31m"
#define FG_GREEN "\033[32m"
#define FG_RESET "\033[0m"

using namespace std;

queue<function<void()>> pending_ops;

char assert_msg[1024];

VerilatedContext *ctx;
Vrv32_core *top;
VerilatedVcdC *tfp;

struct registers {
    uint32_t r0;
    uint32_t r1;
    uint32_t r2;
    uint32_t r3;
    uint32_t r4;
    uint32_t r5;
    uint32_t r6;
    uint32_t r7;
    uint32_t r8;
    uint32_t r9;
    uint32_t r10;
    uint32_t r11;
    uint32_t r12;
    uint32_t r13;
    uint32_t r14;
    uint32_t r15;
    uint32_t r16;
    uint32_t r17;
    uint32_t r18;
    uint32_t r19;
    uint32_t r20;
    uint32_t r21;
    uint32_t r22;
    uint32_t r23;
    uint32_t r24;
    uint32_t r25;
    uint32_t r26;
    uint32_t r27;
    uint32_t r28;
    uint32_t r29;
    uint32_t r30;
    uint32_t r31;
};

static void eval()
{
    while (pending_ops.size() > 0) {
        pending_ops.front()();
        pending_ops.pop();
    }
    top->clk = 0;
    ctx->timeInc(1);
    top->eval();
    tfp->dump(ctx->time());
    top->clk = 1;
    ctx->timeInc(1);
    top->eval();
    tfp->dump(ctx->time());
}

static void _ut_assert(bool eq, const char *expr, const char *file, int lineno) {
    if (eq)
        return;

    snprintf(assert_msg, sizeof(assert_msg), "Assertion failed (%s) at %s:%d", expr, file, lineno);
    eval();
    throw system_error(EBADMSG, generic_category(), assert_msg);
}

#define ut_assert(eq) _ut_assert(eq, #eq, __FILE__, __LINE__)

#define BIT_MASK(bits) (uint32_t)((1ull << (uint64_t)(bits)) - 1ull)
#define BITS_MASK(msb, lsb) (BIT_MASK((msb) + 1) ^ BIT_MASK(lsb))
#define BITS(val, msb, lsb) ((val & BITS_MASK(msb, lsb)) >> (lsb))

#define R_TYPE_FN7(fn) (((fn) & 0x7f) << 25)
#define R_TYPE_RS2(r) (((r) & 0x1f) << 20)
#define R_TYPE_RS1(r) (((r) & 0x1f) << 15)
#define R_TYPE_FN3(fn) (((fn) & 0x7) << 12)
#define R_TYPE_RD(rd) (((rd) & 0x1f) << 7)

#define I_TYPE_IMM(imm) (((imm) & 0xfff) << 20)
#define I_TYPE_RS1(rs) (((rs) & 0x1f) << 15)
#define I_TYPE_FN3(fn) (((fn) & 7) << 12)
#define I_TYPE_RD(rd) (((rd) & 0x1f) << 7)

#define S_TYPE_IMM(imm) ((((imm) & 0xfe0) << 20) | (((imm) & 0x1f) << 7))
#define S_TYPE_RS2(r) (((r) & 0x1f) << 20)
#define S_TYPE_RS1(r) (((r) & 0x1f) << 15)
#define S_TYPE_FN3(fn) (((fn) & 0x7) << 12)

#define U_TYPE_IMM(imm) ((imm) & 0xfffff000)
#define U_TYPE_RD(rd) (((rd) & 0x1f) << 7)

#define J_TYPE_IMM(imm) ( \
    (BITS(imm, 20, 20) << 31) | \
    (BITS(imm, 10, 1) << 21) | \
    (BITS(imm, 11, 11) << 20) | \
    (BITS(imm, 19, 12) << 12) \
)
#define J_TYPE_RD(rd) (((rd) & 0x1f) << 7)

#define OPCODE_LUI      0b0110111
#define OPCODE_AUIPC    0b0010111
#define OPCODE_JAL      0b1101111
#define OPCODE_JALR     0b1100111
#define OPCODE_ARITH    0b0110011
#define OPCODE_LOAD     0b0000011
#define OPCODE_STORE    0b0100011

#define OP_LUI(imm, rd) (U_TYPE_IMM(imm) | U_TYPE_RD(rd) | OPCODE_LUI)
#define OP_AUIPC(imm, rd) (U_TYPE_IMM(imm) | U_TYPE_RD(rd) | OPCODE_AUIPC)
#define OP_JAL(imm, rd) (J_TYPE_IMM(imm) | J_TYPE_RD(rd) | OPCODE_JAL)
#define OP_JALR(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b000) | I_TYPE_RD(rd) | OPCODE_JALR)
#define OP_ADD(rs2, rs1, rd) (R_TYPE_FN7(0b0000000) | R_TYPE_RS2(rs2) | \
    R_TYPE_RS1(rs1) | R_TYPE_FN3(0b000) | R_TYPE_RD(rd) | OPCODE_ARITH)
#define OP_LW(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b010) | I_TYPE_RD(rd) | OPCODE_LOAD)
#define OP_LH(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b001) | I_TYPE_RD(rd) | OPCODE_LOAD)
#define OP_LB(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b000) | I_TYPE_RD(rd) | OPCODE_LOAD)
#define OP_LUH(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b101) | I_TYPE_RD(rd) | OPCODE_LOAD)
#define OP_LUB(imm, rs1, rd) (I_TYPE_IMM(imm) | I_TYPE_RS1(rs1) | \
    I_TYPE_FN3(0b100) | I_TYPE_RD(rd) | OPCODE_LOAD)
#define OP_SW(imm, rs2, rs1) (S_TYPE_IMM(imm) | S_TYPE_RS2(rs2) | \
    S_TYPE_RS1(rs1) | S_TYPE_FN3(0b010) | OPCODE_STORE)
#define OP_SH(imm, rs2, rs1) (S_TYPE_IMM(imm) | S_TYPE_RS2(rs2) | \
    S_TYPE_RS1(rs1) | S_TYPE_FN3(0b001) | OPCODE_STORE)
#define OP_SB(imm, rs2, rs1) (S_TYPE_IMM(imm) | S_TYPE_RS2(rs2) | \
    S_TYPE_RS1(rs1) | S_TYPE_FN3(0b000) | OPCODE_STORE)

static void grab_regs(struct registers &regs_val)
{
    // Note: hardware reads zeros on src reg decode on the version this was
    //       written for, MUST be updated if register access changes
    regs_val.r0 = 0;

    for (int i = 1; i < 32; i++)
        ((uint32_t *)&regs_val)[i] = top->rootp->rv32_core__DOT__regs[i];
}

static void set_regs(struct registers regs_val)
{
    pending_ops.push([regs_val](){
        for (int i = 1; i < 32; i++)
            top->rootp->rv32_core__DOT__regs[i] = ((uint32_t *)&regs_val)[i];
    });
}

static bool check_regs(const struct registers regs_val) {
    struct registers regs;
    bool eq = true;

    grab_regs(regs);

    for (int i = 0; i < 32; i++) {
        if (((uint32_t *)&regs_val)[i] != ((uint32_t *)&regs)[i]) {
            eq = false;
            fprintf(stderr, FG_RED "r%d 0x(%x) != expected 0x%x\n" FG_RESET,
                    i, ((uint32_t *)&regs)[i], ((uint32_t *)&regs_val)[i]);
        }
    }
    return eq;
}

static void run_reset() {
    pending_ops.push([](){
        top->reset_n = 0;
    });

    eval();
    pending_ops.push([](){
        top->reset_n = 1;
    });
}

static void run_op(uint32_t val) {
    pending_ops.push([val](){
        top->ram_data_out = val;
    });

    eval();
    ut_assert(!top->rootp->rv32_core__DOT__core_hault);
    ut_assert(!top->ram_wr_en);
    ut_assert(top->core_fault == 0);
}

static void run_op_w_read(uint32_t val, uint32_t exp_addr, uint32_t mem_val) {
    pending_ops.push([val](){
        top->ram_data_out = val;
    });

    eval();
    ut_assert(top->rootp->rv32_core__DOT__core_hault);
    ut_assert(!top->ram_wr_en);
    if (top->ram_addr << 2 != exp_addr) {
        fprintf(stderr, "load address 0x%x != exected 0x%x\n",
                top->ram_addr << 2, exp_addr);
    }
    ut_assert(top->ram_addr << 2 == exp_addr);
    pending_ops.push([mem_val](){
        top->ram_data_out = mem_val;
    });
    ut_assert(top->core_fault == 0);

    eval();
    ut_assert(!top->rootp->rv32_core__DOT__core_hault);
    ut_assert(!top->ram_wr_en);
    ut_assert(top->core_fault == 0);
}

static void run_op_w_write(uint32_t val, uint32_t exp_addr, uint8_t exp_wr_strobe, uint32_t exp_mem_val) {
    pending_ops.push([val](){
        top->ram_data_out = val;
    });

    eval();
    ut_assert(top->rootp->rv32_core__DOT__core_hault);
    ut_assert(top->ram_wr_en);

    if (top->ram_wr_strobe != exp_wr_strobe) {
        fprintf(stderr, "ram wr mask 0x%x != expected 0x%x\n",
                top->ram_wr_strobe, exp_wr_strobe);
    }
    ut_assert(top->ram_wr_strobe == exp_wr_strobe);

    uint32_t wr_mask = 0;
    for (int i = 0; i < 4; i++) {
        if (exp_wr_strobe & (1 << i))
            wr_mask |= BITS_MASK(i * 8 + 7, i * 8);
    }
    if ((top->ram_data_in & wr_mask) != (exp_mem_val & wr_mask)) {
        fprintf(stderr, "ram data 0x%x != expected 0x%x\n",
                top->ram_data_in & wr_mask, exp_mem_val & wr_mask);
    }
    ut_assert((top->ram_data_in & wr_mask) == (exp_mem_val & wr_mask));

    if (top->ram_addr << 2 != exp_addr) {
        fprintf(stderr, "load address 0x%x != exected 0x%x\n",
                top->ram_addr << 2, exp_addr);
    }
    ut_assert(top->ram_addr << 2 == exp_addr);
    ut_assert(top->core_fault == 0);

    eval();
    ut_assert(!top->rootp->rv32_core__DOT__core_hault);
    ut_assert(!top->ram_wr_en);
    ut_assert(top->core_fault == 0);
}

static void test_lui() {
    struct registers regs;

    run_reset();
    grab_regs(regs);

    // Write reg 1
    regs.r1 = 0x70000000;
    run_op(OP_LUI(regs.r1, 1));
    ut_assert(check_regs(regs));

    // Check for propper masking (tested in reg 4)
    regs.r4 = 0x4000ff01;
    run_op(OP_LUI(regs.r4, 4));
    //run_op(U_TYPE_IMM(reg_state[4]) | U_TYPE_RD(4) | OP_LUI);
    regs.r4 = 0x4000f000;
    ut_assert(check_regs(regs));

    /*
     * That r0 can't be written to (not really tested in this sim, but usefull
     * if reg access changes in the future)
     */
    run_op(OP_LUI(0xffffffff, 0));
    regs.r0 = 0;
    ut_assert(check_regs(regs));

    fprintf(stderr, FG_GREEN "lui tests passed!\n" FG_RESET);
}

static void test_add() {
    struct registers regs;

    run_reset();
    grab_regs(regs);

    regs.r1 = 0x70000000;
    set_regs(regs);
    run_op(OP_ADD(0, 1, 2));
    regs.r2 = 0x70000000;
    ut_assert(check_regs(regs));

    // Test modify r0, not really a test with the current sim
    run_op(OP_ADD(1, 2, 0));
    ut_assert(check_regs(regs));

    // Test using r0, this will actually test r0 internally
    run_op(OP_ADD(0, 2, 3));
    regs.r3 = 0x70000000;
    ut_assert(check_regs(regs));

    regs.r2 = 0x70000001;
    set_regs(regs);
    run_op(OP_ADD(2, 3, 4));
    regs.r4 = 0xe0000001;
    ut_assert(check_regs(regs));

    fprintf(stderr, FG_GREEN "add tests passed!\n" FG_RESET);
}

static void test_load() {
    struct registers regs;

    run_reset();
    grab_regs(regs);

    // Load 32-bit value
    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LW(0x10, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x12345678;
    ut_assert(check_regs(regs));

    // Load 16-bit value
    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LH(0x10, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x5678;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LH(0x12, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x1234;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LH(0x10, 1, 2), 0xe10, 0x9234c678);
    regs.r2 = 0xffffc678;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LH(0x12, 1, 2), 0xe10, 0x9234c678);
    regs.r2 = 0xffff9234;
    ut_assert(check_regs(regs));

    // Load 8-bit value
    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x10, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x78;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x11, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x56;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x12, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x34;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x13, 1, 2), 0xe10, 0x12345678);
    regs.r2 = 0x12;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x10, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xffffffe8;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x11, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xffffffd6;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x12, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xffffffb4;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LB(0x13, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xffffff92;
    ut_assert(check_regs(regs));

    // Load 16-bit unsigned value
    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUH(0x10, 1, 2), 0xe10, 0x9234c678);
    regs.r2 = 0xc678;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUH(0x12, 1, 2), 0xe10, 0x9234c678);
    regs.r2 = 0x9234;
    ut_assert(check_regs(regs));

    // Load 8-bit value
    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUB(0x10, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xe8;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUB(0x11, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xd6;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUB(0x12, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0xb4;
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    set_regs(regs);
    run_op_w_read(OP_LUB(0x13, 1, 2), 0xe10, 0x92b4d6e8);
    regs.r2 = 0x92;
    ut_assert(check_regs(regs));

    fprintf(stderr, FG_GREEN "load tests passed!\n" FG_RESET);
}

static void test_store() {
    struct registers regs;

    run_reset();
    grab_regs(regs);

    // 32-bit store
    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SW(0x10, 2, 1), 0xe10, 0xf, 0x1234abcd);
    ut_assert(check_regs(regs));

    // 16-bit store
    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SH(0x10, 2, 1), 0xe10, 0x3, 0xabcd);
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SH(0x12, 2, 1), 0xe10, 0xc, 0xabcd0000);
    ut_assert(check_regs(regs));

    // 8-bit store
    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SB(0x10, 2, 1), 0xe10, 0x1, 0xcd);
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SB(0x11, 2, 1), 0xe10, 0x2, 0xcd00);
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SB(0x12, 2, 1), 0xe10, 0x4, 0xcd0000);
    ut_assert(check_regs(regs));

    regs.r1 = 0x70000e00;
    regs.r2 = 0x1234abcd;
    set_regs(regs);
    run_op_w_write(OP_SB(0x13, 2, 1), 0xe10, 0x8, 0xcd000000);
    ut_assert(check_regs(regs));

    fprintf(stderr, FG_GREEN "store tests passed!\n" FG_RESET);
}

static void test_jal() {
    struct registers regs;
    uint32_t pc;

    run_reset();
    grab_regs(regs);

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(-16, 1));
    regs.r1 = pc + 4;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc - 16);

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1024, 2));
    regs.r2 = pc + 4;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + 1024);

    // Check every valid imm bit boundary
    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1 << 2, 3));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + (1 << 2));

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1 << 10, 3));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + (1 << 10));

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1 << 11, 3));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + (1 << 11));

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1 << 12, 3));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + (1 << 12));

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    run_op(OP_JAL(1 << 19, 3));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + (1 << 19));
    // bit 20 is already covered by the -16 test (sign bit) and 19 not going
    // the wrong way

    fprintf(stderr, FG_GREEN "jal tests passed!\n" FG_RESET);
}

static void test_auipc() {
    struct registers regs;
    uint32_t pc;
    uint32_t offset;

    run_reset();
    grab_regs(regs);

    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    offset = 1 << 12;
    run_op(OP_AUIPC(offset, 1));
    regs.r1 = pc + offset;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + 4);

    // Test offset too small to encode
    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    offset = 1 << 11;
    run_op(OP_AUIPC(offset, 1));
    regs.r1 = pc;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == pc + 4);
}

static void test_jalr() {
    struct registers regs;
    uint32_t offset;
    uint32_t pc;

    run_reset();
    grab_regs(regs);

    regs.r1 = 0x100;
    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    offset = 1 << 10;
    run_op(OP_JALR(offset, 1, 2));
    regs.r2 = pc + 4;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == regs.r1 + offset);

    // sign extend
    regs.r1 = 0x100;
    pc = top->rootp->rv32_core__DOT__pc;
    set_regs(regs);
    offset = 1 << 11;
    run_op(OP_JALR(offset, 1, 2));
    offset = 0xfffff800;
    regs.r2 = pc + 4;
    ut_assert(check_regs(regs));
    ut_assert(top->rootp->rv32_core__DOT__pc == regs.r1 + offset);
}

static void run_sim() {
    test_lui();
    test_auipc();
    test_jal();
    test_jalr();
    test_add();
    test_load();
    test_store();
}

int main(int argc, const char **argv) {
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    top = new Vrv32_core{ctx};
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("simx.vcd");

    try {
        run_sim();
        eval(); // Final eval to display values check in last step
        tfp->close();
        delete tfp;
        delete top;
        delete ctx;
        printf(FG_GREEN "Simulation Successfull!\n" FG_RESET);
    } catch (system_error &err) {
        fprintf(stderr, FG_RED "%s\n" FG_RESET, err.what());
        tfp->close();
        delete tfp;
        delete top;
        delete ctx;
    }
    return 0;
}