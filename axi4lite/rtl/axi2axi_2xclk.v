//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple 1x clock to 2x clock sync bridge for AXI4
//----------------------------------------------------------------------------

module axi2axi_2xclk #(
	parameter P_PASSTHROUGH = 0,
	parameter P_AXI_IDWIDTH = 5
)(
	input						aclk			,
	input						aclkx2			, // aclk and aclkx2 must be synchronous
	input						aresetn			, // asynchronous reset internally synchronized to aclkx2
	// AXI Slave inetrface1 - aclk domain
	input	[31:0]				axis_awaddr		,
	input	[ 7:0]				axis_awlen		,
	input	[ 2:0]				axis_awsize		,
	input	[ 1:0]				axis_awburst	,
	input	[P_AXI_IDWIDTH-1:0]	axis_awid		,
	input						axis_awlock		,
	input	[3:0]				axis_awcache	,
	input	[2:0]				axis_awprot		,
	input						axis_awvalid	,
	output						axis_awready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis_wid		,
	input	[63:0]				axis_wdata		,
	input	[ 7:0]				axis_wstrb		,
	input						axis_wlast		,
	input						axis_wvalid		,
	output						axis_wready		,

	output	[P_AXI_IDWIDTH-1:0]	axis_bid		,
	output	[ 1:0]				axis_bresp		,
	output						axis_bvalid		,
	input						axis_bready		,
	
	input	[P_AXI_IDWIDTH-1:0]	axis_arid		,
	input	[31:0]				axis_araddr		,
	input	[ 3:0]				axis_arlen		,
	input	[ 2:0]				axis_arsize		,
	input	[ 1:0]				axis_arburst	,
	input						axis_arlock		,
	input	[3:0]				axis_arcache	,
	input	[2:0]				axis_arprot		,
	input						axis_arvalid	,
	output						axis_arready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axis_rid		,
	output	[63:0]				axis_rdata		,
	output	[ 1:0]				axis_rresp		,
	output						axis_rlast		,
	output						axis_rvalid		,
	input						axis_rready		,

	input						axis_awuser		,
	input						axis_wuser		,
	output						axis_buser		,
	input						axis_aruser		,
	output						axis_ruser		,

	// AXI Master inetrface - output aclkx2 domain
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

	reg r_ireset = 1, iresetn_meta = 0;
	wire ireset = r_ireset;
	always @(posedge aclkx2) begin
		iresetn_meta <= aresetn;
		r_ireset <= ~iresetn_meta;
	end
	

	wire phase;
	clk_sync_phase #(P_PASSTHROUGH) i_clk_sync_phase (.clk(aclk),.clk_2x(aclkx2),.falling(phase));
	
	// AXI Write Address channel
	assign	axim_awaddr		= axis_awaddr	;
	assign	axim_awlen		= axis_awlen	;
	assign	axim_awsize		= axis_awsize	;
	assign	axim_awburst	= axis_awburst	;
	assign	axim_awid		= axis_awid		;
	assign	axim_awlock		= axis_awlock	;
	assign	axim_awcache	= axis_awcache	;
	assign	axim_awprot		= axis_awprot	;
	assign	axim_awuser		= axis_awuser	;

	reg axim_awvalid_gate = 0;
	always @(posedge aclkx2) axim_awvalid_gate <= phase & axis_awvalid & axim_awready & ~(axim_awvalid_gate | ireset);
	assign	axim_awvalid	= axis_awvalid & (P_PASSTHROUGH? 1'b1 : ~axim_awvalid_gate);
	assign	axis_awready	= P_PASSTHROUGH? axim_awready : axim_awvalid_gate | axim_awready;
	
	//AXI Write Data channel
	assign	axim_wid	=	axis_wid	;
	assign	axim_wdata	=	axis_wdata	;
	assign	axim_wstrb	=	axis_wstrb	;
	assign	axim_wlast	=	axis_wlast	;
	assign	axim_wuser	=	axis_wuser	;
	reg axim_wvalid_gate = 0;
	always @(posedge aclkx2) axim_wvalid_gate <= phase & axis_wvalid & axim_wready & ~(axim_wvalid_gate | ireset);
	assign	axim_wvalid	= axis_wvalid & (P_PASSTHROUGH? 1'b1 : ~axim_wvalid_gate);
	assign	axis_wready	= P_PASSTHROUGH? axim_wready : axim_wvalid_gate | axim_wready;
	
	
	// AXI Write Data Response channel - response channels need to go through FIFO
	wire axim_brespff_empty;
	wire axim_brespff_full;
	wire [P_AXI_IDWIDTH+3-1:0] axim_brespff_q;
	
	sc_fifo_ffmem #(
		.P_WIDTH		(	P_AXI_IDWIDTH+2+1	),	//FIFO data width
		.P_LOG2SIZE		(	1	),	//FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY		(	1	),	//aempty = usedw < P_AEMPTY
		.P_AFULL		(	1	),	//afull = usedw >= P_AFULL
		.P_PPROTECT		(	1	),	//pointer overflow protection
		.P_SHOWAHEAD	(	1	)	//1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem_bresp (
		.aclr	(	1'b0		),
		.sclr	(	ireset		),
		.clock	(	aclkx2		),
		.data	(	{axim_buser, axim_bid, axim_bresp}	),
		.rdreq	(	P_PASSTHROUGH? 1'b0 : ~phase		),
		.wrreq	(	P_PASSTHROUGH? 1'b0 : axim_bready & axim_bvalid	),
		.aempty	(		),
		.empty	(	axim_brespff_empty	),
		.afull	(		),
		.full	(	axim_brespff_full	),
		.usedw	(		),
		.q		(	axim_brespff_q	)
	);

	assign axis_bresp = P_PASSTHROUGH? axim_bresp : axim_brespff_q[1:0];
	assign axis_bid   = P_PASSTHROUGH? axim_bid   : axim_brespff_q[P_AXI_IDWIDTH+2-1:2];
	assign axis_buser = P_PASSTHROUGH? axim_buser : axim_brespff_q[P_AXI_IDWIDTH+3-1];

	assign axis_bvalid= P_PASSTHROUGH? axim_bvalid : ~axim_brespff_empty;
	assign axim_bready= P_PASSTHROUGH? axis_bready : ~axim_brespff_full; //axis_bready & axim_brespff_empty;

	// AXI Read Address channel
	assign axim_arid	= axis_arid		;
	assign axim_araddr	= axis_araddr	;
	assign axim_arlen	= axis_arlen	;
	assign axim_arsize	= axis_arsize	;
	assign axim_arburst	= axis_arburst	;
	assign axim_arlock	= axis_arlock	;
	assign axim_arcache	= axis_arcache	;
	assign axim_arprot	= axis_arprot	;
	assign axim_aruser	= axis_aruser	;
	
	reg axim_arvalid_gate = 0;
	always @(posedge aclkx2) axim_arvalid_gate <= phase & axis_arvalid & axim_arready & ~(axim_arvalid_gate | ireset);
	assign	axim_arvalid	= axis_arvalid & (P_PASSTHROUGH? 1'b1 : ~axim_arvalid_gate);
	assign	axis_arready	= P_PASSTHROUGH? axim_arready : axim_arvalid_gate | axim_arready;
	
	
	// AXI Read Data channel - response channels need to go through FIFO
	wire axim_rrespff_empty;
	wire axim_rrespff_full;
	wire [64+1+2+P_AXI_IDWIDTH+1-1:0] axim_rrespff_q;
	
	//sc_fifo_ffmem #(
	sc_fifo_usram #(
		.P_WIDTH		(	64+1+2+P_AXI_IDWIDTH+1	),	//FIFO data width
		.P_LOG2SIZE		(	4	),	//FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY		(	1	),	//aempty = usedw < P_AEMPTY
		.P_AFULL		(	1	),	//afull = usedw >= P_AFULL
		.P_PPROTECT		(	1	),	//pointer overflow protection
		.P_SHOWAHEAD	(	1	)	//1 - showahead, 0 - synchronous
	) i_sc_fifo_rresp (
		.aclr	(	1'b0		),
		.sclr	(	ireset		),
		.clock	(	aclkx2		),
		.data	(	{axim_ruser, axim_rid, axim_rresp, axim_rlast, axim_rdata}	),
		.rdreq	(	P_PASSTHROUGH? 1'b0 : axis_rready & ~phase		),
		.wrreq	(	P_PASSTHROUGH? 1'b0 : axim_rready & axim_rvalid	),
		.aempty	(		),
		.empty	(	axim_rrespff_empty	),
		.afull	(		),
		.full	(	axim_rrespff_full	),
		.usedw	(		),
		.q		(	axim_rrespff_q		)
	);

	assign axis_rdata	= P_PASSTHROUGH?	axim_rdata	: axim_rrespff_q[0 +: 64];
	assign axis_rlast	= P_PASSTHROUGH?	axim_rlast	: axim_rrespff_q[64+0 +: 1];
	assign axis_rresp	= P_PASSTHROUGH?	axim_rresp	: axim_rrespff_q[64+1 +: 2];
	assign axis_rid		= P_PASSTHROUGH?	axim_rid	: axim_rrespff_q[64+3 +: P_AXI_IDWIDTH];
	assign axis_ruser	= P_PASSTHROUGH?	axim_ruser	: axim_rrespff_q[64+3+P_AXI_IDWIDTH +: 1];

	assign axis_rvalid= P_PASSTHROUGH? axim_rvalid : ~axim_rrespff_empty;
	assign axim_rready= P_PASSTHROUGH? axis_rready : ~axim_rrespff_full;
	

endmodule
