//----------------------------------------------------------------------------
// Description : simple feed-through to help connecting slave to mirrored slave with 2x clk crossing
//----------------------------------------------------------------------------

module ahb_slv2mrslv_clk2x #(parameter P_PASSTHROUGH = 0) (
	input			clk					,
	input			clk_2x				,
	input			resetn				, // asynchronous active low reset, internally synchronized
	//AHB Slave (input)
	input	[31:0]	ahb_inp_haddr		,
	input	[ 1:0]	ahb_inp_htrans		,
	input			ahb_inp_hwrite		,
	input	[ 2:0]	ahb_inp_hsize		,
	input	[ 2:0]	ahb_inp_hburst		,
	input	[ 3:0]	ahb_inp_hprot		,
	input	[31:0]	ahb_inp_hwdata		,
	input			ahb_inp_hlock		,
	input			ahb_inp_hsel		,
	input			ahb_inp_hready		,
	output	[31:0]	ahb_inp_hrdata		,
	output			ahb_inp_hreadyout	,
	output	[ 1:0]	ahb_inp_hresp		,

	//AHB Mirrored Slave (output)
	output	[31:0]	ahb_out_haddr		,
	output	[ 1:0]	ahb_out_htrans		,
	output			ahb_out_hwrite		,
	output	[ 2:0]	ahb_out_hsize		,
	output	[ 2:0]	ahb_out_hburst		,
	output	[ 3:0]	ahb_out_hprot		,
	output	[31:0]	ahb_out_hwdata		,
	output			ahb_out_hlock		,
	output			ahb_out_hsel		,
	output			ahb_out_hready		,
	input	[31:0] 	ahb_out_hrdata		,
	input			ahb_out_hreadyout	,
	input	[ 1:0]	ahb_out_hresp		
);
	wire falling;
	reg active = 0;
	reg resp = 0;
	reg [31:0] r_ahb_out_hrdata;
	
	reg iresetn = 0, iresetn_meta = 0; 

	generate if (P_PASSTHROUGH) begin
		assign	ahb_out_haddr		=	ahb_inp_haddr		;
		assign	ahb_out_htrans		=	ahb_inp_htrans		;
		assign	ahb_out_hwrite		=	ahb_inp_hwrite		;
		assign	ahb_out_hsize		=	ahb_inp_hsize		;
		assign	ahb_out_hburst		=	ahb_inp_hburst		;
		assign	ahb_out_hprot		=	ahb_inp_hprot		;
		assign	ahb_out_hwdata		=	ahb_inp_hwdata		;
		assign	ahb_out_hlock		=	ahb_inp_hlock		;
		assign	ahb_out_hsel		=	ahb_inp_hsel		;
		assign	ahb_out_hready		=	ahb_inp_hreadyout	;

		assign	ahb_inp_hrdata		=	ahb_out_hrdata		;
		assign	ahb_inp_hreadyout	=	ahb_out_hreadyout	;
		assign	ahb_inp_hresp		=	ahb_out_hresp		;
	end else begin
		clk_sync_phase #(P_PASSTHROUGH) i_clk_sync_phase (.clk(clk),.clk_2x(clk_2x),.falling(falling));
		always @(posedge clk_2x) begin
			iresetn_meta <= resetn;
			iresetn <= iresetn_meta;
		end
		
		
		assign	ahb_out_haddr		=	ahb_inp_haddr		;
		assign	ahb_out_htrans		=	ahb_inp_htrans & ~{active | (falling & ahb_inp_hwrite), active | (falling & ahb_inp_hwrite)};
		assign	ahb_out_hwrite		=	ahb_inp_hwrite		;
		assign	ahb_out_hsize		=	ahb_inp_hsize		;
		assign	ahb_out_hburst		=	ahb_inp_hburst		;
		assign	ahb_out_hprot		=	ahb_inp_hprot		;
		assign	ahb_out_hwdata		=	ahb_inp_hwdata		;
		assign	ahb_out_hlock		=	ahb_inp_hlock		;
		assign	ahb_out_hsel		=	ahb_inp_hsel		;
		assign	ahb_out_hready		=	1'b1				;

		assign	ahb_inp_hrdata		=	resp? r_ahb_out_hrdata	: 	ahb_out_hrdata;
		assign	ahb_inp_hreadyout	=	ahb_out_hreadyout	| resp;
		assign	ahb_inp_hresp		=	0		;
		
		
		always @(posedge clk_2x)
			if (~iresetn) begin
				active <= 0;
				resp <= 0;
			end else begin
				resp <= 0;
				if (~active) begin
					if ((ahb_inp_hwrite? ~falling : falling) & ahb_inp_htrans[1] & ahb_inp_hreadyout & ahb_inp_hready & ahb_inp_hsel) begin
						active <= 1'b1;
					end
				end else begin
					if (ahb_out_hreadyout) begin
						active <= 1'b0;
						resp <= falling;
					end
				end
			end

		always @(posedge clk_2x)
			if (active)
				r_ahb_out_hrdata <= ahb_out_hrdata;
		
	end endgenerate

endmodule

