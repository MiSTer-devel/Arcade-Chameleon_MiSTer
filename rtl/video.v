
module video(
  input clk,
  output reg hs,
  output reg vs,
  output reg hb,
  output reg vb,
  output reg [8:0] hcount,
  output reg [8:0] vcount,
  output reg frame
);


initial begin
  hs <= 1'b1;
  vs <= 1'b1;
end

always @(posedge clk) begin
  frame <= 1'b0;
  hcount <= hcount + 9'd1;
  case (hcount)
    0: hb <= 1'b0;
    256: hb <= 1'b1;
    274: hs <= 1'b0;
    299: hs <= 1'b1;
    442: begin
      vcount <= vcount + 9'd1;
      hcount <= 9'b0;
      case (vcount)
        224: vb <= 1'b1;
        242: vs <= 1'b0;
        245: vs <= 1'b1;
        262: begin
          frame <= 1'b1;
          vcount <= 9'd0;
          vb <= 1'b0;
        end
      endcase
    end
  endcase
end

endmodule
