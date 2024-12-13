// top level real module of the math and physics behind it moving, as well as everything  


module pendulum_problem(
input CLOCK_50, 
input [3:0]SW,
input [3:1]KEY,
//input rst,


output reg [31:0]stan,
output reg [31:0]theta

);


wire clk;
wire load;
wire start;
wire reset;
assign clk = CLOCK_50;
assign reset = KEY[1];
assign load = KEY[2];
assign start = KEY[3];

					
					
parameter      START = 5'd1,
					CONVERT      = 5'd2,
					INITIALIZE   = 5'd3,

					// Calculation states
					XD_CALC      = 5'd4,
					X_CALC       = 5'd5,
					THETAD_CALC  = 5'd6,
					THETA_CALC   = 5'd7,

					// Check states
					CHK_THETA    = 5'd8,
					CHK_THETAD   = 5'd9,
					CHK_X        = 5'd10,
					CHK_XD       = 5'd11,
					CHK_XDD      = 5'd12,
					CHK_THETADD  = 5'd13,
					
					XDD_CALC		= 5'd14,
					THETADD_CALC = 5'd15,
					
					// Error 
					ERROR = 5'd16;
					
					
					
reg [4:0]S;
reg [4:0]NS;

reg [31:0]radians;
reg[63:0]fornow;
wire [31:0]noah = {12'b0,SW,16'b0};
wire [31:0]conv_factor = 32'b00000000000000000000010001100001;
wire [31:0]tim = 32'h00006554;

reg [63:0]aud;
reg [63:0]audd;
reg [63:0]au;
reg [63:0]a;

reg [63:0]xddt;
reg [63:0]xdt;
reg [63:0]thetaddt;
reg [63:0]thetadt;


reg [31:0]current_theta;
reg [31:0]current_thetad;
reg [31:0]current_xdd;
reg [31:0]current_xd;
reg [31:0]current_x;

reg [31:0]thetad;
reg [31:0]thetadd;
reg [31:0]xdd;
reg [31:0]xd;


reg [31:0]change_x;
reg [31:0]change_theta;



	 // module to calculate theta dd
//	 calculate_thetadd johns_thetadd(

//		.theta(current_theta),
//		.thetad(current_thetad),
//		.xdd(current_xdd),
//		.xd(current_xd),
		
//		.thetadd(thetadd_m)
//		);
		
		
	// module to calculate x dd	
//	calculate_xdd johns_xdd(

//		.theta(current_theta),
//		.thetad(current_thetad),
//		.thetadd(thetadd),
//		.xd(current_x),
		
//		.xdd(xdd)
//		);
		
		

		
 
// these are things that are for THETADD calculations   
 localparam [31:0]tt1 = 32'h00006D73;
 localparam [31:0]tt2 = 32'h000015A3;
 localparam [31:0]tt3 = 32'h00000AF2;
 localparam [31:0]tden = 32'h0000097C;
 
	
 
 // thigns that are 64 bits 
 reg [63:0]tt;
 reg [63:0]tterm1;
 reg [63:0]tter;
 reg [63:0]ttermm;
 reg [63:0]tterm3;
 // thigns that are 32 bits 
 reg [31:0]tactterm1;
 reg [31:0]tte;
 reg [31:0]tterm;
 reg [31:0]tterm2;
 reg [31:0]tactterm3;
 

 // these are things for the XDD calculations
 localparam [31:0]xt1 = 32'h00000AF2; // mp * l 
 localparam [31:0]xden = 32'h0000C3B7; // mc + mp

 
 // thigns that are 64 bits 
 reg [63:0]xt;
 reg [63:0]xsqu;
 reg [63:0]xtn;

 // thigns that are 32 bits 
 reg [31:0]xsqua;
 reg [31:0]xte;
 reg [31:0]xterm1;
 reg [31:0]xterm2;

 
   
		
	//seven_segment johns_sev(
	// just show what degrees you inputted, essnetially the switch from binary to seven nothing special 


//reset always block 
always@(posedge clk or negedge reset)
if (reset == 1'b0)  begin
	S = START;
	end
	else  
	begin
	S = NS;
	end

	
	
	
// from one state to the next always block 	
always@(*)
begin 
	case(S)
		// once rst pressed, wait for load 
		START:
		begin
		if(load == 1'b0) 
			NS = START;
		else 
			NS = CONVERT;
		end
		
	
		// once load is pressed, convert the SW to input into VGA
		CONVERT:
		begin 
		if(start == 1'b0)
			NS = CONVERT; 
		else
			NS = INITIALIZE;
		end
		// once start is pressed, set all calcs to present (initialize) 	
		INITIALIZE: NS = THETADD_CALC;
		
		//and run through calculations 
		THETADD_CALC: NS = INITIALIZE;
		XDD_CALC: NS = XD_CALC;
		
		XD_CALC: NS = X_CALC;
		X_CALC: NS = THETAD_CALC;
		THETAD_CALC: NS =  THETA_CALC;
		THETA_CALC: NS = CHK_THETA;
		
// if they are not all zero, then it needs to run through all the calculations again 
// if they are all zero, then the design go back to initialize to run through the calculations until 0 
		CHK_THETA: 
		begin
		if (theta==32'd0)
			NS = CHK_THETAD;
		else 
			NS = INITIALIZE;
		end

		CHK_THETAD: 
		begin
		if (thetad==32'd0)
			NS = CHK_X;
		else 
			NS = INITIALIZE;
		end

		CHK_X: 
		begin
		if (stan==32'd0)
			NS = CHK_XD;
		else 
			NS = INITIALIZE;
		end

		CHK_XD: 
		begin
		if (xd==32'd0)
			NS = CHK_XDD;
		else 
			NS = INITIALIZE;
		end

		CHK_XDD: 
		begin
		if (xdd==32'd0)
			NS = CHK_THETADD;
		else 
			NS = INITIALIZE;
		end

		CHK_THETADD: 
		begin
		if (thetadd==32'd0)
			NS = START;
		else 
			NS = INITIALIZE;
		end
		default: NS = START;
	
	endcase
end



	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
always@(posedge clk or negedge reset)

begin 		
	case(S)
	START: 
	begin
		thetadd <= 32'h00000000;
		thetad <= 32'h00000000;
		theta <= 32'h00000000;
		
		xdd <= 32'h00000000;
		xd <= 32'h00000000;
		stan <= 32'h00000000;
		
	end
	 


//convert from degree input by switches to radians 
	CONVERT: 
	begin
	fornow = noah * conv_factor;
	radians = fornow[47:16]; 
	theta = radians;
	end	
	

	
// Operations 
// calculations one by one 
	INITIALIZE: begin		// this makes everything from the previous iterations the current 
		
		current_thetad = thetad;
		current_theta = theta;
		
		current_xd = xd;
		current_x = stan;

	end

// I initially had theta dd calc and x dd calc here but decided to make another module to do the calculations 

// these next state go through the additon of deltat 
// delta t can just be 1 second, and the clock can be changed so that the program goes through the FSM every one second 



THETADD_CALC:
begin 
 
 tterm1 = tt1 * current_theta;
 
 tactterm1 = tterm1[47:16];
 
 
 tt = xd * current_thetad;
 tte = tt[47:16];
 tter = tte * current_theta;
 tterm = tter[47:16];
 ttermm = tterm * tt2;
 tterm2 = ttermm[47:16];
 

 tterm3 = tt3 * xdd;
 tactterm3 = tterm3[47:16];

 
 // final acceleration of x 
 thetadd = {( tactterm1 + tterm2 - tactterm3 ),(16'd0)} / tden;
 
 
 
 end 


XDD_CALC:
  begin
  
  xt = xt1  * thetadd;
  xterm1 = xt[47:16];
  
  xsqu = current_thetad * current_thetad;
  xsqua = xsqu[47:16];
  xtn = xt1 * xsqua;
  xterm2 = xtn[47:16];
  
  
  xdd = {(xterm1 + xterm2),(16'd0)} / xden;
  
  
  end 











	XD_CALC: begin
		
		aud = xdd * tim;
		xddt = aud[47:16];
		xd = current_xd + xddt;
		
		end

		
	 X_CALC: begin
	   au = xd * tim;
		xdt = au[47:16];
		change_x = current_x - xdt;
		
		stan = current_x - change_x;
	
		end
		
		
	THETAD_CALC: begin
		audd = thetadd * tim;
		thetaddt = audd[47:16];
		thetad = current_thetad + thetaddt;
		
		end
		

	THETA_CALC: begin
		a = thetad * tim;
		thetadt = a[47:16];
		change_theta = current_theta - thetadt;

		theta = current_theta - change_theta;
		
		end
		
	endcase
end

endmodule 
	

		
		
		
		
		
		
		




















