
//Generated with: generate_avalon_interconnect.py v2.2
//Date: 22-Aug-2017 10:50:25
//Input: interconnect_spec_eccop.xls

		//MSS Master Input
		.amm_writedata   (    amm_writedata     ),
		.amm_read        (    amm_read          ),
		.amm_address     (    amm_address       ),
		.amm_readdata    (    amm_readdata      ),
		.amm_write       (    amm_write         ),
		.amm_waitrequest (    amm_waitrequest   ),
		.amm_byteenable  (    amm_byteenable    ),
		//Operand Memory
		.dat_writedata   (    dat_writedata     ),
		.dat_read        (    dat_read          ),
		.dat_address     (    dat_address       ), //Size: 16384 = [14-1:0]
		.dat_readdata    (    dat_readdata      ),
		.dat_write       (    dat_write         ),
		.dat_waitrequest (    dat_waitrequest   ),
		.dat_byteenable  (    dat_byteenable    ),
		//Command Memory
		.cod_writedata   (    cod_writedata     ),
		.cod_read        (    cod_read          ),
		.cod_address     (    cod_address       ), //Size: 16384 = [14-1:0]
		.cod_readdata    (    cod_readdata      ),
		.cod_write       (    cod_write         ),
		.cod_waitrequest (    cod_waitrequest   ),
		.cod_byteenable  (    cod_byteenable    ),
		//Control
		.cmd_writedata   (    cmd_writedata     ),
		.cmd_read        (    cmd_read          ),
		.cmd_address     (    cmd_address       ), //Size: 16384 = [14-1:0]
		.cmd_readdata    (    cmd_readdata      ),
		.cmd_write       (    cmd_write         ),
		.cmd_waitrequest (    cmd_waitrequest   ),
		.cmd_byteenable  (    cmd_byteenable    ),
