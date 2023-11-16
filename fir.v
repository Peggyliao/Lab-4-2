`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
	
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
//w
    output  wire                     arready,
	
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
	
    output  wire                     rvalid,
    output  reg  [(pDATA_WIDTH-1):0] rdata,   
//R
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
	
    output  wire                     ss_tready, 
//slave
    input   wire                     sm_tready, 
	
    output  reg                      sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  reg                      sm_tlast, 
//master    
	
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire  [(pDATA_WIDTH-1):0] tap_Di,
    output  wire  [(pADDR_WIDTH-1):0] tap_A,
    input   wire  [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg  [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n,

    input   wire                     wb_valid
);

	wire [(pADDR_WIDTH-1):0]addr;
	wire [(pDATA_WIDTH-1):0]ap_ctrl;

	wire wen,awen,ren,aren;
	reg [(pDATA_WIDTH-1):0]data_length;
	reg [(pDATA_WIDTH-1):0]sys_cnt;
	reg [(pDATA_WIDTH-1):0]fir_out;
	wire [(pDATA_WIDTH-1):0]data;
	reg [(pADDR_WIDTH-1):0]data_ptr,tap_ptr,output_cnt,offset,input_cnt;

	reg ap_done;
	reg ap_start;
	reg ap_idle;
	reg ap_start_flag;
	wire ap_x;
	wire ap_y;

	//AXI Lite enable
	assign wen=(wvalid&wready)?1'b1:1'b0;
	assign awen=(awvalid&awready)?1'b1:1'b0;
	assign ren=(rvalid&rready)?1'b1:1'b0;
	assign aren=(arvalid&arready)?1'b1:1'b0;

	//AXI Lite signal
	assign wready=(wvalid)?1'b1:1'b0;
	assign awready=(awvalid)?1'b1:1'b0;
	assign rvalid=((!wvalid)&(!wready))?1'b1:1'b0;
	assign arready=((!wvalid)&(!wready))?1'b1:1'b0;

	//addr for config reg
	assign addr=(awen|awaddr==12'h80)?awaddr:(aren|araddr==12'h84)?araddr:12'hff;

	//tap RAM
	assign tap_WE=((wen&awen)&((awaddr>=12'h40)))?4'b1111:4'b0000;
	assign tap_EN=(((wen&awen)|(ren&aren))&((addr>=12'h40))|(ap_start))?1'b1:1'b0;
	assign tap_Di=(wen&((awaddr>=12'h40)))?wdata:tap_Di;
	assign tap_A=(tap_EN)?(!ap_start)?addr[5:0]:tap_ptr:tap_A;

	//data RAM
	always@(posedge axis_clk)begin
		if(ss_tready)begin
			data_WE<=4'b1111;
		end
		else begin
			data_WE<=4'b0000;
		end
	end

	assign data_EN=(ss_tvalid&ss_tready|(!ss_tlast)|ap_start)?1'b1:1'b0;
	assign data_Di=(data_EN)?ss_tdata:data_Di;
	assign data_A=(data_EN)?(~ap_start)?12'h00:data_ptr:12'd40;

	//situation need to maintain
	wire maintain;

	assign maintain = (ss_tready) ? 1'b0 :
				  (data_WE==4'b1111) ? 1'b1 :
				  (maintain_cnt!=4'b0)? 1'b0 : 1'b1;

	reg [3:0] maintain_cnt;

	always@(posedge axis_clk)begin
		if(axis_rst_n)begin
			maintain_cnt<=4'b0;
		end
		else if(output_cnt==32'd11&&input_cnt!=32'b0)begin
			maintain_cnt<=4'b0;
		end
		else if(ss_tready)begin
			maintain_cnt<=4'b1;
		end
		else if(maintain_cnt>=4'b1)begin
			maintain_cnt<=maintain_cnt+1;
		end

	end

	//ap_start
	always@(posedge axis_clk)begin
		if(axis_rst_n)begin
			ap_start<=1'b0;
			ap_start_flag<=1'b0;
		end
		else if((awaddr==12'h00)&&(wdata[0]==1'b1)&&(ap_start_flag==1'b0))begin
			ap_start<=1'b1;
			ap_start_flag<=1'b1;
		end
		else if(ap_start_flag==1'b1)begin
			ap_start<=1'b1;
		end
		else begin
			ap_start<=1'b0;
		end
	end

	//data_length
	always@(posedge axis_clk)begin
		if(wen&awen&(awaddr==12'h10))begin
			data_length<=wdata;
		end
		else begin
			data_length<=data_length;
		end
	end

	//ap_done & sm_tlast
	always@(posedge axis_clk)begin
		if(axis_rst_n)begin
			sys_cnt<=32'd0;
			ap_done<=1'b0;
			sm_tlast<=1'b0;
		end
		else if(sys_cnt==32'd7200)begin
			sys_cnt<=sys_cnt;
			ap_done<=1'b1;
			sm_tlast<=1'b1;
		end
		else if(ap_start&&!maintain) begin
			sys_cnt<=sys_cnt+32'b1;
			ap_done<=1'b0;
			sm_tlast<=1'b0;
		end
	end

	//ap_idle
	always@(posedge axis_clk)begin
		if(axis_rst_n)begin
			ap_idle<=1'b1;
		end
		else if(ap_start)begin
			ap_idle<=1'b0;
		end
		else if(ap_done)begin
			ap_idle<=1'b1;
		end
		else begin
			ap_idle<=1'b1;
		end
	end
	
	assign ap_x = (input_cnt==32'd0&&addr==12'h00)?1'b1:
				  (tap_ptr==32'h28&&addr==12'h00)?1'b1:1'b0;
	assign ap_y = (sm_tvalid);
	
	assign ap_ctrl={27'd0,ap_y,ap_x,ap_idle,ap_done,ap_start};

	//AXI Lite Read
	always@(*)begin
		if(ren&aren)begin
			if(araddr==12'h00)begin
				rdata<=ap_ctrl;
			end
			else if(araddr>=12'h40)begin
				rdata<=tap_Do;
			end
			else begin
				rdata<=rdata;
			end
		end
	end
	
	//data RAM to data
	assign data =((output_cnt>1)&(output_cnt<=input_cnt+12'd1))?data_Do:32'd0;

	//fir operation
	always@(posedge axis_clk)begin
		if(ap_idle|ss_tready)begin
			fir_out<=32'd0;
		end
		else if(ap_start&&!maintain)begin
			fir_out<=fir_out+data*tap_Do;
		end
		else begin
			fir_out<=fir_out;
		end
	end

	//sm_tdata
	assign sm_tdata=(sm_tvalid&sm_tready)?fir_out:sm_tdata;
	
	//tap_ptr
	always@(posedge axis_clk)begin
		if(tap_ptr==12'd0|ss_tready)begin
			tap_ptr<=12'h28;
		end
		else if(ap_start&&!maintain)begin
			tap_ptr<=tap_ptr-12'd4;
		end
		else begin
			tap_ptr<=12'h28;
		end
	end

	always@(posedge axis_clk)begin
		if(~ap_start)begin
			output_cnt<=12'd0;
			sm_tvalid<=1'b0;
		end
		else if(maintain)begin
			output_cnt<=output_cnt;
		end
		else if(output_cnt>12'd10)begin
			output_cnt<=12'd0;
			sm_tvalid<=1'b1;
		end
		else begin
			output_cnt<=output_cnt+12'd1;
			sm_tvalid<=1'b0;
		end
	end

	assign ss_tready = !ss_chk&&(addr==12'h80)&&wb_valid;

	reg ss_chk;

	always@(posedge axis_clk)begin
		if(addr==12'h80)begin
			ss_chk<=1'b1;
		end
		else begin
			ss_chk<=1'b0;
		end
	end	

	always@(posedge axis_clk)begin
		if((axis_rst_n)|(offset>12'd10))begin
			offset<=12'd0;
		end
		else if(ss_tready)begin
			offset<=offset+12'd1;
		end
		else begin
			offset<=offset;
		end
	end
	
	always@(posedge axis_clk)begin
		if(~ap_start)begin
			data_ptr<=12'h28;
		end
		else if(ss_tready)begin
			data_ptr<=12'h28-offset*4;
		end
		else if(maintain)begin
			data_ptr<=data_ptr;
		end
		else if(data_ptr<12'h28)begin
			data_ptr<=data_ptr+12'd4;
		end
		else begin
			data_ptr<=12'h0;
		end
	end

	always@(posedge axis_clk)begin
		if(axis_rst_n)begin
			input_cnt<=12'd0;
		end
		else if(ss_tready)begin
			input_cnt<=input_cnt+12'd1;
		end
		else if(input_cnt>12'd11)begin
			input_cnt<=input_cnt;
		end
		else begin
			input_cnt<=input_cnt;
		end
	end

endmodule
