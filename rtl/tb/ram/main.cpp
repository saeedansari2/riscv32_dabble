#include "Vram.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <functional>
#include <queue>
#include <system_error>

using namespace std;

queue<function<void()>> pending_ops;

char assert_msg[1024];

static void _ut_assert(bool eq, const char *expr, const char *file, int lineno) {
    if (eq)
        return;

    snprintf(assert_msg, sizeof(assert_msg), "Assertion failed (%s) at %s:%d", expr, file, lineno);

    throw system_error(EBADMSG, generic_category(), assert_msg);
}

#define ut_assert(eq) _ut_assert(eq, #eq, __FILE__, __LINE__)

VerilatedContext *ctx;
Vram *top;
VerilatedVcdC *tfp;

static void eval()
{
    top->clk = 1;
    top->eval();
    while (pending_ops.size() > 0) {
        pending_ops.front()();
        pending_ops.pop();
    }
    ctx->timeInc(1);
    top->eval();
    tfp->dump(ctx->time());
    top->clk = 0;
    ctx->timeInc(1);
    top->eval();
    tfp->dump(ctx->time());
}

void run_sim()
{
    pending_ops.push([](){
        //top->rd_en = 0;
        top->wr_en = 0;
        top->data_in = 0xabcdef;
        top->addr = 0x100;
        top->wr_strobe = 0xf;
    });
    eval();
    pending_ops.push([](){
        top->wr_en = 1;
        //top->rd_en = 1;
    });
    eval();
    pending_ops.push([](){
        top->wr_en = 0;
        //top->rd_en = 0;
    });
    eval();
    pending_ops.push([](){
        top->data_in = 0x1234567;
        top->addr = 0x101;
        top->wr_en = 1;
        //top->rd_en = 1;
    });
    eval();
    pending_ops.push([](){
        top->wr_en = 0;
        //top->rd_en = 0;
    });
    eval();
    pending_ops.push([](){
        top->data_in = 0x1234567;
        top->addr = 0x100;
        top->wr_en = 1;
        //top->rd_en = 1;
    });
    eval();
    ut_assert(top->data_out == 0xabcdef);
    pending_ops.push([](){
        top->wr_en = 0;
        //top->rd_en = 0;
    });
    eval();
    pending_ops.push([](){
        top->data_in = 0xbaddad;
        top->addr = 0x101;
        top->wr_en = 1;
        //top->rd_en = 1;
    });
    eval();
    ut_assert(top->data_out == 0x1234567);
    pending_ops.push([](){
        top->wr_en = 0;
        //top->rd_en = 0;
    });
    eval();
}

int main(int argc, const char **argv)
{
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    top = new Vram{ctx};
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("simx.vcd");

    try {
        run_sim();
        tfp->close();
        delete tfp;
        delete top;
        delete ctx;
        printf("Simulation Successfull!\n");
    } catch (system_error &err) {
        fprintf(stderr, "%s\n", err.what());
        tfp->close();
        delete tfp;
        delete top;
        delete ctx;
    }
    return 0;
}