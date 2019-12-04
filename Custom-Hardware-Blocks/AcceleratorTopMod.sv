/**
 *	AcceleratorTopMod.sv
 *
 * 	Created	:	26 Nov 2019, 12:44 PM EST
 * 	Author	:	Abhishek Bhaumick
 * 	
 */

import AcceleratorPackage::*;


module AcceleratorTopMod 
#(
	parameter integer AddressWidth	=	10,
	parameter integer DataWidth		=	32
)
(

	input  logic	clk,		// Clock
	input  logic	reset,		// Synchronous reset active low

	input  logic	ReadEnIn,
	input  logic	WriteEnIn,

	input  logic [AddressWidth-1:0]	AddressIn,
	input  logic [DataWidth-1:0]	DataIn,
	output logic [DataWidth-1:0]	DataOut
	
);

	/**********************    Parameters    **********************/

		localparam PxBfrCount = PixelBufferCount;
		localparam PxBfrDepth = PixelBufferDepth;

	//	Wires and Registers
	
		reg  [AddressWidth-2:0] controlReg;
		AcclDataType [FilterRowSize-1:0][BlockCount-1:0][PxBfrCount-1:0] coeffBuffer;
		reg  [BlockCount-1:0]		coeffRdBlockOffset;
		reg  [FilterRowSize-1:0]	coeffRdCellOffset;

		// reg [PxBfrCount-1:0] pxBfrWrSelect;

		wire [AddrRoutingBits-1:0] addrRoute;

		reg cmdReset;

		AcclDataType [PxBfrDepth-1:0][PxBfrCount-1:0] pxBuffer;
		reg  pxBfrWrOvf;
		reg  pxBfrRdEn;
		reg  [clog2(PixelBufferDepth)+clog2(PixelBufferCount)-1:0] pxBfrWrCounter = 0;
		reg  [clog2(PixelBufferDepth)-1:0] pxBfrRdOffset	= 0;
		reg  [clog2(PixelBufferDepth)-1:0] pxBfrDelOffset 	= 0;
		reg  filterRowEnd;
		reg  filterCellEnd;

		MacStateType macState;
		reg  macRdEn;
		reg  macWrEn;
		reg  macInputValid;
		AcclDataType [2*PixelBufferCount-1:0] macInputs;

		reg  [clog2(MacEngineLatency):0] macWaitCounter;
		reg  macWaitEnd;
		reg  [MacEngineLatency:0] macPipeSReg;


	/*******************    Avalon Interface    *******************/

		assign addrRoute	= AddressIn[AddressWidth-1:AddressWidth-AddrRoutingBits];

		always_ff @(posedge clk) begin	:	wrCoeff
			if (reset == 1 || cmdReset == 1) begin
				coeffBuffer <= '{default:32'h0};
			end else begin
				if (WriteEnIn == 1) begin
					if (addrRoute == routeCoeff) begin
						coeffBuffer[AddressIn[6:5]][AddressIn[4:3]][AddressIn[2:0]] <= DataIn;	//	Upto 16 Locations
					end
				end
			end
		end

		always_ff @(posedge clk) begin	:	wrControl
			if (reset == 1) begin
				cmdReset <= 0;
			end else begin
				if (WriteEnIn == 1) begin
					case (AddressIn)
						'h00 :
							cmdReset <= 1;
						default : 
							cmdReset <= 0;
					endcase
				end else begin
					cmdReset <= 0;
				end
			end
		end

		wire [clog2(PixelBufferDepth)-1:0] pxBfrWrOffset = pxBfrWrCounter[clog2(PixelBufferDepth)+clog2(PixelBufferCount)-1:clog2(PixelBufferCount)];
		wire [clog2(PixelBufferCount)-1:0] pxBfrWrSelect = pxBfrWrCounter[clog2(PixelBufferCount)-1:0];
		
		always_ff @(posedge clk) begin	:	wrData
			if (reset == 1 || cmdReset == 1) begin
				pxBuffer <= '{default:32'h0};
				pxBfrWrCounter <= 'h0;
			end else begin
				if (WriteEnIn == 1) begin
					if (addrRoute == routeData) begin
						//LSH with MSB append
						pxBuffer[pxBfrWrOffset][pxBfrWrSelect] <= DataIn;
						pxBfrWrCounter <= pxBfrWrCounter + 1;
					end
				end
			end
		end

		wire [clog2(PixelBufferDepth)-1:0] pxBfrNextWrOffset	= pxBfrWrOffset + 1;
		wire [clog2(PixelBufferDepth)-1:0] pxBfrNextRdOffset	= pxBfrRdOffset + 1;
		wire [clog2(PixelBufferDepth)-1:0] pxBfrNextDelOffset	= pxBfrDelOffset + 1;

		always_latch begin : bfrWrStsFlags
			if (reset == 1 || cmdReset == 1) begin
				pxBfrWrOvf <= 0;
				pxBfrRdEn  <= 0;
			end else begin
				if (pxBfrNextWrOffset == pxBfrRdOffset) begin
					pxBfrWrOvf <= 1;
				end else begin
					pxBfrWrOvf <= 0;
				end
				if (pxBfrRdOffset == pxBfrWrOffset ) begin
					pxBfrRdEn <= 0;
				end else if (pxBfrNextRdOffset == pxBfrWrOffset) begin
					pxBfrRdEn <= 1;
				end
			end
		end

		always_ff @(posedge clk) begin : rdMacInput
			if(reset == 1 || cmdReset == 1) begin
				pxBfrRdOffset		<= 0;
				macInputs			<= '{default:32'h0};
				macInputValid		<= 0;
				coeffRdBlockOffset	<= 0;
				coeffRdCellOffset	<= 0;
			end else begin
				if (macRdEn == 1) begin
					macInputValid	<= 0;
					pxBfrRdOffset	<= pxBfrRdOffset + 1;
					for (int i = 0; i < PxBfrCount; i++) begin
						macInputs[i*2+0] <= pxBuffer[pxBfrRdOffset][i];
						macInputs[i*2+1] <= coeffBuffer[coeffRdCellOffset][coeffRdBlockOffset][i];
					end
				end else begin
					macInputValid	<= 0;
				end
			end
		end

		always_ff @(posedge clk) begin : rdLogic
			if(reset == 1 || cmdReset == 1) begin
				filterCellEnd	<= 0;
				filterRowEnd	<= 0;
			end else begin
				if (macRdEn == 1) begin
					if (coeffRdBlockOffset == BlockCount - 1) begin
						coeffRdBlockOffset	<= 0;
						filterCellEnd		<= 1;
						if (coeffRdCellOffset == FilterRowSize - 1) begin
							coeffRdCellOffset <= 0;
							filterRowEnd <= 1;
						end else begin
							coeffRdCellOffset <= coeffRdCellOffset + 1;
							filterRowEnd <= 0;
						end
					end else begin
						filterCellEnd	<= 0;
						filterRowEnd	<= 0;
						coeffRdBlockOffset <= coeffRdBlockOffset + 1;
					end
				end else begin
					filterCellEnd	<= 0;
					filterRowEnd	<= 0;
				end
			end
		end

	/*******************    MAC State Machine    ******************/


		always_ff @(posedge clk) begin : sm
			if(reset == 1 || cmdReset == 1) begin
				macState	<= s_Idle;
				macRdEn		<= 0;
				macWrEn		<= 0;
			end else begin
				case (macState)
					s_Idle	:	begin
						macWrEn	<= 0;
						if (pxBfrRdEn == 1) begin
							macRdEn <= 1;
							macState <= s_ReadInput;
						end else begin
							macRdEn	<= 0;
						end
					end

					s_ReadInput	:	begin
						macWrEn		<= 0;
						macRdEn		<= 0;
						macState	<= s_WaitForCalc;
					end

					s_WaitForCalc : begin
						macRdEn <= 0;
						if (macWaitEnd == 1) begin
							macState	<= s_ReadResult;
							macWrEn		<= 1;
						end
					end

					s_ReadResult :	begin
						macWrEn		<= 0;
						if (pxBfrRdEn == 1) begin
							macRdEn <= 1;
							macState <= s_ReadInput;
						end else begin
							macRdEn <= 0;
							macState <= s_Idle;
						end
					end

				 	default : begin
				 		macRdEn		<= 0;
				 		macWrEn		<= 0;
				 		macState	<= s_Idle;
				 	end

				 endcase
			end
		end

		always_ff @(posedge clk) begin : macWait
			if (reset==1 || cmdReset ==1) begin
				macWaitCounter	<= 0;
				macWaitEnd		<= 0;
			end else begin
				if (macWaitCounter == 0) begin
					macWaitEnd <= 0;
					if (macRdEn == 1) begin
						macWaitCounter <= MacEngineLatency - 1;
					end
				end else begin
					macWaitCounter <= macWaitCounter - 1;
					if (macWaitCounter == 1) begin
						macWaitEnd <= 1;
					end else begin
						macWaitEnd <= 0;
					end
				end
			end
		end

		always_ff @(posedge clk) begin : macPipe
			if(reset) begin
				macPipeSReg <= 0;
			end else begin
				macPipeSReg <= { macPipeSReg[MacEngineLatency-1:0], 
									macPipeSReg[MacEngineLatency] };
			end
		end


	/**********************    MAC Engine    **********************/

		/*
		datapath mac
		(
			.clk(clk),
			.reset(reset),

			//Pipeline Register Enables
			.stage_1_en(macPipeSReg[0]),
			.stage_2_en(macPipeSReg[1]),
			.stage_3_en(macPipeSReg[2]),
			.stage_4_en(macPipeSReg[3]),

			//MULTIPLY Stage Inputs
			.mul0_in0(macInputs[ 0]), .mul0_in1(macInputs[ 1]),
			.mul1_in0(macInputs[ 2]), .mul1_in1(macInputs[ 3]),
			.mul2_in0(macInputs[ 4]), .mul2_in1(macInputs[ 5]),
			.mul3_in0(macInputs[ 6]), .mul3_in1(macInputs[ 7]),
			.mul4_in0(macInputs[ 8]), .mul4_in1(macInputs[ 9]),
			.mul5_in0(macInputs[10]), .mul5_in1(macInputs[11]),
			.mul6_in0(macInputs[12]), .mul6_in1(macInputs[13]),
			.mul7_in0(macInputs[14]), .mul7_in1(macInputs[15]),

			//Results
			.result(macResult)
		);
		*/

endmodule