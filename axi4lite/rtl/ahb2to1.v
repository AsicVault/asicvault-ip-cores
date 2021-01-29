//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple 2 AHB slave into 1 AHB master multiplexer
//----------------------------------------------------------------------------

module ahb2to1 (
	//Avalon MM interface (master)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	//AHB Lite interface (slave interface)
	input		[31:0]	ahb0_haddr		,
	input		[ 2:0]	ahb0_hsize		,
	input		[ 1:0]	ahb0_htrans		,
	input		[31:0]	ahb0_hwdata		,
	input				ahb0_hwrite		,
	input				ahb0_hready		,
	input				ahb0_hselx		,
	output		[31:0]	ahb0_hrdata		,
	output				ahb0_hresp		,
	output				ahb0_hreadyout	,

	input		[31:0]	ahb1_haddr		,
	input		[ 2:0]	ahb1_hsize		,
	input		[ 1:0]	ahb1_htrans		,
	input		[31:0]	ahb1_hwdata		,
	input				ahb1_hwrite		,
	input				ahb1_hready		,
	input				ahb1_hselx		,
	output		[31:0]	ahb1_hrdata		,
	output				ahb1_hresp		,
	output				ahb1_hreadyout	,
	
	//AHB Lite interface (master)
	output		[31:0]	ahbm_haddr		,
	output		[ 2:0]	ahbm_hsize		,
	output		[ 1:0]	ahbm_htrans		,
	output		[31:0]	ahbm_hwdata		,
	output				ahbm_hwrite		,
	output		[ 2:0]	ahbm_hburst		,
	input		[31:0]	ahbm_hrdata		,
	input				ahbm_hresp		,
	input 				ahbm_hready		
	
);

	wire	[31:0]	am0_address		;
	wire	[31:0]	am0_writedata	;
	wire	[ 3:0]	am0_byteenable	;
	wire			am0_write		;
	wire			am0_read		;
	wire	[31:0]	am0_readdata	;
	wire			am0_waitrequest	;

	wire	[31:0]	am1_address		;
	wire	[31:0]	am1_writedata	;
	wire	[ 3:0]	am1_byteenable	;
	wire			am1_write		;
	wire			am1_read		;
	wire	[31:0]	am1_readdata	;
	wire			am1_waitrequest	;

	wire	[31:0]	amm_address		;
	wire	[31:0]	amm_writedata	;
	wire	[ 3:0]	amm_byteenable	;
	wire			amm_write		;
	wire			amm_read		;
	wire	[31:0]	amm_readdata	;
	wire			amm_waitrequest	;
	
	reg sel = 0;
	reg active = 0;

	ahb2amm #(0) i_ahb2amm_0 (
		.aclk				(	aclk		),
		.aresetn			(	aresetn		), //synchronous active low reset
		.amm_address		(	am0_address			),
		.amm_writedata		(	am0_writedata		),
		.amm_byteenable		(	am0_byteenable		),
		.amm_write			(	am0_write			),
		.amm_read			(	am0_read			),
		.amm_readdata		(	am0_readdata		),
		.amm_waitrequest	(	am0_waitrequest		),
		.ahb_haddr			(	ahb0_haddr			),
		.ahb_hsize			(	ahb0_hsize			),
		.ahb_htrans			(	ahb0_htrans			),
		.ahb_hwdata			(	ahb0_hwdata			),
		.ahb_hwrite			(	ahb0_hwrite			),
		.ahb_hready			(	ahb0_hready			),
		.ahb_hselx			(	ahb0_hselx			),
		.ahb_hrdata			(	ahb0_hrdata			),
		.ahb_hresp			(	ahb0_hresp			),
		.ahb_hreadyout		(	ahb0_hreadyout		)
	);

	ahb2amm #(0) i_ahb2amm_1 (
		.aclk				(	aclk		),
		.aresetn			(	aresetn		), //synchronous active low reset
		.amm_address		(	am1_address			),
		.amm_writedata		(	am1_writedata		),
		.amm_byteenable		(	am1_byteenable		),
		.amm_write			(	am1_write			),
		.amm_read			(	am1_read			),
		.amm_readdata		(	am1_readdata		),
		.amm_waitrequest	(	am1_waitrequest		),
		.ahb_haddr			(	ahb1_haddr			),
		.ahb_hsize			(	ahb1_hsize			),
		.ahb_htrans			(	ahb1_htrans			),
		.ahb_hwdata			(	ahb1_hwdata			),
		.ahb_hwrite			(	ahb1_hwrite			),
		.ahb_hready			(	ahb1_hready			),
		.ahb_hselx			(	ahb1_hselx			),
		.ahb_hrdata			(	ahb1_hrdata			),
		.ahb_hresp			(	ahb1_hresp			),
		.ahb_hreadyout		(	ahb1_hreadyout		)
	);

	assign	amm_address		= sel? am1_address		: am0_address		;
	assign	amm_writedata	= sel? am1_writedata	: am0_writedata		;
	assign	amm_byteenable	= sel? am1_byteenable	: am0_byteenable	;
	assign	amm_write		= active & (sel? am1_write	: am0_write	);
	assign	amm_read		= active & (sel? am1_read	: am0_read	);
	
	assign am0_readdata = amm_readdata	;
	assign am1_readdata = amm_readdata	;
	assign am0_waitrequest	= active? sel? 1'b1 : amm_waitrequest : 1'b1;
	assign am1_waitrequest	= active? sel? amm_waitrequest : 1'b1 : 1'b1;
	
	always @(posedge aclk)
		if (~aresetn) begin
			sel		<= 0;
			active	<= 0;
		end else begin
			active	<= active? amm_waitrequest : am0_read | am0_write | am1_read | am1_write;
			sel <= active? sel : sel? ((am0_read | am0_write)? 0 : sel) : ((am1_read | am1_write)? 1 : sel); 
		end
		
	
	amm2ahb i_amm2ahb (
		//Avalon MM interface (slave)
		.aclk				(	aclk				),
		.aresetn			(	aresetn				), //synchronous active low reset
		.amm_address		(	amm_address			),
		.amm_writedata		(	amm_writedata		),
		.amm_byteenable		(	amm_byteenable		),
		.amm_write			(	amm_write			),
		.amm_read			(	amm_read			),
		.amm_readdata		(	amm_readdata		),
		.amm_waitrequest	(	amm_waitrequest		),
		//AHB Lite interface (master)
		.ahb_haddr			(	ahbm_haddr			),
		.ahb_hsize			(	ahbm_hsize			),
		.ahb_htrans			(	ahbm_htrans			),
		.ahb_hwdata			(	ahbm_hwdata			),
		.ahb_hwrite			(	ahbm_hwrite			),
		.ahb_hburst			(	ahbm_hburst			),
		.ahb_hrdata			(	ahbm_hrdata			),
		.ahb_hresp			(	ahbm_hresp			),
		.ahb_hready			(	ahbm_hready			)
	);
	
	
	
	
endmodule

