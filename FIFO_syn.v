module FIFO_syn #(parameter WIDTH=32, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

wire [WIDTH-1:0] rdata_q;
localparam ASIZE = $clog2(WORDS);

// wptr and rptr should be gray coded, with extra bit
reg [ASIZE:0] wptr;
reg [ASIZE:0] rptr;

reg [ASIZE:0] wbin;
reg [ASIZE:0] n_wptr, n_wbin;

reg [ASIZE:0] rbin;
reg [ASIZE:0] n_rptr, n_rbin;

// address of SRAM, with normal bit
reg [ASIZE-1:0] waddr, raddr;

// sync_w2r & sync_r2w
wire [ASIZE:0] rq2_wptr, wq2_rptr; // with extra bit
// double flip flops synchronizer
NDFF_BUS_syn #(.WIDTH(ASIZE+1)) sync_w2r (wptr, rq2_wptr, rclk, rst_n);
NDFF_BUS_syn #(.WIDTH(ASIZE+1)) sync_r2w (rptr, wq2_rptr, wclk, rst_n);


// write full
always @(*) begin
    n_wbin = wbin + (winc & ~wfull);
    n_wptr = (n_wbin >> 1) ^ n_wbin; // calculate gray code
end

always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) begin
        wbin    <= 0; // binary code with extra bit, the actual waddr to sram, the leading bit of wbin is to indicate whether fifo is full or empty
        wptr    <= 0; // gray code with extra bit
        wfull   <= 0;
    end else begin
        wbin    <= n_wbin;
        wptr    <= n_wptr;

        // next pointer where i'm gonna write == next pointer where i'm gonna read 
        wfull   <= (n_wptr == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]}); // it is equivalent to {n_wbin[MSB] != rbin[MSB], n_wbin[REST] == rbin[REST]}
    end
end

// read empty
always @(*) begin
    n_rbin = rbin + (rinc & ~rempty);
    n_rptr = (n_rbin >> 1) ^ n_rbin; // calculate gray code
end

always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) begin
        rbin    <= 0;
        rptr    <= 0;
        rempty  <= 1;
    end else begin
        rbin    <= n_rbin;
        rptr    <= n_rptr;
        rempty  <= (n_rptr == rq2_wptr); // next pointer where i'm gonna read == next pointer where i'm gonna write 
    end
end

// dual port SRAM
wire wclken;
assign wclken = ~winc | wfull; // equivalent to ~(winc & ~wfull), when write request (winc == 1) and fifo isn't full (~wfull), our wclken should be 0, wclken is the WEN of sram port. (0 when Write, 1 when Read)

always @(*) begin
    waddr = wbin[ASIZE-1:0];
    raddr = rbin[ASIZE-1:0];
end

// +=========================================+
// |                                         |
// |          MEMORY: sram or FF             |
// |                                         |
// +=========================================+

// FF
reg [WIDTH-1:0] mem [0:WORDS-1];

always @(posedge rclk) begin
    rdata <= mem[raddr];
end

always @(posedge wclk) begin
    if (wclken == 0)
        mem[waddr] <= wdata;
end

// SRAM
// reg CSB;

// always @(*) begin
//     if (rempty == 1)    CSB = 0; // whenever fifo is empty, we turn off read port
//     else                CSB = 1;
// end

// DUAL_PORT_SRAM mem (
//     .clkA(wclk),
//     .clkB(rclk),

//     // write enable: 0: write, 1: read
//     .WEAN(wclken),
//     .WEBN(1'b1),

//     // chip enable
//     .CSA(1'b1),
//     .CSB(CSB),

//     // output enable
//     .OEA(1'b1),
//     .OEB(1'b1),

//     .addr_A(waddr),
//     .addr_B(raddr),
//     .DIA(wdata);
//     .DOA(),
//     .DIB(),
//     .DOB(rdata);
// );

endmodule