
// A simple module to retime an axi channel

module axi_ch_retime #(
	parameter P_WIDTH = 64+8+5, // width of the data signals
	parameter P_PASSTHROUGH = 0
)(
	input						clk			,
	input						reset		,
	input	[P_WIDTH-1:0]		i_data		,
	input						i_val		,
	output						i_rdy		,
	output	reg	[P_WIDTH-1:0]	o_data		,
	output	reg					o_val		,
	input						o_rdy		
);

	generate if (P_PASSTHROUGH) begin : dummy
		assign o_data = i_data;
		assign o_val = i_val;
		assign i_rdy = o_rdy;
	end else begin
		always @(posedge clk)
			if (i_val & i_rdy)
				o_data <= i_data;
				
		always @(posedge clk)
			if (reset) begin
				o_val <= 1'b0;
			end else begin
				o_val <= o_val? o_rdy? i_val : o_val : i_val;
			end

		 assign i_rdy = o_val? o_rdy : 1'b1;
	end endgenerate

endmodule


//no path from o_rdy ti i_rdy
module axi_ch_retime_slow #(
	parameter P_WIDTH = 64+8+5, // width of the data signals
	parameter P_PASSTHROUGH = 0
)(
	input						clk			,
	input						reset		,
	input	[P_WIDTH-1:0]		i_data		,
	input						i_val		,
	output						i_rdy		,
	output	reg	[P_WIDTH-1:0]	o_data		,
	output	reg					o_val		,
	input						o_rdy		
);
	generate if (P_PASSTHROUGH) begin : dummy
		assign o_data = i_data;
		assign o_val = i_val;
		assign i_rdy = o_rdy;
	end else begin
		always @(posedge clk)
			if (i_val & i_rdy)
				o_data <= i_data;
				
		always @(posedge clk)
			if (reset) begin
				o_val <= 1'b0;
			end else begin
				o_val <= o_val? ~o_rdy : i_val;
			end

		 assign i_rdy = ~o_val;
	end endgenerate 
endmodule
