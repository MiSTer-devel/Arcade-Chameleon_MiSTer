
module ram
#(
  parameter addr_width=12,
  parameter data_width=8
)
(
  input clk,
  input [addr_width-1:0] addr,
  input [data_width-1:0] din,
  output [data_width-1:0] q,
  output reg ready,
  input rd_n,
  input wr_n,
  input ce_n
);

reg [data_width-1:0] data;
reg [data_width-1:0] mem[(1<<addr_width)-1:0];
reg old_rd_n;

assign q = ~ce_n ? data : 0;

always @(posedge clk) begin

  old_rd_n <= rd_n;
  if (~rd_n & old_rd_n) ready <= 1'b0;

  if (~ready) begin
    data <= mem[addr];
    ready <= 1'b1;
  end

  if (~ce_n & ~wr_n) mem[addr] <= din;

end


endmodule