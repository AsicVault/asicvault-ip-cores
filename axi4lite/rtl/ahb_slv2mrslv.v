//----------------------------------------------------------------------------
// Description : a simple feed-through component with address masking and 
//             : basing
//----------------------------------------------------------------------------

module ahb_slv2mrslv (
	//AHB Slave (slave)
	input	[31:0]	ahb_slv_haddr		,
	input	[ 1:0]	ahb_slv_htrans		,
	input			ahb_slv_hwrite		,
	input	[ 2:0]	ahb_slv_hsize		,
	input	[ 2:0]	ahb_slv_hburst		,
	input	[ 3:0]	ahb_slv_hprot		,
	input	[31:0]	ahb_slv_hwdata		,
	input			ahb_slv_hlock		,
	output	[31:0]	ahb_slv_hrdata		,
	output			ahb_slv_hreadyout	,
	output	[ 1:0]	ahb_slv_hresp		,
	input			ahb_slv_hselx		,
	input			ahb_slv_hready		,

	//AHB Mirrored Slave (master)
	output	[31:0]	ahb_mslv_haddr		,
	output	[ 1:0]	ahb_mslv_htrans		,
	output			ahb_mslv_hwrite		,
	output	[ 2:0]	ahb_mslv_hsize		,
	output	[ 2:0]	ahb_mslv_hburst		,
	output	[ 3:0]	ahb_mslv_hprot		,
	output	[31:0]	ahb_mslv_hwdata		,
	output			ahb_mslv_hlock		,
	input	[31:0] 	ahb_mslv_hrdata		,
	input			ahb_mslv_hreadyout	,
	input	[ 1:0]	ahb_mslv_hresp		,
	output			ahb_mslv_hselx		,
	output			ahb_mslv_hready		
);

	parameter P_HREADY_ALWAYS_SET = 0	;
	parameter P_ADDR_MASK = 32'hFFFFFFFF	;
	parameter P_ADDR_BASE = 32'h00000000	;

	assign ahb_mslv_haddr	= (ahb_slv_haddr		 & P_ADDR_MASK) | P_ADDR_BASE;
	assign ahb_mslv_htrans	= ahb_slv_htrans	;
	assign ahb_mslv_hwrite	= ahb_slv_hwrite	;
	assign ahb_mslv_hsize	= ahb_slv_hsize		;
	assign ahb_mslv_hburst	= ahb_slv_hburst	;
	assign ahb_mslv_hprot	= ahb_slv_hprot		;
	assign ahb_mslv_hwdata	= ahb_slv_hwdata	;
	assign ahb_mslv_hlock	= ahb_slv_hlock		;
	assign ahb_mslv_hselx	= ahb_slv_hselx		;
	assign ahb_mslv_hready	= ahb_slv_hready	| P_HREADY_ALWAYS_SET;

	assign ahb_slv_hrdata		= ahb_mslv_hrdata		;
	assign ahb_slv_hreadyout	= ahb_mslv_hreadyout	;
	assign ahb_slv_hresp		= ahb_mslv_hresp		;


endmodule

