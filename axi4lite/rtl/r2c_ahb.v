//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple Read-to-Clear interrupt module. Captures a pulse input 
//             : into level type interrupt output
//-----------------------------------------------------------------------------

module r2c_ahb (
	//AHB Lite interface (slave)
	input				clk				,
	input				resetn			, //synchronous active low reset
	input 		[31:0]	ahb_haddr		,
	input 		[ 1:0]	ahb_hsize		,
	input 		[ 1:0]	ahb_htrans		,
	input 		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	output		[31:0] 	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hready		,
	// Interrupt input/output
	input				int_pulse_in	, // active high pulse input
	output	reg			int_level_out =0 // active high level interrupt output
);

	assign ahb_hrdata    = {{30{1'b0}},int_level_out};
	assign ahb_hresp     = 1'b0;
	assign ahb_hready    = 1'b1;
	reg clr = 0;
	
	always @(posedge clk)
		if (~resetn) begin
			int_level_out   <= 1'b0;
			clr <= 1'b0;
		end else begin
			clr <= ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ~ahb_hwrite;
			int_level_out <= int_level_out? clr? 1'b0 : int_level_out : int_pulse_in;
		end

endmodule
