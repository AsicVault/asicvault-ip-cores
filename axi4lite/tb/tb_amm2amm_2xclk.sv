`timescale 1 ns / 100 ps

module tb_amm2amm_2xclk;

	parameter P_PASSTHROUGH = 0;
	reg clk2x = 0, clk1x = 0;
	reg reset = 1'b1;

	amm_if #(32,4) f_if(), s_if();
	
	int errors = 0;
	int cmdindx = 0;
	
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
	
	
	
	//amm2amm_2xclk #(P_PASSTHROUGH) dut (
	amm2amm_2xclk_sync dut (
		.clk				(	clk1x	),
		.clk_2x				(	clk2x	),
		.reset				(	reset	), //synchronous active high reset
		.s_address			(	s_if.address			),
		.s_byteenable		(	s_if.byteenable			),
		.s_writedata		(	s_if.writedata			),
		.s_read				(	s_if.read				),
		.s_write			(	s_if.write				),
		.s_waitrequest		(	s_if.waitrequest		),
		.s_readdata			(	s_if.readdata			),
		.m_address			(	f_if.address			),
		.m_byteenable		(	f_if.byteenable			),
		.m_writedata		(	f_if.writedata			),
		.m_read				(	f_if.read				),
		.m_write			(	f_if.write				),
		.m_waitrequest		(	f_if.waitrequest		),
		.m_readdata			(	f_if.readdata			)
	);
	
	
	task generate_check(int n = 10);
		req_t r;
		reg val;
		repeat (n) begin
			r.rnw  = $random;
			r.addr = $random;
			r.data = $random;
			r.be = $random;
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
			$display("%t ns: Init CMD %d, %s", $time/10.0, r.num, r.rnw? "read" : "write");
			@(posedge clk1x);
			while (s_if.waitrequest)
				@(posedge clk1x);
			s_if.read  = 1'b0;
			s_if.write = 1'b0;
			if (r.rnw) begin
				r = resp_que.pop_front();
				$display("%t ns: read Testing CMD %d", $time/10, r.num);
				if (r.data !== s_if.readdata) begin
					$display("%t ns: ERROR: r.data:0x%1X != s.readdata:0x%8X, addr=0x%8X", $time/10.0, r.data, s_if.readdata, r.addr);
					errors++;
				end
				if (r.rnw !== 1'b1) begin
					$display("%t ns: ERROR: r.rnw is write", $time/10.0);
					errors++;
				end
			end 
		end
	endtask
	
	
	task responder (int n = 10);
		req_t r;
		f_if.waitrequest = 1'b1;
		repeat (n) begin
			@(posedge clk2x);
			while (~(f_if.read | f_if.write))
				@(posedge clk2x);
			f_if.waitrequest = ~(($random%3) == 0);
			while (f_if.waitrequest) begin
				@(posedge clk2x);
				f_if.waitrequest = ~(($random%3) == 0);
			end
			if (f_if.read) begin
				r = cmd_que.pop_front();
				r.data = $random;
				f_if.readdata = r.data;
				resp_que.push_back(r);
			end
			@(posedge clk2x);
			if (f_if.write) begin
				r = cmd_que.pop_front();
				$display("%t ns: write Testing CMD %d", $time/10.0, r.num);
				if (r.addr !== f_if.address) begin
					$display("%t ns: ERROR: r.addr:0x%8X != m.addr:0x%8X", $time/10.0, r.addr, f_if.address);
					errors++;
				end
				if (r.be !== f_if.byteenable) begin
					$display("%t ns: ERROR: r.be:0x%1X != m.be:0x%1X", $time/10.0, r.be, f_if.byteenable);
					errors++;
				end
				if (r.data !== f_if.writedata) begin
					$display("%t ns: ERROR: r.data:0x%1X != m.writedata:0x%8X", $time/10.0, r.data, f_if.writedata);
					errors++;
				end
				if (r.rnw !== 1'b0) begin
					$display("%t ns: ERROR: r.rnw is read", $time/10.0);
					errors++;
				end
			end
			f_if.waitrequest = 1'b1;
			f_if.readdata = 0;
		end
	endtask
	
	//test seq
	initial begin
		@(negedge reset);
		@(posedge clk1x);
		fork
			generate_check(10000);
			responder(10000);
		join
		if (errors) begin
			$display("TEST FAILED with %d errors", errors);
		end else begin
			$display("TEST PASSED");
		end
		repeat (10) @(posedge clk1x);
		$stop();
	end
	
endmodule