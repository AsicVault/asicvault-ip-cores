//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : eccop_ahb_async
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_ahb_async #(
	parameter P_ASYNC_BUS = 1, //Enable separate bus and processing clock.
	parameter P_DUMMY = 0,
	parameter P_POLARFIRE = 1
) (
	input				clk				, // engine clock
	input				sreset			, // synchronous reset
	input				areset			, // asynchronous reset
	input				hclk			, // bus clock
	input				hresetn			, // bus reset - engine sreset is generated from this internally
	//AHB Lite interface (slave interface)
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	,
	output				interrupt		
);

	wire	[31:0]	amm_address			;
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

	generate if (P_DUMMY) begin : dummy_engine
		assign amm_waitrequest = 1'b0;
		assign amm_readdata    = 32'hDEADC0DE;
		assign interrupt       = 1'b0;
	end else begin
		eccop_amm_async #(
			.P_ASYNC_BUS(	P_ASYNC_BUS	),	//Enable separate bus and processing clock.
			.P_POLARFIRE(	P_POLARFIRE	)
		) i_eccop_amm_async (
			.clk				(	clk					), // engine clock
			.sreset				(	sreset				), // synchronous reset
			.areset				(	areset				), // asynchronous reset
			.bus_clk			(	hclk				), // bus clock
			.bus_sreset			(	~hresetn			), // bus reset - engine sreset is generated from this internally
			.bus_areset			(	1'b0				), // bus reset - asynchronous
			.bus_interrupt		(	interrupt			),
			.bus_address		(	amm_address			),
			.bus_writedata		(	amm_writedata		),
			.bus_write			(	amm_write			),
			.bus_read			(	amm_read			),
			.bus_waitrequest	(	amm_waitrequest		),
			.bus_readdata		(	amm_readdata		)
		);
	end endgenerate

endmodule
