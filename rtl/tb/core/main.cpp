#include "Vtop.h"
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

static void _ut_assert(bool eq, const char *expr, const char *file, int lineno) {
    if (eq)
        return;

    snprintf(assert_msg, sizeof(assert_msg), "Assertion failed (%s) at %s:%d", expr, file, lineno);

    throw system_error(EBADMSG, generic_category(), assert_msg);
}

#define ut_assert(eq) _ut_assert(eq, #eq, __FILE__, __LINE__)

VerilatedContext *ctx;
Vtop *top;
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
        top->reset_n = 1;
    });
    for (int i=0; i<20; i++) {
        eval();
    }
    pending_ops.push([](){
        top->a_wr_en = 1;
        top->a_addr = 0x1f000 >> 2;
        top->a_data_in = 0x2;
    });
    eval();
    pending_ops.push([](){
        top->a_wr_en = 1;
        top->a_addr = 0x1f004 >> 2;
        top->a_data_in = 0x3;
    });
    eval();
    pending_ops.push([](){
        top->a_wr_en = 0;
    });
    for (int i=0; i<10; i++) {
        eval();
    }
    pending_ops.push([](){
        top->a_addr = 0x1f008 >> 2;
    });
    eval();
    ut_assert(top->a_data_out == 5);
    pending_ops.push([](){
        top->a_wr_en = 1;
        top->a_addr = 0x1f000 >> 2;
        top->a_data_in = 0x20;
    });
    eval();
    pending_ops.push([](){
        top->a_wr_en = 1;
        top->a_addr = 0x1f004 >> 2;
        top->a_data_in = 0x31;
    });
    eval();
    pending_ops.push([](){
        top->a_wr_en = 0;
    });
    for (int i=0; i<10; i++) {
        eval();
    }
    pending_ops.push([](){
        top->a_addr = 0x1f008 >> 2;
    });
    eval();
    ut_assert(top->a_data_out == 0x51);
}

void load_file(string f_name) {
    string line;
    ifstream infile;
    infile.open(f_name, ios::in);
    pending_ops.push([](){
        top->a_wr_en = 0;
        top->a_wr_strobe = 0xf;
        top->reset_n = 0;
    });
    eval();
    while (getline(infile, line)) {
        long addr;
        long value;
        sscanf(line.c_str(), "%lx:%lx", &addr, &value);
        pending_ops.push([addr, value](){
            top->a_wr_en = 1;
            top->a_addr = addr >> 2;
            top->a_data_in = value;
        });
        eval();
        ut_assert((addr & 0x3) == 0x0);
    }
    pending_ops.push([](){
        top->a_wr_en = 0;
    });
    eval();
}
int main(int argc, const char **argv)
{
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    top = new Vtop{ctx};
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("simx.vcd");

    try {
        load_file("../../../src/build/test.dhex");
        run_sim();
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