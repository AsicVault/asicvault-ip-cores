//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM to APB bridge, supports only 32-bit access
//-----------------------------------------------------------------------------

module amm2apb (
	input				clk				,
	input				reset			,
	input		[31:0]	amm_address		,
	input		[31:0]	amm_writedata	,
	input				amm_write		,
	input				amm_read		,
	output		[31:0]	amm_readdata	,
	output				amm_waitrequest	,

	output				APB_PSEL 		,
	output	reg			APB_PENABLE	= 0	,
	output		[31:0]	APB_PADDR		,
	output		[31:0]	APB_PWDATA		,
	output				APB_PWRITE		,
	input		[31:0]	APB_PRDATA		,
	input				APB_PREADY		,
	input				APB_PSLVERR		
);

	always @(posedge clk or posedge reset)
		if (reset) begin
			APB_PENABLE <= 1'b0;
		end else begin
			APB_PENABLE <= APB_PENABLE? ~APB_PREADY : APB_PSEL;
		end
	
	assign	APB_PADDR	= amm_address;
	assign	APB_PSEL	= amm_write | amm_read;
	assign	APB_PWDATA	= amm_writedata;
	assign	APB_PWRITE	= amm_write;
	assign	amm_readdata= APB_PRDATA;
	assign	amm_waitrequest = APB_PENABLE? ~APB_PREADY : 1'b1;
	
	
endmodule
