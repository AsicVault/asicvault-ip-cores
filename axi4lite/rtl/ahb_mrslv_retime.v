//----------------------------------------------------------------------------
// Description : a module to improve bus timing - inserts FFs to address and data paths
//----------------------------------------------------------------------------

module ahb_mrslv_retime (
	input				hclk			,
	input				resetn			, //synchronous active low reset
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
	input			ahb_slv_hsel		, 
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
	output			ahb_mslv_hsel		,
	output			ahb_mslv_hready		
);

	wire [1:0] w_ahb_slv_htrans = ahb_slv_htrans & {(ahb_slv_hsel & ahb_slv_hready), (ahb_slv_hsel & ahb_slv_hready)};

	ahb_master_retime i_ahb_master_retime (
		.hclk				(	hclk				),
		.resetn				(	resetn				), //synchronous active low reset
		//AHB Mirrored Master (slave)
		.ahb_mmst_haddr		(	ahb_slv_haddr		),
		.ahb_mmst_htrans	(	w_ahb_slv_htrans	),
		.ahb_mmst_hwrite	(	ahb_slv_hwrite		),
		.ahb_mmst_hsize		(	ahb_slv_hsize		),
		.ahb_mmst_hburst	(	ahb_slv_hburst		),
		.ahb_mmst_hprot		(	ahb_slv_hprot		),
		.ahb_mmst_hwdata	(	ahb_slv_hwdata		),
		.ahb_mmst_hlock		(	ahb_slv_hlock		),
		.ahb_mmst_hrdata	(	ahb_slv_hrdata		),
		.ahb_mmst_hready	(	ahb_slv_hreadyout	),
		.ahb_mmst_hresp		(	ahb_slv_hresp		),

		//AHB Master (master)
		.ahb_mst_haddr		(	ahb_mslv_haddr			),
		.ahb_mst_htrans		(	ahb_mslv_htrans			),
		.ahb_mst_hwrite		(	ahb_mslv_hwrite			),
		.ahb_mst_hsize		(	ahb_mslv_hsize			),
		.ahb_mst_hburst		(	ahb_mslv_hburst			),
		.ahb_mst_hprot		(	ahb_mslv_hprot			),
		.ahb_mst_hwdata		(	ahb_mslv_hwdata			),
		.ahb_mst_hlock		(	ahb_mslv_hlock			),
		.ahb_mst_hrdata		(	ahb_mslv_hrdata			),
		.ahb_mst_hready		(	ahb_mslv_hreadyout		),
		.ahb_mst_hresp		(	ahb_mslv_hresp			)
	);

	assign ahb_mslv_hsel   = (ahb_mslv_htrans != 2'b00);
	assign ahb_mslv_hready = (ahb_mslv_htrans != 2'b00);

endmodule

