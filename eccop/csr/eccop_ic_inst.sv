
	eccop_ic #(30, 4) inst_eccop_ic (

		`include "eccop_ic_connections.svh"
		//Clock and Reset
		.sreset(	reset),
		.areset(	 1'b0),
		.clk(		clk)
	);
