/**
 * 	tbAccl.sv
 *
 * 	Created	:	27 Nov 2019
 * 	Author	:	Abhishek Bhaumick
 * 	
 */

`timescale 1 ns / 1 ns

import AcceleratorPackage::*;

module tbAccl();

	reg clk;
	reg reset;

	wire rdEn;
	wire wrEn;
	wire [AddressBitWidth-1:0]	addr;
	wire [DataBitWidth-1:0]		wrData;
	wire [DataBitWidth-1:0]		rdData;

	AcceleratorTopMod accl
	(

		.clk(clk),		// Clock
		.reset(reset),	// Asynchronous reset active low

		.ReadEnIn(rdEn),
		.WriteEnIn(wrEn),

		.AddressIn(addr),
		.DataIn(wrData),
		.DataOut(rdData)
	
	);

	loadTest tbLd
	(
		.clk(clk),		// Clock
		.reset(reset),	// Asynchronous reset active low

		.ReadEnIn(rdEn),
		.WriteEnIn(wrEn),

		.AddressIn(addr),
		.DataIn(wrData),
		.DataOut(rdData)
	);

	initial begin
		$display( "Starting testbench" );
		clk = 0;
		reset = 1;
		#100
		reset = 0;
	end

	always #5 clk = ~clk;

endmodule	// tbAccl

program loadTest (
	input  logic	clk,
	input  logic	reset,

	output logic	ReadEnIn,
	output logic	WriteEnIn,

	output logic [AddressBitWidth-1:0]	AddressIn,
	output logic [DataBitWidth-1:0]		DataIn,
	input  logic [DataBitWidth-1:0]		DataOut

	);


	task automatic writeData;
		input int writeAddr;
		input int writeData;
	begin
		@(posedge clk);
		WriteEnIn	<= 1;
		ReadEnIn	<= 0;
		AddressIn	<= writeAddr;
		DataIn		<= writeData;
	end
	endtask	//automatic

	task automatic busIdle;
	begin
		@(posedge clk);
		WriteEnIn	<= 0;
		ReadEnIn	<= 0;
		AddressIn	<= 0;
		DataIn		<= 0;
	end
	endtask	//automatic

	initial begin

		WriteEnIn	<= 0;
		ReadEnIn	<= 0;
		AddressIn	<= 0;
		DataIn		<= 0;

		#10
		wait (reset == 0);

		@(posedge clk);
		@(posedge clk);

		for ( int i=0; i<NumFilterCoeffs; i++ ) begin
			writeData( (AddrOffsetCoeff + i), i+1 );
		end

		busIdle();

		#20

		$display("Reset");
		writeData( AddrOffsetControl, 0 );
		busIdle();

		#20

		for ( int i=0; i<NumFilterCoeffs; i++ ) begin
			writeData( (AddrOffsetCoeff + i), i+1 );
		end
		busIdle();

		for (int i = 0; i <64; i++) begin
			writeData( AddrOffsetData, 32'h0100_0000 + i );
		end
		busIdle();

		#100000;
	end

endprogram

