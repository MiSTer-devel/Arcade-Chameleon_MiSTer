
module top(
  input reset,
  input clk_sys, // 42

  input [7:0] j1,
  input [7:0] j2,
  input [7:0] p1,
  input [7:0] p2,
  
  input ioctl_index,
  input ioctl_download,
  input [25:0] ioctl_addr,
  input [15:0] ioctl_dout,
  input ioctl_wr

);

/******** VID SYNC ********/

wire clk_vid;
clk_en #(3) clk_en_main(clk_sys, clk_vid);

wire vs;
video video(
  .clk ( clk_vid ),
  .hs  (         ),
  .vs  ( vs      ),
  .hb  (         ),
  .vb  (         )
);

/******** VRAM BUFFER ********/

wire [7:0] hh, vv;
wire [2:0] red, green;
wire [1:0] blue;
wire color_ready, frame;

reg [7:0] vram[256*256*2:0];
reg [16:0] vram_layer;

always @(posedge frame)
  if (vram_layer == 17'd0)
    vram_layer <= 256*256;
  else
    vram_layer <= 0;


always @(posedge clk_sys)
  if (color_ready) vram[vram_layer+vv*256+hh] <= { red, green, blue };

/******** AUDIO MIX ********/

wire signed [10:0] sound1;
wire signed [10:0] sound1;
wire signed [15:0] mix = sound1 + sound2;

/******** CORE ********/

core u_core(
  .reset          ( reset          ),
  .clk_sys        ( clk_sys        ),
  .j1             ( j1             ),
  .j2             ( j2             ),
  .p1             ( p1             ),
  .p2             ( p2             ),
  .ioctl_index    ( ioctl_index    ),
  .ioctl_download ( ioctl_download ),
  .ioctl_addr     ( ioctl_addr     ),
  .ioctl_dout     ( ioctl_dout     ),
  .ioctl_wr       ( ioctl_wr       ),
  .hh             ( hh             ),
  .vv             ( vv             ),
  .red            ( red            ),
  .green          ( green          ),
  .blue           ( blue           ),
  .color_ready    ( color_ready    ),
  .frame          ( frame          ),
  .vs             ( vs             ),
  .sound1         ( sound1         ),
  .sound2         ( sound2         )
);



endmodule

