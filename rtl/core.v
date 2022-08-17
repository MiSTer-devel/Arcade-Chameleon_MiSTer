
module core(
  input reset,
  input clk_sys,

  input [7:0] j1,
  input [7:0] j2,
  input [7:0] p1,
  input [7:0] p2,

  input [7:0]  ioctl_index,
  input        ioctl_download,
  input [26:0] ioctl_addr,
  input [15:0] ioctl_dout,
  input        ioctl_wr,

  output [7:0] hh,
  output [7:0] vv,
  output [2:0] red,
  output [2:0] green,
  output [1:0] blue,
  output       color_ready,
  output       frame,

  output signed [10:0] sound1,
  output signed [10:0] sound2,

  input vs
);

/******** CLOCKS ********/

// AUDIO CPU: 0.6MHz from MAME, too slow comparing to the original game
// MAIN CPU: 0.7MHz, good
// SN89: 2MHz, not sure
wire clk_en_6, clk_en_7, clk_en_2;
clk_en #(56) mcpu_clk_en(clk_sys, clk_en_7);
clk_en #(69) acpu_clk_en(clk_sys, clk_en_6);
clk_en #(20) sn89_clk_en(clk_sys, clk_en_2);

/******** MCPU ********/

reg   [7:0] mcpu_din;
reg         mcpu_nmi_n;
wire [15:0] mcpu_addr;
wire  [7:0] mcpu_dout;
wire        mcpu_rw_n;
wire        mcpu_irq_n = vs;

t65 MCPU(
  .Mode    ( 1'b0       ),
  .Res_n   ( ~reset     ),
  .Enable  ( clk_en_7   ),
  .Clk     ( clk_sys    ),
  .Rdy     ( 1'b1       ),
  .Abort_n ( 1'b1       ),
  .IRQ_n   ( mcpu_irq_n ),
  .NMI_n   ( mcpu_nmi_n ),
  .R_W_n   ( mcpu_rw_n  ),
  .A       ( mcpu_addr  ),
  .DI      ( mcpu_din   ),
  .DO      ( mcpu_dout  )
);

/******** MCPU MEMORY CS ********/

wire       mcpu_ram_en = ~|mcpu_addr[15:12];
wire       mcpu_ioa    = ~|mcpu_addr[15:13] & mcpu_addr[12];
wire       mcpu_spr    = mcpu_ioa & ~mcpu_addr[11];
wire       mcpu_io     = mcpu_ioa & mcpu_addr[11];
wire [2:0] mcpu_reg    = mcpu_addr[2:0];
wire       mcpu_rom_en = |mcpu_addr[15:12];

/******** MCPU MEMORIES ********/

wire  [7:0] mcpu_ram_q;
wire  [7:0] mcpu_spr_q;
wire  [7:0] mcpu_rom_q;
wire  [7:0] mcpu_ram_qb;
wire [31:0] mcpu_spr_qb;

wire [11:0] gfx_ram_addr;
wire  [4:0] gfx_spr_addr;

dpram #(12,8) mcpu_ram(
  .clock     ( clk_sys                  ),
  .address_a ( mcpu_addr[11:0]          ),
  .data_a    ( mcpu_dout                ),
  .q_a       ( mcpu_ram_q               ),
  .wren_a    ( ~mcpu_rw_n & mcpu_ram_en ),
  .rden_a    ( mcpu_rw_n & mcpu_ram_en  ),
  .address_b ( gfx_ram_addr             ),
  .q_b       ( mcpu_ram_qb              ),
  .rden_b    ( 1'b1                     )
);

spram mcpu_spr_ram(
  .clock     ( clk_sys               ),
  .address_a ( mcpu_addr[6:0]        ),
  .data_a    ( mcpu_dout             ),
  .q_a       ( mcpu_spr_q            ),
  .wren_a    ( ~mcpu_rw_n & mcpu_spr ),
  .rden_a    ( mcpu_rw_n & mcpu_spr  ),
  .address_b ( gfx_spr_addr          ),
  .q_b       ( mcpu_spr_qb           )
);

wire bt14 = mcpu_addr[14] & ~mcpu_addr[15];
wire  [7:0] mcpu_rom_data  = ioctl_dout;
wire [15:0] mcpu_rom_addr  = ioctl_download ? ioctl_addr + 27'h4000 : { mcpu_addr[15], bt14, mcpu_addr[13:0] };
wire        mcu_rom_wren_a = ioctl_download && ioctl_addr < 27'h8000 ? ioctl_wr : 1'b0;

dpram #(16,8) mcpu_rom(
  .clock     ( clk_sys                 ),
  .address_a ( mcpu_rom_addr           ),
  .data_a    ( mcpu_rom_data           ),
  .q_a       ( mcpu_rom_q              ),
  .rden_a    ( mcpu_rw_n & mcpu_rom_en ),
  .wren_a    ( mcu_rom_wren_a          )
);

/******** MCPU I/O ********/

reg bank;
reg h_flip;
reg v_flip;

reg [7:0] bgc;
reg [7:0] io_data;
reg [7:0] old_p2;
reg [7:0] snd_latch;

// generate a NMI on coin insertion & start buttons
// p2[7:6]=start A/B, p2[5:4]=coin A/B
// Is NMI only triggered on coin insertion?
reg [3:0] hold_nmi;
always @(posedge clk_sys) begin
  old_p2 <= p2;
  if (p2[7:4] != old_p2[7:4]) begin
    mcpu_nmi_n <= 1'b0;
    hold_nmi <= 4'd15;
  end
  if (~mcpu_nmi_n) hold_nmi <= hold_nmi - 4'd1;
  if (~|hold_nmi & ~mcpu_nmi_n) mcpu_nmi_n <= 1'b1;
end

always @(posedge clk_sys) begin
  if (mcpu_io) begin
    case (mcpu_reg)
      3'd0: snd_latch <= mcpu_dout;
      3'd1: bgc <= mcpu_dout;
      3'd2: begin
        h_flip <= mcpu_dout[0];
        v_flip <= mcpu_dout[1];
        bank   <= mcpu_dout[2];
      end
      3'd3: /*???*/;
      3'd4: io_data <= j1;
      3'd5: io_data <= j2;
      3'd6: io_data <= p1;
      3'd7: io_data <= p2;
    endcase
  end
end

/******** MCPU DATA BUS ********/

always @(posedge clk_sys)
  if (mcpu_rw_n)
    mcpu_din <=
      mcpu_io     ? io_data    :
      mcpu_ram_en ? mcpu_ram_q :
      mcpu_rom_en ? mcpu_rom_q : 8'd0;

/******** ACPU ********/

wire [15:0] acpu_addr;
reg   [7:0] acpu_din;
wire  [7:0] acpu_dout;
reg         acpu_irq_n;
wire        acpu_nmi_n = 1'b1;
reg   [7:0] old_snd_latch;
wire        acpu_rw_n;

reg [1:0] hold_irq;
always @(posedge clk_en_6) begin
  old_snd_latch <= snd_latch;
  if (hold_irq != 2'd0) begin
    hold_irq <= hold_irq - 2'b1;
  end
  else begin
    acpu_irq_n <= 1'b1;
  end
  if (snd_latch != old_snd_latch) begin
    acpu_irq_n <= 1'b0;
    hold_irq <= hold_irq - 2'b1;
  end
end

t65 ACPU(
  .Mode    ( 1'b0       ),
  .Res_n   ( ~reset     ),
  .Enable  ( clk_en_6   ),
  .Clk     ( clk_sys    ),
  .Rdy     ( 1'b1       ),
  .Abort_n ( 1'b1       ),
  .IRQ_n   ( acpu_irq_n ),
  .NMI_n   ( acpu_nmi_n ),
  .R_W_n   ( acpu_rw_n  ),
  .A       ( acpu_addr  ),
  .DI      ( acpu_din   ),
  .DO      ( acpu_dout  )
);

/******** ACPU MEMORY CS ********/

wire       acpu_ram_en  = ~|acpu_addr[15:9];
wire       acpu_io      = acpu_addr[15:12] == 4'b1011;
wire       acpu_rom_en  = ~acpu_io & |acpu_addr[15:12];
wire [1:0] acpu_rom_sel = acpu_addr[13:12];
wire [2:0] acpu_reg     = acpu_addr[2:0];

/******** ACPU MEMORIES ********/

wire  [7:0] acpu_rom1_data = ioctl_dout;
wire  [7:0] acpu_rom2_data = ioctl_dout;
wire  [7:0] acpu_rom3_data = ioctl_dout;

wire [11:0] acpu_rom1_addr = ioctl_download ? ioctl_addr - 27'h8000 : acpu_addr[11:0];
wire [11:0] acpu_rom2_addr = ioctl_download ? ioctl_addr - 27'h9000 : acpu_addr[11:0];
wire [11:0] acpu_rom3_addr = ioctl_download ? ioctl_addr - 27'ha000 : acpu_addr[11:0];

wire acpu_rom1_wren_a = ioctl_download && ioctl_addr >= 27'h8000 && ioctl_addr < 27'h9000 ? ioctl_wr : 1'b0;
wire acpu_rom2_wren_a = ioctl_download && ioctl_addr >= 27'h9000 && ioctl_addr < 27'ha000 ? ioctl_wr : 1'b0;
wire acpu_rom3_wren_a = ioctl_download && ioctl_addr >= 27'ha000 && ioctl_addr < 27'hb000 ? ioctl_wr : 1'b0;

wire acpu_rom1_en = acpu_rw_n & acpu_rom_en & acpu_rom_sel == 2'd1;
wire acpu_rom2_en = acpu_rw_n & acpu_rom_en & acpu_rom_sel == 2'd2;
wire acpu_rom3_en = acpu_rw_n & acpu_rom_en & acpu_rom_sel == 2'd3;

wire [7:0] acpu_ram_q;
wire [7:0] acpu_rom1_q;
wire [7:0] acpu_rom2_q;
wire [7:0] acpu_rom3_q;

dpram #(9,8) acpu_ram(
  .clock     ( clk_sys                  ),
  .address_a ( acpu_addr[8:0]           ),
  .data_a    ( acpu_dout                ),
  .q_a       ( acpu_ram_q               ),
  .rden_a    ( acpu_rw_n & acpu_ram_en  ),
  .wren_a    ( ~acpu_rw_n & acpu_ram_en )
);

dpram #(12,8) acpu_rom1(
  .clock     ( clk_sys          ),
  .address_a ( acpu_rom1_addr   ),
  .data_a    ( acpu_rom1_data   ),
  .q_a       ( acpu_rom1_q      ),
  .rden_a    ( acpu_rom1_en     ),
  .wren_a    ( acpu_rom1_wren_a )
);

dpram #(12,8) acpu_rom2(
  .clock     ( clk_sys          ),
  .address_a ( acpu_rom2_addr   ),
  .data_a    ( acpu_rom2_data   ),
  .q_a       ( acpu_rom2_q      ),
  .rden_a    ( acpu_rom2_en     ),
  .wren_a    ( acpu_rom2_wren_a )
);

dpram #(12,8) acpu_rom3(
  .clock     ( clk_sys          ),
  .address_a ( acpu_rom3_addr   ),
  .data_a    ( acpu_rom3_data   ),
  .q_a       ( acpu_rom3_q      ),
  .rden_a    ( acpu_rom3_en     ),
  .wren_a    ( acpu_rom3_wren_a )
);


/******** ACPU I/O ********/

reg  [7:0] acpu_io_data;
reg  [7:0] sn89_data;
reg  [1:0] sn89_sel;
wire [1:0] snd_status;

always @(posedge clk_sys) begin
  if (acpu_io) begin
    case (acpu_reg)
      3'd0: if (~acpu_rw_n)
        sn89_data <= {
          acpu_dout[0],
          acpu_dout[1],
          acpu_dout[2],
          acpu_dout[3],
          acpu_dout[4],
          acpu_dout[5],
          acpu_dout[6],
          acpu_dout[7]
        };
      3'd1: if (~acpu_rw_n) sn89_sel <= acpu_dout[1:0];
      3'd4: acpu_io_data <= snd_status;
      3'd5: acpu_io_data <= snd_latch;
    endcase
  end
end

/******** JT89 (SN76489) ********/

wire sn89_1_rdy, sn89_2_rdy;
assign snd_status = { sn89_1_rdy, sn89_2_rdy };

reg [1:0] old_sn89_sel;
wire jt89_1_wr_n = ~(old_sn89_sel[0] & ~sn89_sel[0]);
wire jt89_2_wr_n = ~(old_sn89_sel[1] & ~sn89_sel[1]);

always @(posedge clk_sys)
  old_sn89_sel <= sn89_sel;

jt89 jt89_1(
  .clk    ( clk_sys     ),
  .clk_en ( clk_en_2    ),
  .rst    ( reset       ),
  .wr_n   ( jt89_1_wr_n ),
  .din    ( sn89_data   ),
  .sound  ( sound1      ),
  .ready  ( sn89_1_rdy  )
);

jt89 jt89_2(
  .clk    ( clk_sys     ),
  .clk_en ( clk_en_2    ),
  .rst    ( reset       ),
  .wr_n   ( jt89_2_wr_n ),
  .din    ( sn89_data   ),
  .sound  ( sound2      ),
  .ready  ( sn89_2_rdy  )
);


/******** ACPU DATA BUS ********/

always @(posedge clk_sys)
  if (acpu_rw_n)
    acpu_din <=
      acpu_io      ? acpu_io_data :
      acpu_ram_en  ? acpu_ram_q   :
      acpu_rom1_en ? acpu_rom1_q  :
      acpu_rom2_en ? acpu_rom2_q  :
      acpu_rom3_en ? acpu_rom3_q  : 8'd0;


/********* GFX ********/

wire [12:0] gfx1_addr;
wire [12:0] gfx2_addr;
wire  [5:0] color_index;
wire  [7:0] gfx_rom1_q;
wire  [7:0] gfx_rom2_q;
wire  [7:0] col_rom_q;
wire  [2:0] br, bg;
wire  [1:0] bb;

gfx gfx(
  .clk          ( clk_sys       ),
  .h            ( hh            ),
  .v            ( vv            ),
  .ram_addr     ( gfx_ram_addr  ),
  .ram_data     ( mcpu_ram_qb   ),
  .gfx1_addr    ( gfx1_addr     ),
  .gfx1_data    ( gfx_rom1_q    ),
  .gfx2_addr    ( gfx2_addr     ),
  .gfx2_data    ( gfx_rom2_q    ),
  .spr_addr     ( gfx_spr_addr  ),
  .spr_data     ( mcpu_spr_qb   ),
  .color_index  ( color_index   ),
  .color_data   ( col_rom_q     ),
  .bank         ( bank          ),
  .r            ( br            ),
  .g            ( bg            ),
  .b            ( bb            ),
  .done         ( color_ready   ),
  .frame        ( frame         ),
  .h_flip       ( h_flip        ),
  .v_flip       ( v_flip        )
);

/******** GFX ROMs ********/

wire  [7:0] gfx_rom_data    = ioctl_dout;
wire [12:0] gfx_rom1_addr   = ioctl_download ? ioctl_addr - 27'hb000 : gfx1_addr;
wire [12:0] gfx_rom2_addr   = ioctl_download ? ioctl_addr - 27'hd000 : gfx2_addr;
wire        gfx_rom1_wren_a = ioctl_download && ioctl_addr >= 27'hb000 && ioctl_addr < 27'hd000 ? ioctl_wr : 1'b0;
wire        gfx_rom2_wren_a = ioctl_download && ioctl_addr >= 27'hd000 && ioctl_addr < 27'hf000 ? ioctl_wr : 1'b0;

dpram #(13,8) gfx_rom1(
  .clock     ( clk_sys         ),
  .address_a ( gfx_rom1_addr   ),
  .data_a    ( gfx_rom_data    ),
  .q_a       ( gfx_rom1_q      ),
  .rden_a    ( 1'b1            ),
  .wren_a    ( gfx_rom1_wren_a )
);

dpram #(13,8) gfx_rom2(
  .clock     ( clk_sys         ),
  .address_a ( gfx_rom2_addr   ),
  .data_a    ( gfx_rom_data    ),
  .q_a       ( gfx_rom2_q      ),
  .rden_a    ( 1'b1            ),
  .wren_a    ( gfx_rom2_wren_a )
);

/******** COLOR ROMs ********/

wire [7:0] col_rom_data   = ioctl_dout;
wire [5:0] col_rom_addr_a = ioctl_download ? ioctl_addr - 27'hf000 : color_index;
wire       col_rom_wren_a = ioctl_download && ioctl_addr >= 27'hf000 ? ioctl_wr : 1'b0;

dpram #(6,8) col_rom(
  .clock     ( clk_sys        ),
  .address_a ( col_rom_addr_a ),
  .data_a    ( col_rom_data   ),
  .q_a       ( col_rom_q      ),
  .rden_a    ( 1'b1           ),
  .wren_a    ( col_rom_wren_a )
);

/******** COLOR MIX ********/

assign red   = |br ? br : bgc[2:0];
assign green = |bg ? bg : bgc[5:3];
assign blue  = |bb ? bb : bgc[7:6];


endmodule
