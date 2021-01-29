//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AHB Lite to Avalon MM module
//----------------------------------------------------------------------------

module ahb_debug_capture(
	//Avalon MM interface (master)
	input				clk				,
	input				aresetn			,
	//AHB Lite interface (monitor interface)
	input		[31:0]	ahb_haddr		,
	input		[ 1:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input		[31:0]	ahb_hrdata		,
	input				ahb_hresp		,
	output				status1,
	output 				status2
);

	reg		[31:0]	state_haddr		;
	reg		[ 1:0]	state_hsize		;
	reg		[ 1:0]	state_htrans	;
	reg		[31:0]	state_hwdata	;
	reg				state_hwrite	;
	reg				state_hready	;
	reg		[31:0]	state_hrdata	;
	reg				state_hresp		;
	
	reg		[31:0]	capt_haddr		;
	reg		[ 1:0]	capt_hsize		;
	reg		[ 1:0]	capt_htrans		;
	reg		[31:0]	capt_hwdata		;
	reg				capt_hwrite		;
	reg		[31:0]	capt_hrdata		;
	reg				capt_hresp		;

	reg		[15:0]  tr_init;
	reg		[15:0]  tr_done;
	reg 			tr_act;
	
	assign status1 = ^state_haddr ^ ^state_hsize ^ ^state_htrans ^ ^state_hwdata ^ state_hwrite ^ state_hready ^ ^state_hrdata ^ state_hresp;
	assign status2 = ^capt_haddr ^ ^capt_hsize ^ ^capt_htrans ^ ^capt_hwdata ^ capt_hwrite ^ ^capt_hrdata ^ capt_hresp ^ ^tr_init ^ ^tr_done;
	
	always @(posedge clk or negedge aresetn)
		if (~aresetn) begin
			state_haddr		<= 0;
			state_hsize		<= 0;
			state_htrans	<= 0;
			state_hwdata	<= 0;
			state_hwrite	<= 0;
			state_hready	<= 0;
			state_hrdata	<= 0;
			state_hresp		<= 0;
			capt_haddr		<= 0;
			capt_hsize		<= 0;
			capt_htrans		<= 0;
			capt_hwdata		<= 0;
			capt_hwrite		<= 0;
			capt_hrdata		<= 0;
			capt_hresp		<= 0;
			tr_init <= 0;
			tr_done <= 0;
			tr_act  <= 0;
		end else begin
			state_haddr		<= ahb_haddr	;
			state_hsize		<= ahb_hsize	;
			state_htrans	<= ahb_htrans	;
			state_hwdata	<= ahb_hwdata	;
			state_hwrite	<= ahb_hwrite	;
			state_hready	<= ahb_hready	;
			state_hrdata	<= ahb_hrdata	;
			state_hresp		<= ahb_hresp	;
			
			if (ahb_hready & tr_act) begin
				capt_hwdata	<= ahb_hwdata	;
				capt_hrdata	<= ahb_hrdata	;
				capt_hresp	<= ahb_hresp	;
				tr_act <= 0;
				tr_done <= tr_done + 1'b1;
			end
			if (ahb_hready & |ahb_htrans) begin
				capt_haddr	<= ahb_haddr	;
				capt_hsize	<= ahb_hsize	;
				capt_htrans	<= ahb_htrans	;
				capt_hwrite	<= ahb_hwrite	;
				tr_init <= tr_init + 1'b1;
				tr_act <= 1'b1;
			end
		
		end
	
endmodule





