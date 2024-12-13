module vga_driver_memory_2	(
    	//////////// ADC //////////
	//output		          		ADC_CONVST,
	//output		          		ADC_DIN,
	//input 		          		ADC_DOUT,
	//output		          		ADC_SCLK,

	//////////// Audio //////////
	//input 		          		AUD_ADCDAT,
	//inout 		          		AUD_ADCLRCK,
	//inout 		          		AUD_BCLK,
	//output		          		AUD_DACDAT,
	//inout 		          		AUD_DACLRCK,
	//output		          		AUD_XCK,

	//////////// CLOCK //////////
	//input 		          		CLOCK2_50,
	//input 		          		CLOCK3_50,
	//input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// SDRAM //////////
	//output		    [12:0]		DRAM_ADDR,
	//output		     [1:0]		DRAM_BA,
	//output		          		DRAM_CAS_N,
	//output		          		DRAM_CKE,
	//output		          		DRAM_CLK,
	//output		          		DRAM_CS_N,
	//inout 		    [15:0]		DRAM_DQ,
	//output		          		DRAM_LDQM,
	//output		          		DRAM_RAS_N,
	//output		          		DRAM_UDQM,
	//output		          		DRAM_WE_N,

	//////////// I2C for Audio and Video-In //////////
	//output		          		FPGA_I2C_SCLK,
	//inout 		          		FPGA_I2C_SDAT,

	//////////// SEG7 //////////
	output		     [6:0]		HEX0,

	//output		     [6:0]		HEX4,
	//output		     [6:0]		HEX5,

	//////////// IR //////////
	//input 		          		IRDA_RXD,
	//output		          		IRDA_TXD,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// LED //////////

	//////////// PS2 //////////
	//inout 		          		PS2_CLK,
	//inout 		          		PS2_CLK2,
	//inout 		          		PS2_DAT,
	//inout 		          		PS2_DAT2,

	//////////// SW //////////
	input 		     [3:0]		SW,

	//////////// Video-In //////////
	//input 		          		TD_CLK27,
	//input 		     [7:0]		TD_DATA,
	//input 		          		TD_HS,
	//output		          		TD_RESET_N,
	//input 		          		TD_VS,

	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output reg	     [7:0]		VGA_B,
	output		          		VGA_CLK,
	output reg	     [7:0]		VGA_G,
	output		          		VGA_HS,
	output reg	     [7:0]		VGA_R,
	output		          		VGA_SYNC_N,
	output		          		VGA_VS

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	//inout 		    [35:0]		GPIO_0,

	//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
	//inout 		    [35:0]		GPIO_1


);



  // Turn off all displays.

// DONE STANDARD PORT DECLARATION ABOVE

/* HANDLE SIGNALS FOR CIRCUIT */
wire clk;
wire rst;

assign clk = CLOCK_50;
assign rst = KEY[0];

wire [17:0]SW_db;


wire [31:0]radians;
wire [31:0]pos;										
wire [15:0]pospos	= pos[31:16];	


pendulum_problem pen_inst(
.CLOCK_50(CLOCK_50),
.SW(SW), 
.KEY(KEY[3:1]),
.stan(pos),
.theta(radians)
);


seven_segment johns_sev(
.i(SW),
.o(HEX0)
);




/* -------------------------------- */

/* DEBUG SIGNALS */
//assign LEDR[0] = active_pixels;

/* -------------------------------- */
// VGA DRIVER
wire active_pixels; // is on when we're in the active draw space
wire frame_done;

wire [9:0]x; // current x
wire [9:0]y; // current y - 10 bits = 1024 ... a little bit more than we need

vga_driver the_vga(
.clk(clk),
.rst(rst),

.vga_clk(VGA_CLK),

.hsync(VGA_HS),
.vsync(VGA_VS),

.active_pixels(active_pixels),
.frame_done(frame_done),

.xPixel(x),
.yPixel(y),

.VGA_BLANK_N(VGA_BLANK_N),
.VGA_SYNC_N(VGA_SYNC_N)
);

/* -------------------------------- */
/* MEMORY to STORE a MINI frambuffer.  Problem is the FPGA's on-chip memory can't hold an entire frame, so some
form of compression is needed.  I show a simple compress the image to 16 pixels or a 4 by 4, but this memory
could handle more */
reg [14:0] frame_buf_mem_address;
reg [23:0] frame_buf_mem_data;
reg frame_buf_mem_wren;
wire [23:0]frame_buf_mem_q;

/* This memory is 
vga_frame vga_memory(
	frame_buf_mem_address,
	clk,
	frame_buf_mem_data,
	frame_buf_mem_wren,
	frame_buf_mem_q);



/* -------------------------------- */
/* 	FSM to control the writing to the framebuffer and the reading of it.
	I make a 4x4 pixel map in memory.  Then as I read this info I display it 
	noting that the VGA draws in rows, so I have to make sure the right data
	is loaded.  Note, that some of these parameters can be increased. */
reg [15:0]i;
reg [7:0]S;
reg [7:0]NS;
parameter 
	START = 8'd0,
	W2M_INIT = 8'd1, // Write 2 Memory init - this is a FOR loop
	W2M_COND = 8'd2, // Write 2 Memory condion
	W2M_INC = 8'd3, // Write 2 Memory incrementer
	RFM_INIT = 8'd4, // Read From Memory init
	RFM_DRAWING = 8'd5, // Read From Memory draw step
	ERROR = 8'hFF;

parameter LOOP_SIZE = 16'd16;
parameter LOOP_I_SIZE = 16'd4;
parameter WIDTH = 16'd640;
parameter HEIGHT = 16'd480;
parameter PIXELS_IN_WIDTH = WIDTH/LOOP_I_SIZE; // 160
parameter PIXELS_IN_HEIGHT = HEIGHT/LOOP_I_SIZE; // 120

/* Calculate NS */
always @(*)
	case (S)
		START: NS = W2M_INIT;
		W2M_INIT: NS = W2M_COND;
		W2M_COND:
			if (i < LOOP_SIZE)
				NS = W2M_INC;
			else
				NS = RFM_INIT;
		W2M_INC: NS = W2M_COND;
		RFM_INIT: 
			if (frame_done == 1'b0)
				NS = RFM_DRAWING;
			else	
				NS = RFM_INIT;
		RFM_DRAWING:
			if (frame_done == 1'b1)
				NS = RFM_INIT;
			else
				NS = RFM_DRAWING;
		default:	NS = ERROR;
	endcase

	
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
			S <= START;
	end
	else
	begin
			S <= NS;
	end
end

/* 
The code goes through a write phase (after reset) and an endless read phase once writing is done.

The W2M (write to memory) code is roughly:
for (i = 0; i < 16; i++)
	mem[i] = color // where color is a shade of FF/16 * i if switch is on SW[2:0] for {R, G, B}

The RFM (read from memory) is synced with the VGA display which goes row by row
for (i = 0; i < 480; i++) // height
	for (j = 0; j < 640; j++) // width
		color = mem[(i/120 * 4) + j/160] OR just use x, y coming from vga_driver
		
I later simplified and just used the x and y coming from the vga_driver and used it to calculate the memory load.
		
*/

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		frame_buf_mem_address <= 14'd0;
		frame_buf_mem_data <= 24'd0;
		frame_buf_mem_wren <= 1'd0;
		i <= 16'd0;
	end
	else
	begin
		case (S)
			START:
			begin
				frame_buf_mem_address <= 14'd0;
				frame_buf_mem_data <= 24'd0;
				frame_buf_mem_wren <= 1'd0;
				i <= 16'd0;
			end
			W2M_INIT:
			begin
				frame_buf_mem_address <= 14'd0;
				frame_buf_mem_data <= 24'd0;
				frame_buf_mem_wren <= 1'd1;
				i <= 16'd0;
			end
			W2M_COND:
			begin
			end
			W2M_INC: 
			begin
				i <= i + 1'b1;
				frame_buf_mem_address <= frame_buf_mem_address + 1'b1;
				frame_buf_mem_data <= {red, green, blue}; // done in the combinational part below
			end
			RFM_INIT: 
			begin
				frame_buf_mem_wren <= 1'd0; // turn off writing to memory
				// y and x come from the vga_driver module as it progresses through the drawing of the page
				if (y < HEIGHT && x < WIDTH)
					frame_buf_mem_address <= (y/PIXELS_IN_HEIGHT) * LOOP_I_SIZE + (x/PIXELS_IN_WIDTH);
			end
			RFM_DRAWING:
			begin
				// y and x come from the vga_driver module as it progresses through the drawing of the page
				if (y < HEIGHT && x < WIDTH)
					frame_buf_mem_address <= (y/PIXELS_IN_HEIGHT) * LOOP_I_SIZE + (x/PIXELS_IN_WIDTH);
			end	
		endcase
	end
end

reg [7:0]red;
reg [7:0]green;
reg [7:0]blue;

										
								
										
										
reg [15:0] p151;
reg [63:0] pp151;
reg [15:0] p152;
reg [63:0] pp152;
reg [15:0] p153;
reg [63:0] pp153;
reg [15:0] p154;
reg [63:0] pp154;
reg [15:0] p155;
reg [63:0] pp155;
reg [15:0] p156;
reg [63:0] pp156;
reg [15:0] p157;
reg [63:0] pp157;
reg [15:0] p158;
reg [63:0] pp158;
reg [15:0] p159;
reg [63:0] pp159;
reg [15:0] p160;
reg [63:0] pp160;
reg [15:0] p161;
reg [63:0] pp161;
reg [15:0] p162;
reg [63:0] pp162;
reg [15:0] p163;
reg [63:0] pp163;
reg [15:0] p164;
reg [63:0] pp164;
reg [15:0] p165;
reg [63:0] pp165;
reg [15:0] p166;
reg [63:0] pp166;
reg [15:0] p167;
reg [63:0] pp167;
reg [15:0] p168;
reg [63:0] pp168;
reg [15:0] p169;
reg [63:0] pp169;
reg [15:0] p170;
reg [63:0] pp170;
reg [15:0] p171;
reg [63:0] pp171;
reg [15:0] p172;
reg [63:0] pp172;
reg [15:0] p173;
reg [63:0] pp173;
reg [15:0] p174;
reg [63:0] pp174;
reg [15:0] p175;
reg [63:0] pp175;
reg [15:0] p176;
reg [63:0] pp176;
reg [15:0] p177;
reg [63:0] pp177;
reg [15:0] p178;
reg [63:0] pp178;
reg [15:0] p179;
reg [63:0] pp179;
reg [15:0] p180;
reg [63:0] pp180;
reg [15:0] p181;
reg [63:0] pp181;
reg [15:0] p182;
reg [63:0] pp182;
reg [15:0] p183;
reg [63:0] pp183;
reg [15:0] p184;
reg [63:0] pp184;
reg [15:0] p185;
reg [63:0] pp185;
reg [15:0] p186;
reg [63:0] pp186;
reg [15:0] p187;
reg [63:0] pp187;
reg [15:0] p188;
reg [63:0] pp188;
reg [15:0] p189;
reg [63:0] pp189;
reg [15:0] p190;
reg [63:0] pp190;
reg [15:0] p191;
reg [63:0] pp191;
reg [15:0] p192;
reg [63:0] pp192;
reg [15:0] p193;
reg [63:0] pp193;
reg [15:0] p194;
reg [63:0] pp194;
reg [15:0] p195;
reg [63:0] pp195;
reg [15:0] p196;
reg [63:0] pp196;
reg [15:0] p197;
reg [63:0] pp197;
reg [15:0] p198;
reg [63:0] pp198;
reg [15:0] p199;
reg [63:0] pp199;
reg [15:0] p200;
reg [63:0] pp200;

		
reg [15:0]p150;
reg[63:0]pp150;										
reg [15:0]p149;
reg [63:0]pp149;
reg [15:0]p148;
reg [63:0]pp148;
reg [15:0]p147;
reg [63:0]pp147;
reg [15:0]p146;
reg [63:0]pp146;
reg [15:0]p145;
reg [63:0]pp145;
reg [15:0]p144;
reg [63:0]pp144;
reg [15:0]p143;
reg [63:0]pp143;
reg [15:0]p142;
reg [63:0]pp142;
reg [15:0]p141;
reg [63:0]pp141;
reg [15:0]p140;
reg [63:0]pp140;
reg [15:0]p139;
reg [63:0]pp139;
reg [15:0]p138;
reg [63:0]pp138;
reg [15:0]p137;
reg [63:0]pp137;
reg [15:0]p136;
reg [63:0]pp136;
reg [15:0]p135;
reg [63:0]pp135;
reg [15:0]p134;
reg [63:0]pp134;
reg [15:0]p133;
reg [63:0]pp133;
reg [15:0]p132;
reg [63:0]pp132;
reg [15:0]p131;
reg [63:0]pp131;
reg [15:0]p130;
reg [63:0]pp130;
reg [15:0]p129;
reg [63:0]pp129;
reg [15:0]p128;
reg [63:0]pp128;
reg [15:0]p127;
reg [63:0]pp127;
reg [15:0]p126;
reg [63:0]pp126;
reg [15:0]p125;
reg [63:0]pp125;
reg [15:0]p124;
reg [63:0]pp124;
reg [15:0]p123;
reg [63:0]pp123;
reg [15:0]p122;
reg [63:0]pp122;
reg [15:0]p121;
reg [63:0]pp121;
reg [15:0]p120;
reg [63:0]pp120;
reg [15:0]p119;
reg [63:0]pp119;
reg [15:0]p118;
reg [63:0]pp118;
reg [15:0]p117;
reg [63:0]pp117;
reg [15:0]p116;
reg [63:0]pp116;
reg [15:0]p115;
reg [63:0]pp115;
reg [15:0]p114;
reg [63:0]pp114;
reg [15:0]p113;
reg [63:0]pp113;
reg [15:0]p112;
reg [63:0]pp112;
reg [15:0]p111;
reg [63:0]pp111;
reg [15:0]p110;
reg [63:0]pp110;
reg [15:0]p109;
reg [63:0]pp109;
reg [15:0]p108;
reg [63:0]pp108;
reg [15:0]p107;
reg [63:0]pp107;
reg [15:0]p106;
reg [63:0]pp106;
reg [15:0]p105;
reg [63:0]pp105;
reg [15:0]p104;
reg [63:0]pp104;
reg [15:0]p103;
reg [63:0]pp103;
reg [15:0]p102;
reg [63:0]pp102;
reg [15:0]p101;
reg [63:0]pp101;
reg [15:0]p100;
reg [63:0]pp100;
reg [15:0]p99;
reg [63:0]pp99;
reg [15:0]p98;
reg [63:0]pp98;
reg [15:0]p97;
reg [63:0]pp97;
reg [15:0]p96;
reg [63:0]pp96;
reg [15:0]p95;
reg [63:0]pp95;
reg [15:0]p94;
reg [63:0]pp94;
reg [15:0]p93;
reg [63:0]pp93;
reg [15:0]p92;
reg [63:0]pp92;
reg [15:0]p91;
reg [63:0]pp91;
reg [15:0]p90;
reg [63:0]pp90;
reg [15:0]p89;
reg [63:0]pp89;
reg [15:0]p88;
reg [63:0]pp88;
reg [15:0]p87;
reg [63:0]pp87;
reg [15:0]p86;
reg [63:0]pp86;
reg [15:0]p85;
reg [63:0]pp85;
reg [15:0]p84;
reg [63:0]pp84;
reg [15:0]p83;
reg [63:0]pp83;
reg [15:0]p82;
reg [63:0]pp82;
reg [15:0]p81;
reg [63:0]pp81;
reg [15:0]p80;
reg [63:0]pp80;
reg [15:0]p79;
reg [63:0]pp79;
reg [15:0]p78;
reg [63:0]pp78;
reg [15:0]p77;
reg [63:0]pp77;
reg [15:0]p76;
reg [63:0]pp76;
reg [15:0]p75;
reg [63:0]pp75;
reg [15:0]p74;
reg [63:0]pp74;
reg [15:0]p73;
reg [63:0]pp73;
reg [15:0]p72;
reg [63:0]pp72;
reg [15:0]p71;
reg [63:0]pp71;
reg [15:0]p70;
reg [63:0]pp70;
reg [15:0]p69;
reg [63:0]pp69;
reg [15:0]p68;
reg [63:0]pp68;
reg [15:0]p67;
reg [63:0]pp67;
reg [15:0]p66;
reg [63:0]pp66;
reg [15:0]p65;
reg [63:0]pp65;
reg [15:0]p64;
reg [63:0]pp64;
reg [15:0]p63;
reg [63:0]pp63;
reg [15:0]p62;
reg [63:0]pp62;
reg [15:0]p61;
reg [63:0]pp61;
reg [15:0]p60;
reg [63:0]pp60;
reg [15:0]p59;
reg [63:0]pp59;
reg [15:0]p58;
reg [63:0]pp58;
reg [15:0]p57;
reg [63:0]pp57;
reg [15:0]p56;
reg [63:0]pp56;
reg [15:0]p55;
reg [63:0]pp55;
reg [15:0]p54;
reg [63:0]pp54;
reg [15:0]p53;
reg [63:0]pp53;
reg [15:0]p52;
reg [63:0]pp52;
reg [15:0]p51;
reg [63:0]pp51;
reg [15:0]p50;
reg [63:0]pp50;
reg [15:0]p49;
reg [63:0]pp49;
reg [15:0]p48;
reg [63:0]pp48;
reg [15:0]p47;
reg [63:0]pp47;
reg [15:0]p46;
reg [63:0]pp46;
reg [15:0]p45;
reg [63:0]pp45;
reg [15:0]p44;
reg [63:0]pp44;
reg [15:0]p43;
reg [63:0]pp43;
reg [15:0]p42;
reg [63:0]pp42;
reg [15:0]p41;
reg [63:0]pp41;
reg [15:0]p40;
reg [63:0]pp40;
reg [15:0]p39;
reg [63:0]pp39;
reg [15:0]p38;
reg [63:0]pp38;
reg [15:0]p37;
reg [63:0]pp37;
reg [15:0]p36;
reg [63:0]pp36;
reg [15:0]p35;
reg [63:0]pp35;
reg [15:0]p34;
reg [63:0]pp34;
reg [15:0]p33;
reg [63:0]pp33;
reg [15:0]p32;
reg [63:0]pp32;
reg [15:0]p31;
reg [63:0]pp31;
reg [15:0]p30;
reg [63:0]pp30;
reg [15:0]p29;
reg [63:0]pp29;
reg [15:0]p28;
reg [63:0]pp28;
reg [15:0]p27;
reg [63:0]pp27;
reg [15:0]p26;
reg [63:0]pp26;
reg [15:0]p25;
reg [63:0]pp25;
reg [15:0]p24;
reg [63:0]pp24;
reg [15:0]p23;
reg [63:0]pp23;
reg [15:0]p22;
reg [63:0]pp22;
reg [15:0]p21;
reg [63:0]pp21;
reg [15:0]p20;
reg [63:0]pp20;
reg [15:0]p19;
reg [63:0]pp19;
reg [15:0]p18;
reg [63:0]pp18;
reg [15:0]p17;
reg [63:0]pp17;
reg [15:0]p16;
reg [63:0]pp16;
reg [15:0]p15;
reg [63:0]pp15;
reg [15:0]p14;
reg [63:0]pp14;
reg [15:0]p13;
reg [63:0]pp13;
reg [15:0]p12;
reg [63:0]pp12;
reg [15:0]p11;
reg [63:0]pp11;
reg [15:0]p10;
reg [63:0]pp10;
reg [15:0]p9;
reg [63:0]pp9;
reg [15:0]p8;
reg [63:0]pp8;
reg [15:0]p7;
reg [63:0]pp7;
reg [15:0]p6;
reg [63:0]pp6;
reg [15:0]p5;
reg [63:0]pp5;
reg [15:0]p4;
reg [63:0]pp4;
reg [15:0]p3;
reg [63:0]pp3;
reg [15:0]p2;
reg [63:0]pp2;
reg [15:0]p1;
reg [63:0]pp1;		
reg [15:0]p0;
reg [63:0]pp0;										
										
										
										
always@(*)
begin 
	pp150= (radians * {16'd150,16'b0});
	p150= pp150[47:31];
	 
pp200 = (radians * {16'd200, 16'b0}); 
p200 = pp200[47:31];

pp199 = (radians * {16'd199, 16'b0}); 
p199 = pp199[47:31];

pp198 = (radians * {16'd198, 16'b0}); 
p198 = pp198[47:31];

pp197 = (radians * {16'd197, 16'b0}); 
p197 = pp197[47:31];

pp196 = (radians * {16'd196, 16'b0}); 
p196 = pp196[47:31];

pp195 = (radians * {16'd195, 16'b0}); 
p195 = pp195[47:31];

pp194 = (radians * {16'd194, 16'b0}); 
p194 = pp194[47:31];

pp193 = (radians * {16'd193, 16'b0}); 
p193 = pp193[47:31];

pp192 = (radians * {16'd192, 16'b0}); 
p192 = pp192[47:31];

pp191 = (radians * {16'd191, 16'b0}); 
p191 = pp191[47:31];

pp190 = (radians * {16'd190, 16'b0}); 
p190 = pp190[47:31];

pp189 = (radians * {16'd189, 16'b0}); 
p189 = pp189[47:31];

pp188 = (radians * {16'd188, 16'b0}); 
p188 = pp188[47:31];

pp187 = (radians * {16'd187, 16'b0}); 
p187 = pp187[47:31];

pp186 = (radians * {16'd186, 16'b0}); 
p186 = pp186[47:31];

pp185 = (radians * {16'd185, 16'b0}); 
p185 = pp185[47:31];

pp184 = (radians * {16'd184, 16'b0}); 
p184 = pp184[47:31];

pp183 = (radians * {16'd183, 16'b0}); 
p183 = pp183[47:31];

pp182 = (radians * {16'd182, 16'b0}); 
p182 = pp182[47:31];

pp181 = (radians * {16'd181, 16'b0}); 
p181 = pp181[47:31];

pp180 = (radians * {16'd180, 16'b0}); 
p180 = pp180[47:31];

pp179 = (radians * {16'd179, 16'b0}); 
p179 = pp179[47:31];

pp178 = (radians * {16'd178, 16'b0}); 
p178 = pp178[47:31];

pp177 = (radians * {16'd177, 16'b0}); 
p177 = pp177[47:31];

pp176 = (radians * {16'd176, 16'b0}); 
p176 = pp176[47:31];

pp175 = (radians * {16'd175, 16'b0}); 
p175 = pp175[47:31];

pp174 = (radians * {16'd174, 16'b0}); 
p174 = pp174[47:31];

pp173 = (radians * {16'd173, 16'b0}); 
p173 = pp173[47:31];

pp172 = (radians * {16'd172, 16'b0}); 
p172 = pp172[47:31];

pp171 = (radians * {16'd171, 16'b0}); 
p171 = pp171[47:31];

pp170 = (radians * {16'd170, 16'b0}); 
p170 = pp170[47:31];

pp169 = (radians * {16'd169, 16'b0}); 
p169 = pp169[47:31];

pp168 = (radians * {16'd168, 16'b0}); 
p168 = pp168[47:31];

pp167 = (radians * {16'd167, 16'b0}); 
p167 = pp167[47:31];

pp166 = (radians * {16'd166, 16'b0}); 
p166 = pp166[47:31];

pp165 = (radians * {16'd165, 16'b0}); 
p165 = pp165[47:31];

pp164 = (radians * {16'd164, 16'b0}); 
p164 = pp164[47:31];

pp163 = (radians * {16'd163, 16'b0}); 
p163 = pp163[47:31];

pp162 = (radians * {16'd162, 16'b0}); 
p162 = pp162[47:31];

pp161 = (radians * {16'd161, 16'b0}); 
p161 = pp161[47:31];

pp160 = (radians * {16'd160, 16'b0}); 
p160 = pp160[47:31];

pp159 = (radians * {16'd159, 16'b0}); 
p159 = pp159[47:31];

pp158 = (radians * {16'd158, 16'b0}); 
p158 = pp158[47:31];

pp157 = (radians * {16'd157, 16'b0}); 
p157 = pp157[47:31];

pp156 = (radians * {16'd156, 16'b0}); 
p156 = pp156[47:31];

pp155 = (radians * {16'd155, 16'b0}); 
p155 = pp155[47:31];

pp154 = (radians * {16'd154, 16'b0}); 
p154 = pp154[47:31];

pp153 = (radians * {16'd153, 16'b0}); 
p153 = pp153[47:31];

pp152 = (radians * {16'd152, 16'b0}); 
p152 = pp152[47:31];

pp151 = (radians * {16'd151, 16'b0}); 
p151 = pp151[47:31];

pp150 = (radians * {16'd150, 16'b0}); 
p150 = pp150[47:31];

pp149 = (radians * {16'd149, 16'b0}); 
p149 = pp149[47:31];

pp148 = (radians * {16'd148, 16'b0}); 
p148 = pp148[47:31];

pp147 = (radians * {16'd147, 16'b0}); 
p147 = pp147[47:31];

pp146 = (radians * {16'd146, 16'b0}); 
p146 = pp146[47:31];

pp145 = (radians * {16'd145, 16'b0}); 
p145 = pp145[47:31];

pp144 = (radians * {16'd144, 16'b0}); 
p144 = pp144[47:31];

pp143 = (radians * {16'd143, 16'b0}); 
p143 = pp143[47:31];

pp142 = (radians * {16'd142, 16'b0}); 
p142 = pp142[47:31];

pp141 = (radians * {16'd141, 16'b0}); 
p141 = pp141[47:31];

pp140 = (radians * {16'd140, 16'b0}); 
p140 = pp140[47:31];

pp139 = (radians * {16'd139, 16'b0}); 
p139 = pp139[47:31];

pp138 = (radians * {16'd138, 16'b0}); 
p138 = pp138[47:31];

pp137 = (radians * {16'd137, 16'b0}); 
p137 = pp137[47:31];

pp136 = (radians * {16'd136, 16'b0}); 
p136 = pp136[47:31];

pp135 = (radians * {16'd135, 16'b0}); 
p135 = pp135[47:31];

pp134 = (radians * {16'd134, 16'b0}); 
p134 = pp134[47:31];

pp133 = (radians * {16'd133, 16'b0}); 
p133 = pp133[47:31];

pp132 = (radians * {16'd132, 16'b0}); 
p132 = pp132[47:31];

pp131 = (radians * {16'd131, 16'b0}); 
p131 = pp131[47:31];

pp130 = (radians * {16'd130, 16'b0}); 
p130 = pp130[47:31];

pp129 = (radians * {16'd129, 16'b0}); 
p129 = pp129[47:31];

pp128 = (radians * {16'd128, 16'b0}); 
p128 = pp128[47:31];

pp127 = (radians * {16'd127, 16'b0}); 
p127 = pp127[47:31];

pp126 = (radians * {16'd126, 16'b0}); 
p126 = pp126[47:31];

pp125 = (radians * {16'd125, 16'b0}); 
p125 = pp125[47:31];

pp124 = (radians * {16'd124, 16'b0}); 
p124 = pp124[47:31];

pp123 = (radians * {16'd123, 16'b0}); 
p123 = pp123[47:31];

pp122 = (radians * {16'd122, 16'b0}); 
p122 = pp122[47:31];

pp121 = (radians * {16'd121, 16'b0}); 
p121 = pp121[47:31];

pp120 = (radians * {16'd120, 16'b0}); 
p120 = pp120[47:31];

pp119 = (radians * {16'd119, 16'b0}); 
p119 = pp119[47:31];

pp118 = (radians * {16'd118, 16'b0}); 
p118 = pp118[47:31];

pp117 = (radians * {16'd117, 16'b0}); 
p117 = pp117[47:31];

pp116 = (radians * {16'd116, 16'b0}); 
p116 = pp116[47:31];

pp115 = (radians * {16'd115, 16'b0}); 
p115 = pp115[47:31];

pp114 = (radians * {16'd114, 16'b0}); 
p114 = pp114[47:31];

pp113 = (radians * {16'd113, 16'b0}); 
p113 = pp113[47:31];

pp112 = (radians * {16'd112, 16'b0}); 
p112 = pp112[47:31];

pp111 = (radians * {16'd111, 16'b0}); 
p111 = pp111[47:31];

pp110 = (radians * {16'd110, 16'b0}); 
p110 = pp110[47:31];

pp109 = (radians * {16'd109, 16'b0}); 
p109 = pp109[47:31];

pp108 = (radians * {16'd108, 16'b0}); 
p108 = pp108[47:31];

pp107 = (radians * {16'd107, 16'b0}); 
p107 = pp107[47:31];

pp106 = (radians * {16'd106, 16'b0}); 
p106 = pp106[47:31];

pp105 = (radians * {16'd105, 16'b0}); 
p105 = pp105[47:31];

pp104 = (radians * {16'd104, 16'b0}); 
p104 = pp104[47:31];

pp103 = (radians * {16'd103, 16'b0}); 
p103 = pp103[47:31];

pp102 = (radians * {16'd102, 16'b0}); 
p102 = pp102[47:31];

pp101 = (radians * {16'd101, 16'b0}); 
p101 = pp101[47:31];

pp100 = (radians * {16'd100, 16'b0}); 
p100 = pp100[47:31];

pp99 = (radians * {16'd99, 16'b0}); 
p99 = pp99[47:31];

pp98 = (radians * {16'd98, 16'b0}); 
p98 = pp98[47:31];

pp97 = (radians * {16'd97, 16'b0}); 
p97 = pp97[47:31];

pp96 = (radians * {16'd96, 16'b0}); 
p96 = pp96[47:31];

pp95 = (radians * {16'd95, 16'b0}); 
p95 = pp95[47:31];

pp94 = (radians * {16'd94, 16'b0}); 
p94 = pp94[47:31];

pp93 = (radians * {16'd93, 16'b0}); 
p93 = pp93[47:31];

pp92 = (radians * {16'd92, 16'b0}); 
p92 = pp92[47:31];

pp91 = (radians * {16'd91, 16'b0}); 
p91 = pp91[47:31];

pp90 = (radians * {16'd90, 16'b0}); 
p90 = pp90[47:31];

pp89 = (radians * {16'd89, 16'b0}); 
p89 = pp89[47:31];

pp88 = (radians * {16'd88, 16'b0}); 
p88 = pp88[47:31];

pp87 = (radians * {16'd87, 16'b0}); 
p87 = pp87[47:31];

pp86 = (radians * {16'd86, 16'b0}); 
p86 = pp86[47:31];

pp85 = (radians * {16'd85, 16'b0}); 
p85 = pp85[47:31];

pp84 = (radians * {16'd84, 16'b0}); 
p84 = pp84[47:31];

pp83 = (radians * {16'd83, 16'b0}); 
p83 = pp83[47:31];

pp82 = (radians * {16'd82, 16'b0}); 
p82 = pp82[47:31];

pp81 = (radians * {16'd81, 16'b0}); 
p81 = pp81[47:31];

pp80 = (radians * {16'd80, 16'b0}); 
p80 = pp80[47:31];

pp79 = (radians * {16'd79, 16'b0}); 
p79 = pp79[47:31];

pp78 = (radians * {16'd78, 16'b0}); 
p78 = pp78[47:31];

pp77 = (radians * {16'd77, 16'b0}); 
p77 = pp77[47:31];

pp76 = (radians * {16'd76, 16'b0}); 
p76 = pp76[47:31];

pp75 = (radians * {16'd75, 16'b0}); 
p75 = pp75[47:31];

pp74 = (radians * {16'd74, 16'b0}); 
p74 = pp74[47:31];

pp73 = (radians * {16'd73, 16'b0}); 
p73 = pp73[47:31];

pp72 = (radians * {16'd72, 16'b0}); 
p72 = pp72[47:31];

pp71 = (radians * {16'd71, 16'b0}); 
p71 = pp71[47:31];

pp70 = (radians * {16'd70, 16'b0}); 
p70 = pp70[47:31];

pp69 = (radians * {16'd69, 16'b0}); 
p69 = pp69[47:31];

pp68 = (radians * {16'd68, 16'b0}); 
p68 = pp68[47:31];

pp67 = (radians * {16'd67, 16'b0}); 
p67 = pp67[47:31];

pp66 = (radians * {16'd66, 16'b0}); 
p66 = pp66[47:31];

pp65 = (radians * {16'd65, 16'b0}); 
p65 = pp65[47:31];

pp64 = (radians * {16'd64, 16'b0}); 
p64 = pp64[47:31];

pp63 = (radians * {16'd63, 16'b0}); 
p63 = pp63[47:31];

pp62 = (radians * {16'd62, 16'b0}); 
p62 = pp62[47:31];

pp61 = (radians * {16'd61, 16'b0}); 
p61 = pp61[47:31];

pp60 = (radians * {16'd60, 16'b0}); 
p60 = pp60[47:31];

pp59 = (radians * {16'd59, 16'b0}); 
p59 = pp59[47:31];

pp58 = (radians * {16'd58, 16'b0}); 
p58 = pp58[47:31];

pp57 = (radians * {16'd57, 16'b0}); 
p57 = pp57[47:31];

pp56 = (radians * {16'd56, 16'b0}); 
p56 = pp56[47:31];

pp55 = (radians * {16'd55, 16'b0}); 
p55 = pp55[47:31];

pp54 = (radians * {16'd54, 16'b0}); 
p54 = pp54[47:31];

pp53 = (radians * {16'd53, 16'b0}); 
p53 = pp53[47:31];

pp52 = (radians * {16'd52, 16'b0}); 
p52 = pp52[47:31];

pp51 = (radians * {16'd51, 16'b0}); 
p51 = pp51[47:31];

pp50 = (radians * {16'd50, 16'b0}); 
p50 = pp50[47:31];

pp49 = (radians * {16'd49, 16'b0}); 
p49 = pp49[47:31];

pp48 = (radians * {16'd48, 16'b0}); 
p48 = pp48[47:31];

pp47 = (radians * {16'd47, 16'b0}); 
p47 = pp47[47:31];

pp46 = (radians * {16'd46, 16'b0}); 
p46 = pp46[47:31];

pp45 = (radians * {16'd45, 16'b0}); 
p45 = pp45[47:31];

pp44 = (radians * {16'd44, 16'b0}); 
p44 = pp44[47:31];

pp43 = (radians * {16'd43, 16'b0}); 
p43 = pp43[47:31];

pp42 = (radians * {16'd42, 16'b0}); 
p42 = pp42[47:31];

pp41 = (radians * {16'd41, 16'b0}); 
p41 = pp41[47:31];

pp40 = (radians * {16'd40, 16'b0}); 
p40 = pp40[47:31];

pp39 = (radians * {16'd39, 16'b0}); 
p39 = pp39[47:31];

pp38 = (radians * {16'd38, 16'b0}); 
p38 = pp38[47:31];

pp37 = (radians * {16'd37, 16'b0}); 
p37 = pp37[47:31];

pp36 = (radians * {16'd36, 16'b0}); 
p36 = pp36[47:31];

pp35 = (radians * {16'd35, 16'b0}); 
p35 = pp35[47:31];

pp34 = (radians * {16'd34, 16'b0}); 
p34 = pp34[47:31];

pp33 = (radians * {16'd33, 16'b0}); 
p33 = pp33[47:31];

pp32 = (radians * {16'd32, 16'b0}); 
p32 = pp32[47:31];

pp31 = (radians * {16'd31, 16'b0}); 
p31 = pp31[47:31];

pp30 = (radians * {16'd30, 16'b0}); 
p30 = pp30[47:31];

pp29 = (radians * {16'd29, 16'b0}); 
p29 = pp29[47:31];

pp28 = (radians * {16'd28, 16'b0}); 
p28 = pp28[47:31];

pp27 = (radians * {16'd27, 16'b0}); 
p27 = pp27[47:31];

pp26 = (radians * {16'd26, 16'b0}); 
p26 = pp26[47:31];

pp25 = (radians * {16'd25, 16'b0}); 
p25 = pp25[47:31];

pp24 = (radians * {16'd24, 16'b0}); 
p24 = pp24[47:31];

pp23 = (radians * {16'd23, 16'b0}); 
p23 = pp23[47:31];

pp22 = (radians * {16'd22, 16'b0}); 
p22 = pp22[47:31];

pp21 = (radians * {16'd21, 16'b0}); 
p21 = pp21[47:31];

pp20 = (radians * {16'd20, 16'b0}); 
p20 = pp20[47:31];

pp19 = (radians * {16'd19, 16'b0}); 
p19 = pp19[47:31];

pp18 = (radians * {16'd18, 16'b0}); 
p18 = pp18[47:31];

pp17 = (radians * {16'd17, 16'b0}); 
p17 = pp17[47:31];

pp16 = (radians * {16'd16, 16'b0}); 
p16 = pp16[47:31];

pp15 = (radians * {16'd15, 16'b0}); 
p15 = pp15[47:31];

pp14 = (radians * {16'd14, 16'b0}); 
p14 = pp14[47:31];

pp13 = (radians * {16'd13, 16'b0}); 
p13 = pp13[47:31];

pp12 = (radians * {16'd12, 16'b0}); 
p12 = pp12[47:31];

pp11 = (radians * {16'd11, 16'b0}); 
p11 = pp11[47:31];

pp10 = (radians * {16'd10, 16'b0}); 
p10 = pp10[47:31];

pp9 = (radians * {16'd9, 16'b0}); 
p9 = pp9[47:31];

pp8 = (radians * {16'd8, 16'b0}); 
p8 = pp8[47:31];

pp7 = (radians * {16'd7, 16'b0}); 
p7 = pp7[47:31];

pp6 = (radians * {16'd6, 16'b0}); 
p6 = pp6[47:31];

pp5 = (radians * {16'd5, 16'b0}); 
p5 = pp5[47:31];

pp4 = (radians * {16'd4, 16'b0}); 
p4 = pp4[47:31];

pp3 = (radians * {16'd3, 16'b0}); 
p3 = pp3[47:31];

pp2 = (radians * {16'd2, 16'b0}); 
p2 = pp2[47:31];

pp1 = (radians * {16'd1, 16'b0}); 
p1 = pp1[47:31];

pp0 = (radians * {16'd0, 16'b0}); 
p0 = pp0[47:31];





	
end
	
	

always @(*)

// if (init_display) then do the code currently not commented out, else do operations and update 

begin
  /* Draw black horizontal line 300 pixels wide at y = 350 */
  /* Draw black vertical line 200 pixels tall starting at center of horizontal line */
  
  if (S == RFM_INIT || S == RFM_DRAWING) begin
	 // Horizontal line with fixed-point displacement
    if ((y == 350 && x >= (((WIDTH - 300)/2)+ pospos ) && x < (((WIDTH + 300)/2)+ pospos ))  )
        begin
          {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line
		  end
		  
		  
        // Vertical line 
		  else if 
        ((x == (WIDTH/2)+ (p200) + pospos) && (y == 150) )
		  begin
          {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line
		  end
			else if ((x == (WIDTH/2) + (p199)+ pospos) && (y == 151))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 151
end
else if ((x == (WIDTH/2) + (p198)+ pospos) && (y == 152))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 152
end
else if ((x == (WIDTH/2) + (p197)+ pospos) && (y == 153))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 153
end
else if ((x == (WIDTH/2) + (p196)+ pospos) && (y == 154))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 154
end
else if ((x == (WIDTH/2) + (p195)+ pospos) && (y == 155))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 155
end
else if ((x == (WIDTH/2) + (p194)+ pospos) && (y == 156))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 156
end
else if ((x == (WIDTH/2) + (p193)+ pospos) && (y == 157))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 157
end
else if ((x == (WIDTH/2) + (p192)+ pospos) && (y == 158))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 158
end
else if ((x == (WIDTH/2) + (p191)+ pospos) && (y == 159))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 159
end
else if ((x == (WIDTH/2) + (p190)+ pospos) && (y == 160))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 160
end
else if ((x == (WIDTH/2) + (p189)+ pospos) && (y == 161))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 161
end
else if ((x == (WIDTH/2) + (p188)+ pospos) && (y == 162))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 162
end
else if ((x == (WIDTH/2) + (p187)+ pospos) && (y == 163))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 163
end
else if ((x == (WIDTH/2) + (p186)+ pospos) && (y == 164))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 164
end
else if ((x == (WIDTH/2) + (p185)+ pospos) && (y == 165))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 165
end
else if ((x == (WIDTH/2) + (p184)+ pospos) && (y == 166))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 166
end
else if ((x == (WIDTH/2) + (p183)+ pospos) && (y == 167))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 167
end
else if ((x == (WIDTH/2) + (p182)+ pospos) && (y == 168))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 168
end
else if ((x == (WIDTH/2) + (p181)+ pospos) && (y == 169))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 169
end
else if ((x == (WIDTH/2) + (p180)+ pospos) && (y == 170))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 170
end
else if ((x == (WIDTH/2) + (p179)+ pospos) && (y == 171))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 171
end
else if ((x == (WIDTH/2) + (p178)+ pospos) && (y == 172))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 172
end
else if ((x == (WIDTH/2) + (p177)+ pospos) && (y == 173))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 173
end
else if ((x == (WIDTH/2) + (p176)+ pospos) && (y == 174))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 174
end
else if ((x == (WIDTH/2) + (p175)+ pospos) && (y == 175))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 175
end
else if ((x == (WIDTH/2) + (p174)+ pospos) && (y == 176))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 176
end
else if ((x == (WIDTH/2) + (p173)+ pospos) && (y == 177))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 177
end
else if ((x == (WIDTH/2) + (p172)+ pospos) && (y == 178))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 178
end
else if ((x == (WIDTH/2) + (p171)+ pospos) && (y == 179))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 179
end
else if ((x == (WIDTH/2) + (p170)+ pospos) && (y == 180))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 180
end
else if ((x == (WIDTH/2) + (p169)+ pospos) && (y == 181))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 181
end
else if ((x == (WIDTH/2) + (p168)+ pospos) && (y == 182))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 182
end
else if ((x == (WIDTH/2) + (p167)+ pospos) && (y == 183))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 183
end
else if ((x == (WIDTH/2) + (p166)+ pospos) && (y == 184))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 184
end
else if ((x == (WIDTH/2) + (p165)+ pospos) && (y == 185))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 185
end
else if ((x == (WIDTH/2) + (p164)+ pospos) && (y == 186))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 186
end
else if ((x == (WIDTH/2) + (p163)+ pospos) && (y == 187))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 187
end
else if ((x == (WIDTH/2) + (p162)+ pospos) && (y == 188))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 188
end
else if ((x == (WIDTH/2) + (p161)+ pospos) && (y == 189))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 189
end
else if ((x == (WIDTH/2) + (p160)+ pospos) && (y == 190))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 190
end
else if ((x == (WIDTH/2) + (p159)+ pospos) && (y == 191))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 191
end
else if ((x == (WIDTH/2) + (p158)+ pospos) && (y == 192))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 192
end
else if ((x == (WIDTH/2) + (p157)+ pospos) && (y == 193))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 193
end
else if ((x == (WIDTH/2) + (p156)+ pospos) && (y == 194))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 194
end
else if ((x == (WIDTH/2) + (p155)+ pospos) && (y == 195))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 195
end
else if ((x == (WIDTH/2) + (p154)+ pospos) && (y == 196))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 196
end
else if ((x == (WIDTH/2) + (p153)+ pospos) && (y == 197))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 197
end
else if ((x == (WIDTH/2) + (p152)+ pospos) && (y == 198))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 198
end
else if ((x == (WIDTH/2) + (p151)+ pospos) && (y == 199))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 199
end
else if ((x == (WIDTH/2) + (p150)+ pospos) && (y == 200))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 200
end
else if ((x == (WIDTH/2) + (p149)+ pospos) && (y == 201))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 201
end
else if ((x == (WIDTH/2) + (p148)+ pospos) && (y == 202))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 202
end
else if ((x == (WIDTH/2) + (p147)+ pospos) && (y == 203))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 203
end
else if ((x == (WIDTH/2) + (p146)+ pospos) && (y == 204))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 204
end
else if ((x == (WIDTH/2) + (p145)+ pospos) && (y == 205))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 205
end
else if ((x == (WIDTH/2) + (p144)+ pospos) && (y == 206))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 206
end
else if ((x == (WIDTH/2) + (p143)+ pospos) && (y == 207))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 207
end
else if ((x == (WIDTH/2) + (p142)+ pospos) && (y == 208))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 208
end
else if ((x == (WIDTH/2) + (p141)+ pospos) && (y == 209))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 209
end
else if ((x == (WIDTH/2) + (p140)+ pospos) && (y == 210))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 210
end
else if ((x == (WIDTH/2) + (p139)+ pospos) && (y == 211))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 211
end
else if ((x == (WIDTH/2) + (p138)+ pospos) && (y == 212))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 212
end
else if ((x == (WIDTH/2) + (p137)+ pospos) && (y == 213))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 213
end
else if ((x == (WIDTH/2) + (p136)+ pospos) && (y == 214))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 214
end
else if ((x == (WIDTH/2) + (p135)+ pospos) && (y == 215))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 215
end
else if ((x == (WIDTH/2) + (p134)+ pospos) && (y == 216))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 216
end
else if ((x == (WIDTH/2) + (p133)+ pospos) && (y == 217))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 217
end
else if ((x == (WIDTH/2) + (p132)+ pospos) && (y == 218))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 218
end
else if ((x == (WIDTH/2) + (p131)+ pospos) && (y == 219))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 219
end
else if ((x == (WIDTH/2) + (p130)+ pospos) && (y == 220))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 220
end
else if ((x == (WIDTH/2) + (p129)+ pospos) && (y == 221))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 221
end
else if ((x == (WIDTH/2) + (p128)+ pospos) && (y == 222))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 222
end
else if ((x == (WIDTH/2) + (p127)+ pospos) && (y == 223))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 223
end
else if ((x == (WIDTH/2) + (p126)+ pospos) && (y == 224))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 224
end
else if ((x == (WIDTH/2) + (p125)+ pospos) && (y == 225))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 225
end
else if ((x == (WIDTH/2) + (p124)+ pospos) && (y == 226))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 226
end
else if ((x == (WIDTH/2) + (p123)+ pospos) && (y == 227))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 227
end
else if ((x == (WIDTH/2) + (p122)+ pospos) && (y == 228))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 228
end
else if ((x == (WIDTH/2) + (p121)+ pospos) && (y == 229))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 229
end
else if ((x == (WIDTH/2) + (p120)+ pospos) && (y == 230))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 230
end
else if ((x == (WIDTH/2) + (p119)+ pospos) && (y == 231))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 231
end
else if ((x == (WIDTH/2) + (p118)+ pospos) && (y == 232))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 232
end
else if ((x == (WIDTH/2) + (p117)+ pospos) && (y == 233))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 233
end
else if ((x == (WIDTH/2) + (p116)+ pospos) && (y == 234))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 234
end
else if ((x == (WIDTH/2) + (p115)+ pospos) && (y == 235))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 235
end
else if ((x == (WIDTH/2) + (p114)+ pospos) && (y == 236))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 236
end
else if ((x == (WIDTH/2) + (p113)+ pospos) && (y == 237))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 237
end
else if ((x == (WIDTH/2) + (p112)+ pospos) && (y == 238))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 238
end
else if ((x == (WIDTH/2) + (p111)+ pospos) && (y == 239))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 239
end
else if ((x == (WIDTH/2) + (p110)+ pospos) && (y == 240))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 240
end
else if ((x == (WIDTH/2) + (p109)+ pospos) && (y == 241))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 241
end
else if ((x == (WIDTH/2) + (p108)+ pospos) && (y == 242))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 242
end
else if ((x == (WIDTH/2) + (p107)+ pospos) && (y == 243))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 243
end
else if ((x == (WIDTH/2) + (p106)+ pospos) && (y == 244))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 244
end
else if ((x == (WIDTH/2) + (p105)+ pospos) && (y == 245))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 245
end
else if ((x == (WIDTH/2) + (p104)+ pospos) && (y == 246))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 246
end
else if ((x == (WIDTH/2) + (p103)+ pospos) && (y == 247))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 247
end
else if ((x == (WIDTH/2) + (p102)+ pospos) && (y == 248))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 248
end
else if ((x == (WIDTH/2) + (p101)+ pospos) && (y == 249))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 249
end
else if ((x == (WIDTH/2) + (p100)+ pospos) && (y == 250))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 250
end
else if ((x == (WIDTH/2) + (p99)+ pospos) && (y == 251))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 251
end
else if ((x == (WIDTH/2) + (p98)+ pospos) && (y == 252))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 252
end
else if ((x == (WIDTH/2) + (p97)+ pospos) && (y == 253))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 253
end
else if ((x == (WIDTH/2) + (p96)+ pospos) && (y == 254))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 254
end
else if ((x == (WIDTH/2) + (p95)+ pospos) && (y == 255))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 255
end
else if ((x == (WIDTH/2) + (p94)+ pospos) && (y == 256))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 256
end
else if ((x == (WIDTH/2) + (p93)+ pospos) && (y == 257))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 257
end
else if ((x == (WIDTH/2) + (p92)+ pospos) && (y == 258))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 258
end
else if ((x == (WIDTH/2) + (p91)+ pospos) && (y == 259))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 259
end
else if ((x == (WIDTH/2) + (p90)+ pospos) && (y == 260))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 260
end
else if ((x == (WIDTH/2) + (p89)+ pospos) && (y == 261))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 261
end
else if ((x == (WIDTH/2) + (p88)+ pospos) && (y == 262))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 262
end
else if ((x == (WIDTH/2) + (p87)+ pospos) && (y == 263))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 263
end
else if ((x == (WIDTH/2) + (p86)+ pospos) && (y == 264))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 264
end
else if ((x == (WIDTH/2) + (p85)+ pospos) && (y == 265))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 265
end
else if ((x == (WIDTH/2) + (p84)+ pospos) && (y == 266))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 266
end
else if ((x == (WIDTH/2) + (p83)+ pospos) && (y == 267))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 267
end
else if ((x == (WIDTH/2) + (p82)+ pospos) && (y == 268))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 268
end
else if ((x == (WIDTH/2) + (p81)+ pospos) && (y == 269))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 269
end
else if ((x == (WIDTH/2) + (p80)+ pospos) && (y == 270))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 270
end
else if ((x == (WIDTH/2) + (p79)+ pospos) && (y == 271))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 271
end
else if ((x == (WIDTH/2) + (p78)+ pospos) && (y == 272))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 272
end
else if ((x == (WIDTH/2) + (p77)+ pospos) && (y == 273))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 273
end
else if ((x == (WIDTH/2) + (p76)+ pospos) && (y == 274))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 274
end
else if ((x == (WIDTH/2) + (p75)+ pospos) && (y == 275))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 275
end
else if ((x == (WIDTH/2) + (p74)+ pospos) && (y == 276))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 276
end
else if ((x == (WIDTH/2) + (p73)+ pospos) && (y == 277))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 277
end
else if ((x == (WIDTH/2) + (p72)+ pospos) && (y == 278))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 278
end
else if ((x == (WIDTH/2) + (p71)+ pospos) && (y == 279))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 279
end
else if ((x == (WIDTH/2) + (p70)+ pospos) && (y == 280))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 280
end
else if ((x == (WIDTH/2) + (p69)+ pospos) && (y == 281))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 281
end
else if ((x == (WIDTH/2) + (p68)+ pospos) && (y == 282))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 282
end
else if ((x == (WIDTH/2) + (p67)+ pospos) && (y == 283))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 283
end
else if ((x == (WIDTH/2) + (p66)+ pospos) && (y == 284))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 284
end
else if ((x == (WIDTH/2) + (p65)+ pospos) && (y == 285))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 285
end
else if ((x == (WIDTH/2) + (p64)+ pospos) && (y == 286))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 286
end
else if ((x == (WIDTH/2) + (p63)+ pospos) && (y == 287))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 287
end
else if ((x == (WIDTH/2) + (p62)+ pospos) && (y == 288))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 288
end
else if ((x == (WIDTH/2) + (p61)+ pospos) && (y == 289))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 289
end
else if ((x == (WIDTH/2) + (p60)+ pospos) && (y == 290))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 290
end
else if ((x == (WIDTH/2) + (p59)+ pospos) && (y == 291))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 291
end
else if ((x == (WIDTH/2) + (p58)+ pospos) && (y == 292))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 292
end
else if ((x == (WIDTH/2) + (p57)+ pospos) && (y == 293))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 293
end
else if ((x == (WIDTH/2) + (p56)+ pospos) && (y == 294))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 294
end
else if ((x == (WIDTH/2) + (p55)+ pospos) && (y == 295))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 295
end
else if ((x == (WIDTH/2) + (p54)+ pospos) && (y == 296))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 296
end
else if ((x == (WIDTH/2) + (p53)+ pospos) && (y == 297))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 297
end
else if ((x == (WIDTH/2) + (p52)+ pospos) && (y == 298))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 298
end
else if ((x == (WIDTH/2) + (p51)+ pospos) && (y == 299))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 299
end
else if ((x == (WIDTH/2) + (p50)+ pospos) && (y == 300))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 300
end
else if ((x == (WIDTH/2) + (p49)+ pospos) && (y == 301))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 301
end
else if ((x == (WIDTH/2) + (p48)+ pospos) && (y == 302))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 302
end
else if ((x == (WIDTH/2) + (p47)+ pospos) && (y == 303))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 303
end
else if ((x == (WIDTH/2) + (p46)+ pospos) && (y == 304))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 304
end
else if ((x == (WIDTH/2) + (p45)+ pospos) && (y == 305))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 305
end
else if ((x == (WIDTH/2) + (p44)+ pospos) && (y == 306))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 306
end
else if ((x == (WIDTH/2) + (p43)+ pospos) && (y == 307))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 307
end
else if ((x == (WIDTH/2) + (p42)+ pospos) && (y == 308))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 308
end
else if ((x == (WIDTH/2) + (p41)+ pospos) && (y == 309))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 309
end
else if ((x == (WIDTH/2) + (p40)+ pospos) && (y == 310))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 310
end
else if ((x == (WIDTH/2) + (p39)+ pospos) && (y == 311))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 311
end
else if ((x == (WIDTH/2) + (p38)+ pospos) && (y == 312))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 312
end
else if ((x == (WIDTH/2) + (p37)+ pospos) && (y == 313))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 313
end
else if ((x == (WIDTH/2) + (p36)+ pospos) && (y == 314))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 314
end
else if ((x == (WIDTH/2) + (p35)+ pospos) && (y == 315))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 315
end
else if ((x == (WIDTH/2) + (p34)+ pospos) && (y == 316))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 316
end
else if ((x == (WIDTH/2) + (p33)+ pospos) && (y == 317))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 317
end
else if ((x == (WIDTH/2) + (p32)+ pospos) && (y == 318))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 318
end
else if ((x == (WIDTH/2) + (p31)+ pospos) && (y == 319))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 319
end
else if ((x == (WIDTH/2) + (p30)+ pospos) && (y == 320))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 320
end
else if ((x == (WIDTH/2) + (p29)+ pospos) && (y == 321))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 321
end
else if ((x == (WIDTH/2) + (p28)+ pospos) && (y == 322))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 322
end
else if ((x == (WIDTH/2) + (p27)+ pospos) && (y == 323))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 323
end
else if ((x == (WIDTH/2) + (p26)+ pospos) && (y == 324))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 324
end
else if ((x == (WIDTH/2) + (p25)+ pospos) && (y == 325))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 325
end
else if ((x == (WIDTH/2) + (p24)+ pospos) && (y == 326))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 326
end
else if ((x == (WIDTH/2) + (p23)+ pospos) && (y == 327))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 327
end
else if ((x == (WIDTH/2) + (p22)+ pospos) && (y == 328))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 328
end
else if ((x == (WIDTH/2) + (p21)+ pospos) && (y == 329))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 329
end
else if ((x == (WIDTH/2) + (p20)+ pospos) && (y == 330))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 330
end
else if ((x == (WIDTH/2) + (p19)+ pospos) && (y == 331))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 331
end
else if ((x == (WIDTH/2) + (p18)+ pospos) && (y == 332))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 332
end
else if ((x == (WIDTH/2) + (p17)+ pospos) && (y == 333))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 333
end
else if ((x == (WIDTH/2) + (p16)+ pospos) && (y == 334))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 334
end
else if ((x == (WIDTH/2) + (p15)+ pospos) && (y == 335))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 335
end
else if ((x == (WIDTH/2) + (p14)+ pospos) && (y == 336))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 336
end
else if ((x == (WIDTH/2) + (p13)+ pospos) && (y == 337))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 337
end
else if ((x == (WIDTH/2) + (p12)+ pospos) && (y == 338))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 338
end
else if ((x == (WIDTH/2) + (p11)+ pospos) && (y == 339))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 339
end
else if ((x == (WIDTH/2) + (p10)+ pospos) && (y == 340))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 340
end
else if ((x == (WIDTH/2) + (p9)+ pospos) && (y == 341))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 341
end
else if ((x == (WIDTH/2) + (p8)+ pospos) && (y == 342))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 342
end
else if ((x == (WIDTH/2) + (p7)+ pospos) && (y == 343))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 343
end
else if ((x == (WIDTH/2) + (p6)+ pospos) && (y == 344))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 344
end
else if ((x == (WIDTH/2) + (p5)+ pospos) && (y == 345))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 345
end
else if ((x == (WIDTH/2) + (p4)+ pospos) && (y == 346))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 346
end
else if ((x == (WIDTH/2) + (p3)+ pospos) && (y == 347))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 347
end
else if ((x == (WIDTH/2) + (p2)+ pospos) && (y == 348))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 348
end
else if ((x == (WIDTH/2) + (p1)+ pospos) && (y == 349))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 349
end
else if ((x == (WIDTH/2) + (p0)+ pospos) && (y == 350))
begin
    {VGA_R, VGA_G, VGA_B} = 24'h000000;  // Black line at y = 350
end

			 
		else  
			{VGA_R, VGA_G, VGA_B} = 24'hFFFFFF;  // White during initialization 
			 
			 
		 
		end

  
   
  
  /* Color generation during writing phase */
  red = 8'hFF;
  green = 8'hFF;
  blue = 8'hFF;
end
endmodule