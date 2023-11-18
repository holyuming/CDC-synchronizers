// 1 bit synchronizer
module NDFF_syn(D, Q, clk, rst_n);
input D;
input clk;
input rst_n;  
output Q;


reg A1,A2;
assign Q = A2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        A1 <= 0;
        A2 <= 0;
    end else begin
        A1 <= D;
        A2 <= A1;  
    end
end

endmodule