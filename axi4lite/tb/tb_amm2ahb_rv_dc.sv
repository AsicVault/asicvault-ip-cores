`timescale 1 ns / 100 ps

function real reftime();
	reftime = $time/10.0;
endfunction


module tb_amm2ahb_rv_dc;

	parameter P_PASSTHROUGH = 0;
	reg clk2x = 0, clk1x = 0;
	reg reset = 1'b1;

	ammrt_if #(32,4) s_if();
	
	logic	[31:0]	ahbm_haddr	;
	logic	[ 1:0]	ahbm_hsize	;
	logic	[ 1:0]	ahbm_htrans;
	logic	[ 2:0]	ahbm_hburst	;
	logic	[31:0]	ahbm_hwdata	;
	logic			ahbm_hwrite	;
	logic			ahbm_hready	= 1;
	logic	[31:0]	ahbm_hrdata	;
	logic			ahbm_hresp	;
	
	
	int errors = 0;
	int cmdindx = 0;
	event e_error;
	
	typedef struct {
		reg [31:0] addr;
		reg [31:0] data;
		reg [3:0]  be;
		reg        rnw;
		int num;
	} req_t;
	
	req_t cmd_que[$], resp_que[$];
	
	always begin
		clk2x <= ~clk2x;
		clk1x <= ~clk1x;
		#5;
		clk2x <= ~clk2x;
		#5;
		clk2x <= ~clk2x;
		clk1x <= ~clk1x;
		#5;
		clk2x <= ~clk2x;
		#5;
	end
	
	initial begin repeat(4) @(posedge clk1x); reset++; end
	
	
	amm2ahb_rv_dc dut (
		.aclk				(	clk1x				),
		.aclk_2x			(	clk2x				),
		.aresetn			(  1'b1					), //asynchronous active low reset
		.sresetn			(  ~reset				), //synchronous active low reset
		.amm_address		(	s_if.address		),
		.amm_writedata		(	s_if.writedata		),
		.amm_byteenable		(	s_if.byteenable		),
		.amm_write			(	s_if.write			),
		.amm_read			(	s_if.read			),
		.amm_readdata		(	s_if.readdata		),
		.amm_readdatavalid	(	s_if.readdatavalid	),
		.amm_waitrequest	(	s_if.waitrequest	),
		//AHB Lite interface (master)
		.ahb_haddr			(	ahbm_haddr		),
		.ahb_hsize			(	ahbm_hsize		),
		.ahb_htrans			(	ahbm_htrans		),
		.ahb_hwdata			(	ahbm_hwdata		),
		.ahb_hwrite			(	ahbm_hwrite		),
		.ahb_hburst			(	ahbm_hburst		),
		.ahb_hrdata			(	ahbm_hrdata		),
		.ahb_hresp			(	ahbm_hresp		),
		.ahb_hready			(	ahbm_hready		)
	);
	
	function bit [3:0] random_be();
		case (($random()&'hF)%7)
			1 : random_be = 4'b0001;
			2 : random_be = 4'b0010;
			3 : random_be = 4'b0100;
			4 : random_be = 4'b1000;
			5 : random_be = 4'b1100;
			6 : random_be = 4'b0011;
			default: random_be = 4'b1111;
		endcase
	endfunction
	
	
	task generate_commands(int n = 10);
		req_t r;
		reg val;
		repeat (n) begin
			r.rnw  = $random;
			r.addr = $random & ~3;
			r.data = $random;
			r.be = random_be();
			r.num = cmdindx++;
			s_if.address    = r.addr;
			s_if.byteenable = r.be;
			s_if.writedata  = r.data;
			val = (($random%3) == 0);
			while (~val) begin
				@(posedge clk1x);
				val = (($random%3) == 0);
			end
			s_if.read  =   r.rnw;
			s_if.write =  ~r.rnw;
			cmd_que.push_back(r);
			$display("%t ns: Init CMD %d, %s", reftime(), r.num, r.rnw? "read" : "write");
			@(posedge clk1x);
			while (s_if.waitrequest)
				@(posedge clk1x);
			s_if.read  = 1'b0;
			s_if.write = 1'b0;
		end
	endtask
	
	// readdata valid checker
	always @(posedge clk1x) begin
		req_t r;
		if (s_if.readdatavalid) begin
			if (resp_que.size() < 1) begin
				$display("%t ns: ERROR: resp_que is empty, unexpected readdatavalid", reftime());
				errors++;
				-> e_error;
			end
			r = resp_que.pop_front();
			if (r.data !== s_if.readdata) begin
				$display("%t ns: ERROR: r.data:0x%8X != s.readdata:0x%8X, addr=0x%8X, cmd=%d", reftime(), r.data, s_if.readdata, r.addr, r.num);
				errors++;
				-> e_error;
			end else begin
				$display("%t ns: Testing CMD %d readdata pass", reftime(), r.num);
			end
			if (r.rnw !== 1'b1) begin
				$display("%t ns: ERROR: r.rnw is write, unexpected readdatavalid", reftime());
				errors++;
				-> e_error;
			end
		end
	end
	
	
	task check_ahb_cmd(req_t expected, req_t bus);
		if ((bus.addr & ~3) !== (expected.addr & ~3)) begin
			$display("%t ns: ERROR: AHB addr:0x%8X != expected:0x%8X cmd=%d", reftime(), bus.addr, expected.addr, expected.num);
			errors++;
			-> e_error;
		end
		if ((bus.be) !== (expected.be)) begin
			$display("%t ns: ERROR: AHB derived be:%4b != expected:%04b cmd=%d", reftime(), bus.be, expected.be, expected.num);
			errors++;
			-> e_error;
		end
		if ((bus.rnw) !== (expected.rnw)) begin
			$display("%t ns: ERROR: AHB rnw:%b != expected rnw:%b cmd=%d", reftime(), bus.rnw, expected.rnw, expected.num);
			errors++;
			-> e_error;
		end
	endtask
	
	/*
	localparam [2:0] tBYTE  = 3'b000;	// 8 Byte
	localparam [2:0] tHWORD = 3'b001;	// 16 Halfword
	localparam [2:0] tWORD  = 3'b010;	// 32 Word
	localparam [2:0] tDWORD = 3'b011;	// 64 Doubleword
	*/
	
	function bit [3:0] size2be(input [1:0] addr_lsb, input [2:0] hsize);
		size2be = 4'b0000; // incorrect value by default
		case (hsize)
			3'b000: begin
				size2be = 4'b0001;
				case (addr_lsb)
					2'd1: size2be = size2be << 1;
					2'd2: size2be = size2be << 2;
					2'd3: size2be = size2be << 3;
				endcase
			end
			3'b001: begin
				size2be = 4'b0011;
				case (addr_lsb)
					2'd1: size2be = size2be << 4; // incorrect value
					2'd2: size2be = size2be << 2;
					2'd3: size2be = size2be << 4; // incorrect value
				endcase
			end
			3'b010: begin
				size2be = 4'b1111;
				case (addr_lsb)
					2'd1: size2be = size2be << 4; // incorrect value
					2'd2: size2be = size2be << 4; // incorrect value
					2'd3: size2be = size2be << 4; // incorrect value
				endcase
			end
		endcase
	endfunction
	
	
	
	//ahb responder
	reg ihready = 0;
	reg do_check_ahb_cmd;
	always @(posedge clk2x) begin
		req_t c, r;
		do_check_ahb_cmd = 0;
		ahbm_hrdata <= 0;
		if (ihready & ahbm_hready) begin
			ihready <= 0;
			if (~r.rnw) begin
				if (r.data !== ahbm_hwdata) begin
					$display("%t ns: ERROR: AHB wdata:0x%8X != expected:0x%8X cmd=%d", reftime(), ahbm_hwdata, r.data, r.num);
					errors++;
					-> e_error;
				end else begin
					$display("%t ns: Testing CMD %d hwdata pass", reftime(), r.num);
				end
			end
		end
		if (ihready) begin
			if (~ahbm_hready) begin
				if ($random() & 1) begin
					ahbm_hready <= 1'b1;
					if (c.rnw) begin
						c.data = $random();
						ahbm_hrdata <= c.data;
						resp_que.push_back(c);
					end
				end
			end
		end
		if (ahbm_htrans[1]) begin
			if (~ihready) begin
				ihready <= 1'b1;
				do_check_ahb_cmd = 1;
			end else begin
				ihready <= ahbm_hready;
				do_check_ahb_cmd = ahbm_hready;
			end
		end
		if (do_check_ahb_cmd) begin
			if (cmd_que.size() < 1) begin
				$display("%t ns: ERROR: cmd_que is empty, unexpected ahbm_htrans", reftime());
				errors++;
				-> e_error;
			end
			r = cmd_que.pop_front();
			c.addr = ahbm_haddr;
			c.rnw  = ~ahbm_hwrite;
			c.be = size2be(ahbm_haddr[1:0], ahbm_hsize);
			c.num  = r.num;
			check_ahb_cmd(r, c);
			if ($random() & 1) begin
				ahbm_hready <= 1'b1;
				if (c.rnw) begin
					c.data = $random();
					ahbm_hrdata <= c.data;
					resp_que.push_back(c);
				end
			end else begin
				ahbm_hready <= 1'b0;
			end
		end
	end
	
	
	//test seq
	initial begin
		s_if.write <= 0;
		s_if.read <= 0;
		@(negedge reset);
		@(posedge clk1x);
		fork
			generate_commands(10000);
			begin
				@(e_error);
			end
		join_any
		if (errors) begin
			$display("TEST FAILED with %d errors", errors);
		end else begin
			$display("TEST PASSED");
		end
		repeat (10) @(posedge clk1x);
		$stop();
	end
	
endmodule