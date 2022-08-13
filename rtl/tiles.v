
module tiles(
  input clk,
  input [7:0] hh,
  input [7:0] vv,
  output reg [11:0] ram_addr,
  input [7:0] ram_data,
  output reg [13:0] tile_addr,
  input [7:0] tile_data,
  output reg [5:0] color_index,
  input [7:0] color_data,
  
  output [7:0] r, g, b,
  output reg done
);

reg [3:0] next;
reg [3:0] state;
reg [7:0] oldhh;
wire pxdt = tile_data[7-hh[2:0]+:1];

always @(posedge clk) begin
  oldhh <= hh;
  case (state)
    4'd0: begin
      ram_addr <= { 2'b01, vv[7:3], hh[7:3] };
      done <= 1'b1;
      if (oldhh ^ hh) begin
        next <= 4'd1;
        state <= 4'd7;
        done <= 1'b0;
      end
    end
    4'd1: begin
      ram_addr <={ 2'b10, vv[7:3], hh[7:3] };
      tile_addr <= { ram_data, vv[2:0] };
      next <= 4'd2;
      state <= 4'd7;
    end
    4'd2: begin
      color_index[5:2] <= ram_data[3:0];
      color_index[1] <= pxdt;
      tile_addr <= tile_addr + 14'h2000;
      next <= 4'd3;
      state <= 4'd7;
    end
    4'd3: begin
      color_index <= {
        pxdt | color_index[1] ? color_index[5:2] : 4'd0,
        color_index[1], pxdt
      };
      next <= 4'd4;
      state <= 4'd7;
    end
    4'd4: begin
      r <= { color_data[2:0], 5'b0 };
      g <= { color_data[5:3], 5'b0 };
      b <= { color_data[7:6], 6'b0 };
      state <= 4'd0;
    end
    4'd7: state <= next;
  endcase
end

endmodule
