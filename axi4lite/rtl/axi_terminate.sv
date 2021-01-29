//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : AXI4lite slave place-holder module to terminate bus access 
//             : when no actual component is available. Responds with P_RANGE 
//             : reply when read between start and end (including), with 
//             : P_ORANGE otherwise. Write transaction into range creates OK 
//             : response, when out of range DECERR.
//----------------------------------------------------------------------------

module axi4l_terminate #(
	parameter P_START  = 32'h0,         // start address for decoded area
	parameter P_END    = 32'hFFFFFFFF,  // end address for decoded area
	parameter P_ORANGE = 32'h00000000,  // reply for out of range access
	parameter P_RANGE  = 32'h00000000,  // reply for in range access
	parameter P_AMM_MODE = 0
) (
	input						aclk	,
	input						aresetn	,
	//AXI4Lite interface (slave)
	axi_if						axi		,
	amm_if.slave				amm
);

   reg [32-1:0] 				addr = 0;        // $bits(axi.araddr) captured address for compare
   reg 							rd_nwr=1'b0;          // transaction type 
   reg 							addr_valid = 0;  // address within window? 

   enum logic [1:0] {s_idle, s_decode, s_reply} axis = s_idle;

generate if (P_AMM_MODE) begin
	amm2axi #(
		.P_ASIZE  ( 32	), 	//width of the address bus (byte aligned addresses)
		.P_DBYTES ( 4   )	//width of the data bus in bytes
	) i_amm2axi (
		//Avalon MM interface (slave)
		.clk			(	aclk			),
		.reset			(  ~aresetn			),
		.amm_address	(	amm.address		),
		.amm_writedata	(	amm.writedata	),
		.amm_byteenable	(	amm.byteenable	),
		.amm_write		(	amm.write		),
		.amm_read		(	amm.read		),
		.amm_readdata	(	amm.readdata	),
		.amm_waitrequest(	amm.waitrequest	),
		//AXI4Lite interface (master)
		.axi_awaddr		(	axi.awaddr		),
		.axi_awvalid	(	axi.awvalid		),
		.axi_awready	(	axi.awready		),
		.axi_wdata		(	axi.wdata		),
		.axi_wstrb		(	axi.wstrb		),
		.axi_wvalid		(	axi.wvalid		),
		.axi_wready		(	axi.wready		),
		.axi_bready		(	axi.bready		),
		.axi_bvalid		(	axi.bvalid		),
		.axi_bresp		(	axi.bresp		),
		.axi_araddr		(	axi.araddr		),
		.axi_arsize		(	axi.arsize		),
		.axi_arvalid	(	axi.arvalid		),
		.axi_arready	(	axi.arready		),
		.axi_rdata		(	axi.rdata		),
		.axi_rresp		(	axi.rresp		), //input ignored - always valid response expected
		.axi_rvalid		(	axi.rvalid		),
		.axi_rready     (	axi.rready		)
	);
end endgenerate
       
   // axi standard calls for async negative reset
   // currently responses are handled sequentially, write has higher priority
   // if two requests are initiated at the same time then write occurs first
   // followed by read
   
   always @(posedge aclk )
     if ( aresetn == 1'b0 )
       begin
	  // response signals
	  axi.arready <= 1'b0;
	  axi.awready <= 1'b0;
	  axi.rvalid  <= 1'b0;
	  axi.bvalid  <= 1'b0;
	  // state
	  axis        <= s_idle;
	  // read or write transaction
	  rd_nwr <= 1'b0;
	  // captured address
	  addr <= 0;
	  // address within range
	  addr_valid <= 0;	  
       end
     else
       begin
	  axi.arready <= 1'b0;
	  axi.awready <= 1'b0;
	  axi.wready  <= 1'b0;
	  axi.rvalid  <= 1'b0;
	  axi.bvalid  <= 1'b0; 
	case ( axis )
	  s_idle :
	    begin
	       if ( axi.awvalid == 1'b1)
		 begin
		    rd_nwr <= 1'b0;
		    addr   <= axi.awaddr;		 
		    axis   <= s_decode;
		 end
	       else
		 if (axi.arvalid == 1'b1)
		   begin
		      rd_nwr <= 1'b1;
		      addr   <= axi.araddr;
		      axis   <= s_decode;
		   end
		 else
		   axis  <= s_idle;
	    end
	  s_decode:
	    begin
	       axi.arready <= rd_nwr;
	       axi.awready <= ~rd_nwr;
	       axi.wready  <= ~rd_nwr;
	       if ( addr >= P_START && addr <= P_END )
		 addr_valid <= 1'b1;
	       else
		 addr_valid <= 1'b0;
	       axis <= s_reply;	       
	    end
	  s_reply:
	    begin
	       if( rd_nwr ? axi.rready : axi.bready )
		 begin
		    axi.bvalid <=  ~rd_nwr;
		    axi.rvalid <=  rd_nwr;
		    axis <= s_idle;		    
		 end
	       else
		 begin		  
		    axis <= s_reply;		    
		 end			      
	    end
	endcase
     end

   // Responses on read/write channel
   localparam OKAY   = 2'd0;
   localparam DECERR = 2'd3;
   
   // data reply depending on address range
   assign axi.rdata = addr_valid ? P_RANGE : P_ORANGE;
   // responses depending on decode
   assign axi.rresp = addr_valid ? OKAY : DECERR;  
   assign axi.bresp = addr_valid ? OKAY : DECERR;
      

endmodule
