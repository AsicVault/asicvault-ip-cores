//-----------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple AHB Lite to APB bridge
//-----------------------------------------------

module ahb2apb (
	//Avalon MM interface (master)
	input				hclk			,
	input				hresetn			, //synchronous active low reset
	//AHB Lite interface (slave interface)
	input		[31:0]	apb_addr_mask	,
	input		[31:0]	ahb_haddr		,
	input		[ 1:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	,
	// APB bus - master
	output				APB_PSELx		,
	output				APB_PENABLE		,
	output		[31:0]	APB_PADDR		,
	output		[31:0]	APB_PWDATA		,
	output				APB_PWRITE		,
	input		[31:0]	APB_PRDATA		,
	input				APB_PREADY		,
	input				APB_PSLVERR		
);

	wire	[31:0]	amm_address			, amm_address1;
	wire	[31:0]	amm_writedata		;
	wire	[ 3:0]	amm_byteenable		;
	wire			amm_write			;
	wire			amm_read			;
	wire	[31:0]	amm_readdata		;
	wire			amm_waitrequest		;

	ahb2amm #(
		.P_2X_CLOCK	(0) // set this to 1 when AHB bus has 2x slower (synchronous) clock compared to AMM interface
	) i_ahb2amm (
		.aclk				(	hclk				),
		.aresetn			(	hresetn				), //synchronous active low reset
		.amm_address		(	amm_address			),
		.amm_writedata		(	amm_writedata		),
		.amm_byteenable		(	amm_byteenable		),
		.amm_write			(	amm_write			),
		.amm_read			(	amm_read			),
		.amm_readdata		(	amm_readdata		),
		.amm_waitrequest	(	amm_waitrequest		),
		.ahb_haddr			(	ahb_haddr			),
		.ahb_hsize			(	ahb_hsize			),
		.ahb_htrans			(	ahb_htrans			),
		.ahb_hwdata			(	ahb_hwdata			),
		.ahb_hwrite			(	ahb_hwrite			),
		.ahb_hready			(	ahb_hready			),
		.ahb_hselx			(	ahb_hselx			),
		.ahb_hrdata			(	ahb_hrdata			),
		.ahb_hresp			(	ahb_hresp			),
		.ahb_hreadyout		(	ahb_hreadyout		)
	);

	assign amm_address1 = amm_address & apb_addr_mask;
	
	amm2apb i_amm2apb (
		.clk				(	hclk				),
		.reset				(	~hresetn			),
		.amm_address		(	amm_address1		),
		.amm_writedata		(	amm_writedata		),
		.amm_write			(	amm_write			),
		.amm_read			(	amm_read			),
		.amm_readdata		(	amm_readdata		),
		.amm_waitrequest	(	amm_waitrequest		),
		.APB_PSEL 			(	APB_PSELx			),
		.APB_PENABLE		(	APB_PENABLE			),
		.APB_PADDR			(	APB_PADDR			),
		.APB_PWDATA			(	APB_PWDATA			),
		.APB_PWRITE			(	APB_PWRITE			),
		.APB_PRDATA			(	APB_PRDATA			),
		.APB_PREADY			(	APB_PREADY			),
		.APB_PSLVERR		(	APB_PSLVERR			)
	);

endmodule

