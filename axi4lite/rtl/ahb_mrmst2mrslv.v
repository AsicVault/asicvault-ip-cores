//----------------------------------------------------------------------------
// Description : simple feed-through to help connecting master to slave directly
//----------------------------------------------------------------------------

module ahb_mrmst2mrslv (
	//AHB Mirrored Master (input)
	input	[31:0]	ahb_slv_haddr		,
	input	[ 1:0]	ahb_slv_htrans		,
	input			ahb_slv_hwrite		,
	input	[ 2:0]	ahb_slv_hsize		,
	input	[ 2:0]	ahb_slv_hburst		,
	input	[ 3:0]	ahb_slv_hprot		,
	input	[31:0]	ahb_slv_hwdata		,
	input			ahb_slv_hlock		,
	output	[31:0]	ahb_slv_hrdata		,
	output			ahb_slv_hready		,
	output	[ 1:0]	ahb_slv_hresp		,

	//AHB Mirrored Slave (output)
	output	[31:0]	ahb_mslv_haddr		,
	output	[ 1:0]	ahb_mslv_htrans		,
	output			ahb_mslv_hwrite		,
	output	[ 2:0]	ahb_mslv_hsize		,
	output	[ 2:0]	ahb_mslv_hburst		,
	output	[ 3:0]	ahb_mslv_hprot		,
	output	[31:0]	ahb_mslv_hwdata		,
	output			ahb_mslv_hlock		,
	output			ahb_mslv_hsel		,
	output			ahb_mslv_hready		,
	input	[31:0] 	ahb_mslv_hrdata		,
	input			ahb_mslv_hreadyout	,
	input	[ 1:0]	ahb_mslv_hresp		
);

	assign	ahb_mslv_haddr		=	ahb_slv_haddr		;
	assign	ahb_mslv_htrans		=	ahb_slv_htrans		;
	assign	ahb_mslv_hwrite		=	ahb_slv_hwrite		;
	assign	ahb_mslv_hsize		=	ahb_slv_hsize		;
	assign	ahb_mslv_hburst		=	ahb_slv_hburst		;
	assign	ahb_mslv_hprot		=	ahb_slv_hprot		;
	assign	ahb_mslv_hwdata		=	ahb_slv_hwdata		;
	assign	ahb_mslv_hlock		=	ahb_slv_hlock		;
	assign	ahb_mslv_hsel		=	1'b1				;
	assign	ahb_mslv_hready		=	ahb_mslv_hreadyout	;

	assign	ahb_slv_hrdata		=	ahb_mslv_hrdata		;
	assign	ahb_slv_hready		=	ahb_mslv_hreadyout	;
	assign	ahb_slv_hresp		=	ahb_mslv_hresp		;

endmodule

