module seven_segment(
	input wire[3:0]i,
	output reg[6:0]o
);

// HEX out - rewire DE1
//  ---0---
// |       |
// 5       1
// |       |
//  ---6---
// |       |
// 4       2
// |       |
//  ---3---

always @(*)
begin
	case (i)	    // 6543210
		4'h0: o = 7'b1000000;
		4'h1: o = 7'b1111001;
		4'h2: o = 7'b0100100;
		4'h3: o = 7'b0110000;
		4'h4: o = 7'b0011001;
		4'h5: o = 7'b0010010;
		4'h6: o = 7'b0000010;
		4'h7: o = 7'b1111000;
		4'h8: o = 7'b0000000;
		4'h9: o = 7'b0010000;
		4'ha: o = 7'b0001000;
		4'hb: o = 7'b0000011;
		4'hc: o = 7'b1000110;
		4'hd: o = 7'b0100001;
		4'he: o = 7'b0000110;
		4'hf: o = 7'b0001110;
	endcase
end

endmodule