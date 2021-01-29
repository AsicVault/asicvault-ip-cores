//----------------------------------------------------------------------------
// Description : simple feed-through to help connecting master to slave directly
//----------------------------------------------------------------------------

module ahb_mrmst2mrslv_clk2x #(parameter P_PASSTHROUGH = 0) (
	input			clk					,
	input			clk_2x				,
	input			resetn				,
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

	generate if (P_PASSTHROUGH) begin
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
	end else begin
		wire falling;
		clk_sync_phase #(P_PASSTHROUGH) i_clk_sync_phase (.clk(clk),.clk_2x(clk_2x),.falling(falling));
		reg active = 0;
		reg resp = 0;
		reg [31:0] r_ahb_mslv_hrdata;
		
		reg iresetn = 0, iresetn_meta = 0; 
		always @(posedge clk_2x) begin
			iresetn_meta <= resetn;
			iresetn <= iresetn_meta;
		end	
		
		assign	ahb_mslv_haddr		=	ahb_slv_haddr		;
		assign	ahb_mslv_htrans		=	ahb_slv_htrans & ~{active, active};
		assign	ahb_mslv_hwrite		=	ahb_slv_hwrite		;
		assign	ahb_mslv_hsize		=	ahb_slv_hsize		;
		assign	ahb_mslv_hburst		=	ahb_slv_hburst		;
		assign	ahb_mslv_hprot		=	ahb_slv_hprot		;
		assign	ahb_mslv_hwdata		=	ahb_slv_hwdata		;
		assign	ahb_mslv_hlock		=	ahb_slv_hlock		;
		assign	ahb_mslv_hsel		=	1'b1				;
		assign	ahb_mslv_hready		=	1'b1				;

		assign	ahb_slv_hrdata		=	resp? r_ahb_mslv_hrdata	: 	ahb_mslv_hrdata;
		assign	ahb_slv_hready		=	ahb_mslv_hreadyout	| resp;
		assign	ahb_slv_hresp		=	0		;
		
		
		always @(posedge clk_2x)
			if (~iresetn) begin
				active <= 0;
				resp <= 0;
			end else begin
				resp <= 0;
				if (~active) begin
					if (falling & ahb_slv_htrans[1] & ahb_slv_hready) begin
						active <= 1'b1;
					end
				end else begin
					if (ahb_mslv_hreadyout) begin
						active <= 1'b0;
						resp <= falling;
					end
				end
			end

		always @(posedge clk_2x)
			if (active)
				r_ahb_mslv_hrdata <= ahb_mslv_hrdata;
		
	end endgenerate

endmodule

