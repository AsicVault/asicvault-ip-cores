//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : 2S-to-1M APB bus multiplexer/arbiter 
//-----------------------------------------------------------------------------

module apb_mux #(
		parameter DW = 16,
		parameter AW = 16
)(
	input		  CLK				,
	input		  RESETN			,
	
	input         APBS1_PSEL 		,
	input         APBS1_PENABLE		,
	input  [AW-1:0] APBS1_PADDR		,
	input  [DW-1:0] APBS1_PWDATA	,
	input         APBS1_PWRITE		,
	output [DW-1:0] APBS1_PRDATA	,
	output        APBS1_PREADY		,
	output        APBS1_PSLVERR		,

	input         APBS2_PSEL 		,
	input         APBS2_PENABLE		,
	input  [AW-1:0] APBS2_PADDR		,
	input  [DW-1:0] APBS2_PWDATA	,
	input         APBS2_PWRITE		,
	output [DW-1:0] APBS2_PRDATA	,
	output        APBS2_PREADY		,
	output        APBS2_PSLVERR		,

	output        APBM_PSEL 		,
	output        APBM_PENABLE		,
	output [AW-1:0] APBM_PADDR		,
	output [DW-1:0] APBM_PWDATA		,
	output        APBM_PWRITE		,
	input  [DW-1:0] APBM_PRDATA		,
	input         APBM_PREADY		,
	input         APBM_PSLVERR		
);

	reg sel = 0;
	always @(posedge CLK or negedge RESETN)
		if (~RESETN) begin
			sel <= 0;
		end else begin
			case (sel)
				1		: sel <= APBS2_PSEL? (APBS2_PREADY & APBS2_PENABLE)? APBS1_PSEL? 0 : 1 : 1 : APBS1_PSEL? 0 : 1;
				default	: sel <= APBS1_PSEL? (APBS1_PREADY & APBS1_PENABLE)? APBS2_PSEL? 1 : 0 : 0 : APBS2_PSEL? 1 : 0;
			endcase
		end
			
	assign APBM_PADDR	= sel? APBS2_PADDR : APBS1_PADDR;
	assign APBM_PWDATA	= sel? APBS2_PWDATA : APBS1_PWDATA;
	assign APBM_PSEL	= sel? APBS2_PSEL : APBS1_PSEL;
	assign APBM_PENABLE = sel? APBS2_PENABLE : APBS1_PENABLE;
	assign APBM_PWRITE	= sel? APBS2_PWRITE : APBS1_PWRITE;
	
	assign APBS1_PREADY = APBM_PREADY & ~sel;
	assign APBS1_PSLVERR= APBM_PSLVERR& ~sel;
	assign APBS1_PRDATA = APBM_PRDATA;
	
	assign APBS2_PREADY = APBM_PREADY & sel;
	assign APBS2_PSLVERR= APBM_PSLVERR& sel;
	assign APBS2_PRDATA = APBM_PRDATA;


endmodule