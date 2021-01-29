//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : AXI 2S:1M high performance multiplexer with pipelined channels
//-----------------------------------------------------------------------------

module axi_hpmux #(
	parameter P_AXI_IDWIDTH = 5
)(
	input						aclk			,
	input						aresetn			,
	// AXI Slave inetrface1 - input
	input	[31:0]				axis1_awaddr	,
	input	[ 7:0]				axis1_awlen		,
	input	[ 2:0]				axis1_awsize	,
	input	[ 1:0]				axis1_awburst	,
	input	[P_AXI_IDWIDTH-1:0]	axis1_awid		,
	input						axis1_awlock	,
	input	[3:0]				axis1_awcache	,
	input	[2:0]				axis1_awprot	,
	input						axis1_awvalid	,
	output						axis1_awready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis1_wid		,
	input	[63:0]				axis1_wdata		,
	input	[ 7:0]				axis1_wstrb		,
	input						axis1_wlast		,
	input						axis1_wvalid	,
	output						axis1_wready	,

	output	[P_AXI_IDWIDTH-1:0]	axis1_bid		,
	output	[ 1:0]				axis1_bresp		,
	output						axis1_bvalid	,
	input						axis1_bready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis1_arid		,
	input	[31:0]				axis1_araddr	,
	input	[ 3:0]				axis1_arlen		,
	input	[ 2:0]				axis1_arsize	,
	input	[ 1:0]				axis1_arburst	,
	input						axis1_arlock	,
	input	[3:0]				axis1_arcache	,
	input	[2:0]				axis1_arprot	,
	input						axis1_arvalid	,
	output						axis1_arready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axis1_rid		,
	output	[63:0]				axis1_rdata		,
	output	[ 1:0]				axis1_rresp		,
	output						axis1_rlast		,
	output						axis1_rvalid	,
	input						axis1_rready	,

	input						axis1_awuser	,
	input						axis1_wuser		,
	output						axis1_buser		,
	input						axis1_aruser	,
	output						axis1_ruser		,

	// AXI Slave inetrface2 - input
	input	[31:0]				axis2_awaddr	,
	input	[ 7:0]				axis2_awlen		,
	input	[ 2:0]				axis2_awsize	,
	input	[ 1:0]				axis2_awburst	,
	input	[P_AXI_IDWIDTH-1:0]	axis2_awid		,
	input						axis2_awlock	,
	input	[3:0]				axis2_awcache	,
	input	[2:0]				axis2_awprot	,
	input						axis2_awvalid	,
	output						axis2_awready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis2_wid		,
	input	[63:0]				axis2_wdata		,
	input	[ 7:0]				axis2_wstrb		,
	input						axis2_wlast		,
	input						axis2_wvalid	,
	output						axis2_wready	,

	output	[P_AXI_IDWIDTH-1:0]	axis2_bid		,
	output	[ 1:0]				axis2_bresp		,
	output						axis2_bvalid	,
	input						axis2_bready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis2_arid		,
	input	[31:0]				axis2_araddr	,
	input	[ 3:0]				axis2_arlen		,
	input	[ 2:0]				axis2_arsize	,
	input	[ 1:0]				axis2_arburst	,
	input						axis2_arlock	,
	input	[3:0]				axis2_arcache	,
	input	[2:0]				axis2_arprot	,
	input						axis2_arvalid	,
	output						axis2_arready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axis2_rid		,
	output	[63:0]				axis2_rdata		,
	output	[ 1:0]				axis2_rresp		,
	output						axis2_rlast		,
	output						axis2_rvalid	,
	input						axis2_rready	,

	input						axis2_awuser	,
	input						axis2_wuser		,
	output						axis2_buser		,
	input						axis2_aruser	,
	output						axis2_ruser		,


	// AXI Master inetrface - output
	output	[31:0]				axim_awaddr		,
	output	[ 7:0]				axim_awlen		,
	output	[ 2:0]				axim_awsize		,
	output	[ 1:0]				axim_awburst	,
	output	[P_AXI_IDWIDTH-1:0]	axim_awid		,
	output						axim_awlock		,
	output	[3:0]				axim_awcache	,
	output	[2:0]				axim_awprot		,
	output						axim_awvalid	,
	input						axim_awready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_wid		,
	output	[63:0]				axim_wdata		,
	output	[ 7:0]				axim_wstrb		,
	output						axim_wlast		,
	output						axim_wvalid		,
	input						axim_wready		,

	input	[P_AXI_IDWIDTH-1:0]	axim_bid		,
	input	[ 1:0]				axim_bresp		,
	input						axim_bvalid		,
	output						axim_bready		,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_arid		,
	output	[31:0]				axim_araddr		,
	output	[ 3:0]				axim_arlen		,
	output	[ 2:0]				axim_arsize		,
	output	[ 1:0]				axim_arburst	,
	output						axim_arlock		,
	output	[3:0]				axim_arcache	,
	output	[2:0]				axim_arprot		,
	output						axim_arvalid	,
	input						axim_arready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axim_rid		,
	input	[63:0]				axim_rdata		,
	input	[ 1:0]				axim_rresp		,
	input						axim_rlast		,
	input						axim_rvalid		,
	output						axim_rready		,

	output						axim_awuser		,
	output						axim_wuser		,
	input						axim_buser		,
	output						axim_aruser		,
	input						axim_ruser		
);

	// read command mux
	wire arsel, arrdy, rsel, rval;
	axi_hpmux_cmdch_arbiter i_arcmd_arb (
		.aclk		(	aclk			),
		.aresetn	(	aresetn			),
		.req		(	{axis2_arvalid, axis1_arvalid}	),
		.ack		(	axim_arready & axim_arvalid	),
		.sel		(	arsel			)	
	);	

	assign	axim_araddr			=	arsel? axis2_araddr		: axis1_araddr		;
	assign	axim_arlen			=	arsel? axis2_arlen		: axis1_arlen		;
	assign	axim_arsize			=	arsel? axis2_arsize		: axis1_arsize		;
	assign	axim_arburst		=	arsel? axis2_arburst	: axis1_arburst		;
	assign	axim_arlock			=	arsel? axis2_arlock		: axis1_arlock		;
	assign	axim_arcache		=	arsel? axis2_arcache	: axis1_arcache		;
	assign	axim_arprot			=	arsel? axis2_arprot		: axis1_arprot		;
	assign	axim_arvalid		=	arrdy & (arsel? axis2_arvalid	: axis1_arvalid);
	assign	axim_arid			=	arsel? axis2_arid		: axis1_arid		;
	
	assign	axim_aruser			=	arsel? axis2_aruser		: axis1_aruser		;
	assign	axis1_arready		=	(arsel==1)? 0 			: axim_arready		;
	assign	axis2_arready		=	(arsel==0)? 0 			: axim_arready		;
	
	// read response mux
	axi_hpmux_datch_arbiter i_ardat_arb (
		.aclk		(	aclk		),
		.aresetn	(	aresetn		),
		.iport		(	arsel		),
		.ival		(	axim_arvalid & axim_arready	),
		.irdy		(	arrdy		),
		.oport		(	rsel		),
		.oval		(	rval		),
		.ordy       (	axim_rvalid & axim_rlast & axim_rready	)
	);
	
	assign	axim_rready			=	rval & (rsel? axis2_rready	: axis1_rready );
	assign	axis1_rvalid		=	rval & axim_rvalid & ~rsel;
	assign	axis2_rvalid		=	rval & axim_rvalid &  rsel;
	
	assign	axis1_rid			=	axim_rid		;
	assign	axis1_rdata			=	axim_rdata		;
	assign	axis1_rresp			=	axim_rresp		;
	assign	axis1_rlast			=	axim_rlast		;
	assign	axis1_ruser			=	axim_ruser		;
	
	assign	axis2_rid			=	axim_rid		;
	assign	axis2_rdata			=	axim_rdata		;
	assign	axis2_rresp			=	axim_rresp		;
	assign	axis2_rlast			=	axim_rlast		;
	assign	axis2_ruser			=	axim_ruser		;

	// write command mux
	wire awsel, awrdy, wsel, wval, abrdy, bsel, bval;
	axi_hpmux_cmdch_arbiter i_awcmd_arb (
		.aclk		(	aclk			),
		.aresetn	(	aresetn			),
		.req		(	{axis2_awvalid, axis1_awvalid}	),
		.ack		(	axim_awready & axim_awvalid	),
		.sel		(	awsel			)	
	);	
	
	assign	axim_awaddr			=	awsel? axis2_awaddr		:	axis1_awaddr	;
	assign	axim_awlen			=	awsel? axis2_awlen		:	axis1_awlen		;
	assign	axim_awsize			=	awsel? axis2_awsize		:	axis1_awsize	;
	assign	axim_awburst		=	awsel? axis2_awburst	:	axis1_awburst	;
	assign	axim_awid			=	awsel? axis2_awid		:	axis1_awid		;
	assign	axim_awlock			=	awsel? axis2_awlock		:	axis1_awlock	;
	assign	axim_awcache		=	awsel? axis2_awcache	:	axis1_awcache	;
	assign	axim_awprot			=	awsel? axis2_awprot		:	axis1_awprot	;
	assign	axim_awuser			=	awsel? axis2_awuser		:	axis1_awuser	;
	assign	axim_awvalid		=	abrdy & (awsel? axis2_awvalid	:	axis1_awvalid	);
	
	assign	axis1_awready		=	axim_awready & ~awsel;
	assign	axis2_awready		=	axim_awready &  awsel;

	// write data mux
	axi_hpmux_datch_arbiter i_awdat_arb (
		.aclk		(	aclk		),
		.aresetn	(	aresetn		),
		.iport		(	awsel		),
		.ival		(	axim_awvalid & axim_awready	),
		.irdy		(	awrdy		),
		.oport		(	wsel		),
		.oval		(	wval		),
		.ordy       (	axim_wvalid & axim_wlast & axim_wready	)
	);

	assign	axim_wvalid	  = wval & (wsel? axis2_wvalid	: axis1_wvalid );
	assign	axim_wid			=	wsel? axis2_wid		: axis1_wid		;
	assign	axim_wuser			=	wsel? axis2_wuser	: axis1_wuser	;
	assign	axim_wdata			=	wsel? axis2_wdata	: axis1_wdata	;
	assign	axim_wstrb			=	wsel? axis2_wstrb	: axis1_wstrb	;
	assign	axim_wlast			=	wsel? axis2_wlast	: axis1_wlast	;
	
	assign	axis1_wready		=	wval & axim_wready & ~wsel;
	assign	axis2_wready		=	wval & axim_wready &  wsel;

	// write resp mux
	axi_hpmux_datch_arbiter i_awrsp_arb (
		.aclk		(	aclk		),
		.aresetn	(	aresetn		),
		.iport		(	awsel		),
		.ival		(	axim_awvalid & axim_awready	),
		.irdy		(	abrdy		),
		.oport		(	bsel		),
		.oval		(	bval		),
		.ordy       (	axim_bvalid & axim_bready	)
	);

	assign	axim_bready			=	bval & (bsel? axis2_bready : axis1_bready);
	assign	axis1_bvalid		=	axim_bvalid	& bval & ~bsel;
	assign	axis2_bvalid		=	axim_bvalid	& bval &  bsel;
	
	assign	axis1_bid			=	axim_bid		;
	assign	axis1_bresp			=	axim_bresp		;
	assign	axis1_buser			=	axim_buser		;

	assign	axis2_bid			=	axim_bid		;
	assign	axis2_bresp			=	axim_bresp		;
	assign	axis2_buser			=	axim_buser		;
	
endmodule



module axi_hpmux_cmdch_arbiter (
	input		aclk		,
	input 		aresetn		,
	input [1:0]	req			,
	input		ack			,
	output	reg	sel	= 0		
);

	always @(posedge aclk)
		if (~aresetn) begin
			sel	<= 0 ;
		end else begin
			if (sel) begin
				if (req[1]) begin
					sel <= ack? req[0]? 0 : 1 : 1;
				end else begin
					if (req[0])
						sel <= 0;
				end
			end else begin
				if (req[0]) begin
					sel <= ack? req[1]? 1 : 0 : 0;
				end else begin
					if (req[1])
						sel <= 1;
				end
			end
		end

endmodule


module axi_hpmux_datch_arbiter (
	input		aclk		,
	input 		aresetn		,
	input 		iport		,
	input		ival		,
	output		irdy		,
	output reg  oport		,
	output reg	oval	=0	,
	input		ordy
);

	wire afull, empty, re, q;
	assign irdy = ~afull;
	assign re = oval? ordy & ~empty : ~empty;
	
	always @(posedge aclk)
		if (~aresetn) begin
			oval <= 0;
		end else begin
			oval <= oval? ordy? re : oval : re;
		end

	always @(posedge aclk)
		if (re)
			oport <= q;
		
	sc_fifo_ffmem #(
	//sc_fifo_usram #(
		.P_WIDTH		(	 1	), //FIFO data width
		.P_LOG2SIZE		(	 2	), //FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY		(	 1	), //aempty = usedw < P_AEMPTY
		.P_AFULL		(	 2	), //afull = usedw >= P_AFULL
		.P_PPROTECT		(	 1	), //pointer overflow protection  
		.P_SHOWAHEAD	(	 1	)  //1 - showahead, 0 - synchronous
	) i_r_cmd (
		.aclr	(	1'b0		),
		.sclr	(	~aresetn	),
		.clock	(	aclk		),
		.data	(	iport		),
		.rdreq	(	re			),
		.wrreq	(	ival		),
		.aempty	(				),
		.empty	(	empty		),
		.afull	(	afull		),
		.full	(				),
		.usedw	(				),
		.q		(	q			)
	);		
		
endmodule
