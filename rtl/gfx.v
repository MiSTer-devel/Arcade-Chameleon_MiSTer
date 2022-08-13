
module gfx(
  input             clk,
  output      [7:0] h,
  output      [7:0] v,
  output reg [11:0] ram_addr,
  input       [7:0] ram_data,
  output reg [12:0] gfx1_addr,
  input       [7:0] gfx1_data,
  output reg [12:0] gfx2_addr,
  input       [7:0] gfx2_data,
  output reg  [4:0] spr_addr,
  input      [31:0] spr_data,
  output reg  [5:0] color_index,
  input       [7:0] color_data,
  input             bank,
  
  output reg  [2:0] r, g,
  output reg  [1:0] b,
  output reg        done,
  output reg        frame,
  
  input             h_flip,
  input             v_flip
);

reg [3:0] next;
reg [3:0] state;
reg [7:0] oldhh;

wire pxdt1 = gfx1_data[7-hh[2:0]+:1];
wire pxdt2 = gfx2_data[7-hh[2:0]+:1];
wire pxdt3 = gfx1_data[7-px[2:0]+:1];
wire pxdt4 = gfx2_data[7-px[2:0]+:1];

reg [3:0] px, py;
reg [7:0] sdat1, sdat2;

reg  [7:0] hh;
reg  [7:0] vv;

assign h = h_flip ? 256 - hh : hh;
assign v = v_flip ? 256 - vv : vv;

always @(posedge clk) begin
  case (state)
    4'd0: begin
      frame <= 1'b0;
      ram_addr <= { 2'b01, vv[7:3], hh[7:3] };
      done <= 1'b0;
      next <= 4'd1;
      state <= 4'd7;
    end
    4'd1: begin
      ram_addr  <= { 2'b10, vv[7:3], hh[7:3] };
      gfx1_addr <= { bank, ram_data, vv[2:0] };
      gfx2_addr <= { bank, ram_data, vv[2:0] };
      next <= 4'd2;
      state <= 4'd7;
    end
    4'd2: begin
      color_index[5:2] <= ram_data[3:0];
      color_index[1:0] <= { pxdt1, pxdt2 };
      next <= 4'd3;
      state <= 4'd7;
    end
    4'd3: begin
      r <= color_data[2:0];
      g <= color_data[5:3];
      b <= color_data[7:6];
      done <= 1'b1;
      hh <= hh + 8'd1;
      if (hh == 255) vv <= vv + 8'd1;
      if (vv == 255 && hh == 255) begin
        spr_addr <= 5'd31;
        px <= 4'd0;
        py <= 4'd0;
        next <= 4'd8;
        state <= 4'd7;
      end
      else begin
        state <= 4'd0;
      end
    end
    4'd7: state <= next;
    
    // sprites
    4'd8: begin
      gfx1_addr <= { bank, spr_data[13:8] } * 32 + px[3]*8 + py[3]*8 + { py[3:1], py[0] } + 13'h1000;
      gfx2_addr <= { bank, spr_data[13:8] } * 32 + px[3]*8 + py[3]*8 + { py[3:1], py[0] } + 13'h1000;
      done <= 1'b0;
      hh <= spr_data[31:24] + (spr_data[14] ? 15 - px : px);
      vv <= 240 - spr_data[7:0] + (spr_data[15] ? 15 - py : py);
      next <= 4'd9;
      state <= 4'd7;
    end
    4'd9: begin
      done <= 1'b0;
      color_index[5:2] <= spr_data[19:16];// pxdt3 | pxdt4 ? spr_data[19:16] : 4'd0;
      color_index[1:0] <= { pxdt3, pxdt4 };
      next <= 4'd10;
      state <= 4'd7;
    end
    4'd10: begin
      if (|color_data) begin
        r <= color_data[2:0];
        g <= color_data[5:3];
        b <= color_data[7:6];
        done <= 1'b1;
      end
      state <= 4'd8;
      px <= px + 4'd1;
      if (px == 4'd15) py <= py + 4'd1;
      if (px == 4'd15 && py == 4'd15) begin
        spr_addr <= spr_addr - 1;
        next <= 4'd8;
        state <= 4'd7;
        if (spr_addr == 0) begin
          state <= 4'd0;
          vv <= 8'd0;
          hh <= 8'd0;
          frame <= 1'b1;
        end
      end
    end
    
  endcase
end

endmodule
