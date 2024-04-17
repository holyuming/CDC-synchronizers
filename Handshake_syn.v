module Handshake_syn #(parameter WIDTH=32) (
    sclk,
    dclk,
    rst_n,
    sready, // source din is valid
    din,
    dbusy,  // destination is busy
    sidle,  // source is idle
    dvalid,
    dout
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output reg sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// request and ack
reg sreq;
wire dreq;
reg dack;
wire sack;

reg [WIDTH-1:0] data;
reg [1:0] dstate, n_dstate; // dclk state
reg [1:0] sstate, n_sstate; // sclk state

localparam D_IDLE = 0, D_ACK = 1, D_WAIT_NEXT = 2;
localparam S_IDLE = 0, S_WAIT_ACK1 = 1, S_WAIT_ACK0 = 2;


// double flip flops: NDFF_syn(D, Q, clk, rst_n);
NDFF_syn S2D (sreq, dreq, dclk, rst_n);
NDFF_syn D2S (dack, sack, sclk, rst_n);


// store din when sready == 1
always @(posedge sclk or negedge rst_n) begin
    if (!rst_n) data <= 0;
    else        data <= (sready == 1 && sstate == S_IDLE) ? din : data;             // when sready = 1, we store the din
end


// sclk sstate
always @(*) begin
    case (sstate)
        S_IDLE:      n_sstate = (sready == 1)   ? S_WAIT_ACK1   : S_IDLE;
        S_WAIT_ACK1: n_sstate = (sack == 1)     ? S_WAIT_ACK0   : S_WAIT_ACK1;  // we wait to receive ACK from dclk domain
        S_WAIT_ACK0: n_sstate = (sack == 0)     ? S_IDLE        : S_WAIT_ACK0;  // after ACK is pull low, we can go back to IDLE
        default:     n_sstate = S_IDLE;
    endcase
end

always @(posedge sclk or negedge rst_n) begin
    if (!rst_n)     sstate <= S_IDLE;
    else            sstate <= n_sstate;
end


// sreq
always @(posedge sclk or negedge rst_n) begin
    if (!rst_n)     sreq <= 0;
    else begin
        case (n_sstate)
            S_IDLE,
            S_WAIT_ACK0:    sreq <= 0; // after we recieve sack = 0, we can drop our sreq = 0
            S_WAIT_ACK1:    sreq <= 1; // we are waiting sack to be 1, so we have to keep our sreq high
        endcase        
    end
end


// sender idle
always @(*) begin
    sidle = (sstate == S_IDLE);     // it tells sender clk domain we are idle or not
end


// dclk dstate
always @(*) begin
    case (dstate)
        D_IDLE:     n_dstate = (dreq == 1 && dbusy == 0) ? D_WAIT_NEXT : D_IDLE;
        D_WAIT_NEXT:n_dstate = (dreq == 0) ? D_IDLE : D_WAIT_NEXT;              // after sreq pull down, we can observe dreq = 0 later, so that we can go back to IDLE in dclk domain
        default:    n_dstate = D_IDLE;
    endcase
end

always @(posedge dclk or negedge rst_n) begin
    if (!rst_n)     dstate <= D_IDLE;
    else            dstate <= n_dstate;
end


// dack
always @(posedge dclk or negedge rst_n) begin
    if (!rst_n)     dack <= 0;
    else            dack <= (n_dstate == D_IDLE) ? 0 : 1;   // when we receive sreq --> dreq = 1, we can send back ACK signal: dack --> sack 
end


// output
always @(posedge dclk or negedge rst_n) begin
    if (!rst_n) begin
        dvalid  <= 0;
        dout    <= 0;
    end  
    else begin
        if (dstate == D_IDLE && (dreq == 1 && dbusy == 0)) begin
            dvalid  <= 1;
            dout    <= data;
        end else begin
            dvalid  <= 0;
            dout    <= dout;
        end
    end
end


endmodule