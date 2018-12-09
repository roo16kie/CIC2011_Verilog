module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
input clk;
input reset;
input [7:0] IROM_Q;
input [3:0] cmd;
input cmd_valid;
output reg IROM_EN;
output reg [5:0] IROM_A;
output reg IRB_RW;
output reg [7:0] IRB_D;
output reg [5:0] IRB_A;
output reg busy;
output reg done;


/////////////
//PARAMETER//
/////////////

parameter RESET = 2'b00 ;
parameter CMD = 2'b01 ;
parameter OP = 2'b11 ;
parameter WRITE = 2'b10 ;

/////////////////////
//define somethings//
/////////////////////

reg CMD_sig , OP_sig , WRITE_sig , op_reg ;
wire  op_valid ;
wire [9:0] total ;
reg [3:0] reg_cmd ;
wire [5:0] point1,point2,point3;
reg [5:0] point0 ;
reg [2:0] state_cs ;
reg [2:0] state_ns ;
reg [5:0] counter ;
reg [7:0] buffer_in [63:0] ;
reg [7:0] reg0 , reg1 , reg2 , reg3 ;

////////////
///Design///
////////////

assign op_valid = IROM_EN & busy & IRB_RW ;
assign total = (buffer_in[point1] + buffer_in[point2] + buffer_in[point3] + buffer_in[point0]);
assign point1 = point0 + 6'd1 ;
assign point2 = point0 + 6'd8 ;
assign point3 = point0 + 6'd9 ;

always@(*)
begin
	if(reg_cmd==4'h9)
	begin
			if(buffer_in[point0]>8'd191)
				reg0 = 8'd255;
			else 
				reg0 = buffer_in[point0] + 8'd64;	
			if(buffer_in[point1]>8'd191)
				reg1 = 8'd255;
			else 
				reg1 = buffer_in[point1] + 8'd64;
			if(buffer_in[point2]>8'd191)
				reg2 = 8'd255;
			else 
				reg2 = buffer_in[point2] + 8'd64;
			if(buffer_in[point3]>8'd191)
				reg3 = 8'd255;
			else 
				reg3 = buffer_in[point3] + 8'd64;				
	end
	else if(reg_cmd==4'hA)  
	begin
			if(buffer_in[point0]<8'd64)
				reg0 = 8'd0;
			else 
				reg0 = buffer_in[point0] - 8'd64;	
				
			if(buffer_in[point1]<8'd64)
				reg1 = 8'd0;
			else 
				reg1 = buffer_in[point1] - 8'd64;
				
			if(buffer_in[point2]<8'd64)
				reg2 = 8'd0;
			else 
				reg2 = buffer_in[point2] - 8'd64;
			if(buffer_in[point3]<8'd64)
				reg3 = 8'd0;
			else 
				reg3 = buffer_in[point3] - 8'd64;				
	end
	else
	begin reg0 =8'd0 ; reg1 =8'd0 ; reg2 =8'd0 ; reg3 =8'd0 ; end
end


always@(negedge clk)
begin
	if(op_valid)
		op_reg <= op_valid ;
	else
		op_reg <= 0 ;
end

always@(negedge clk or posedge reset)  //current state
begin
	if(reset)
		state_cs <= RESET ;
	else
		state_cs <= state_ns ;
end

always@(*)                             //Control signal
begin

	case(state_ns)
	RESET: begin
			IROM_EN = 0 ; busy = 1 ; IRB_RW = 1 ; 
		   end
	CMD:   begin
			IROM_EN = 1 ; busy = 0 ; IRB_RW = 1 ; 
		   end
	OP:    begin
			IROM_EN = 1 ; busy = 1 ; IRB_RW = 1 ; 	
	       end
	WRITE: begin
			IROM_EN = 1 ; busy = 1 ; IRB_RW = 0 ; 	
           end	
	default: begin IROM_EN = 0 ; busy = 1 ; IRB_RW = 1 ;  end
	endcase
end

always@(*)							   //next state
begin
	case(state_cs)
	RESET: begin
			if(CMD_sig)
				state_ns = CMD ;
			else	
				state_ns = RESET ;
		   end
		   
	CMD:   begin
			if(OP_sig)
				state_ns = OP ;
			else if(WRITE_sig)
				state_ns = WRITE ;
			else
				state_ns = CMD ;
		   end
		   
	OP:    begin
			if(CMD_sig)
				state_ns = CMD	;
			else if(WRITE_sig)
				state_ns = WRITE ;
			else
				state_ns = OP ;
		   end
		   
	WRITE: state_ns = WRITE ;
		   
	default: state_ns = RESET ;
	
	endcase
end


// RESET
always@(negedge clk or posedge reset)  //IROM_A
begin
	if (reset)
		IROM_A <= 6'd0 ;
	else if(!IROM_EN)
		begin
			if(IROM_A == 6'd63)
			IROM_A <= 6'd0 ;
			else
			IROM_A <= IROM_A + 6'd1 ;
		end
end

always@(negedge clk)           //CMD_sig
begin 
	if(IROM_A == 6'd63)
		CMD_sig <= 1 ;
	else if(op_valid==1&&cmd!=4'h0)
		CMD_sig <= 1 ;
	else
		CMD_sig <= 0 ;
end

always@(negedge clk)                  //buffer_in 
begin
	if(!IROM_EN)
		buffer_in[IROM_A] <= IROM_Q ;	
	else if (op_valid||op_reg)
	begin
		if(reg_cmd==4'h5)                            // average
		begin
			buffer_in[point0] <= total[9:2] ; buffer_in[point1] <= total[9:2] ; buffer_in[point2] <= total[9:2] ; buffer_in[point3] <= total[9:2] ;
		end
		else if(reg_cmd==4'h6)                       // X
		begin
			buffer_in[point0] <= buffer_in[point2] ; buffer_in[point1] <= buffer_in[point3] ; 
			buffer_in[point2] <= buffer_in[point0] ; buffer_in[point3] <= buffer_in[point1] ;
		end
		else if(reg_cmd==4'h7)                      // Y
		begin
			buffer_in[point0] <= buffer_in[point1] ; buffer_in[point1] <= buffer_in[point0] ; 
			buffer_in[point2] <= buffer_in[point3] ; buffer_in[point3] <= buffer_in[point2] ;			
		end
		else if(reg_cmd==4'h9)                      // enhance
		begin
			buffer_in[point0] <= reg0 ;
			buffer_in[point1] <= reg1 ;
			buffer_in[point2] <= reg2 ;
			buffer_in[point3] <= reg3 ;
		end
		else if(reg_cmd==4'hA)                       // decrease
		begin
			buffer_in[point0] <= reg0 ;
			buffer_in[point1] <= reg1 ;
			buffer_in[point2] <= reg2 ;
			buffer_in[point3] <= reg3 ;
		end	
		else if(reg_cmd==4'hB)                         //threshold
		begin
			if(buffer_in[point0]<=8'd128)
				buffer_in[point0] <= 8'd0;
			else 
				buffer_in[point0] <= 8'd255;	
			if(buffer_in[point1]<=8'd128)
				buffer_in[point1] <= 8'd0;
			else 
				buffer_in[point1] <= 8'd255;
			if(buffer_in[point2]<=8'd128)
				buffer_in[point2] <= 8'd0;
			else 
				buffer_in[point2] <= 8'd255;
			if(buffer_in[point3]<=8'd128)
				buffer_in[point3] <= 8'd0;
			else 
				buffer_in[point3] <= 8'd255;							
		end
		else if(reg_cmd==4'hC)                           // inverse threshold
		begin
			if(buffer_in[point0]<8'd128)
				buffer_in[point0] <= 8'd255;
			else 
				buffer_in[point0] <= 8'd0 ;
				
			if(buffer_in[point1]<8'd128)
				buffer_in[point1] <= 8'd255;
			else 
				buffer_in[point1] <= 8'd0;
			if(buffer_in[point2]<8'd128)
				buffer_in[point2] <= 8'd255;
			else 
				buffer_in[point2] <= 8'd0;
			if(buffer_in[point3]<8'd128)
				buffer_in[point3] <= 8'd255;
			else 
				buffer_in[point3] <= 8'd0	;						
		end
	end
end

//CMD
always@(negedge clk)                  //OP_sig & WRITE_sig
begin
	if(cmd_valid)
	begin
		if(cmd==4'h0)
		begin WRITE_sig <= 1 ; OP_sig <= 0 ; end
		else
		begin WRITE_sig <= 0 ; OP_sig <= 1 ; end
	end
	else
		begin WRITE_sig <= 0 ; OP_sig <= 0 ; end
end

always@(negedge clk)                  //reg_cmd
begin
	if(cmd_valid)
		reg_cmd <= cmd ;
	else
		reg_cmd <= 4'hD ;
end

//operational point
always@(negedge clk) 
begin
	if(reset)
	point0 <= 6'd27 ;
	else if(op_valid||op_reg)
	begin
		if(reg_cmd==4'h1)
		begin
			if(point0>6'd7)
			point0 <= point0 - 6'd8; 
		end
		else if(reg_cmd==4'h2)
		begin
			if(point0<6'd48)
			point0 <= point0 + 6'd8 ;
		end
		else if(reg_cmd==4'h3)
		begin
			if(point0==6'd0||point0==6'd8||point0==6'd16||point0==6'd24||point0==6'd32||point0==6'd40||point0==6'd48||point0==6'd56)
			point0 <= point0 ; 
			else
			point0 <= point0 - 6'd1 ; 
		end
		else if(reg_cmd==4'h4)
		begin
			if(point0==6'd7||point0==6'd15||point0==6'd23||point0==6'd31||point0==6'd39||point0==6'd47||point0==6'd55||point0==6'd63)
			point0 <= point0 ; 
			else
			point0 <= point0 + 6'd1 ; 
		end
		else if(reg_cmd==4'h8)
			point0 <= 6'd27 ;
	end
end

//WRITE
always@(negedge clk)                 //IRB_A
begin
	if(!IRB_RW)
		IRB_A <= counter ;
end

always@(negedge clk)
begin
	if(!IRB_RW)
		if(counter<6'd63)
		counter <= counter + 6'd1 ;
		else
		begin
		counter <= counter ;
		end
	else
		counter <= 6'd0;
end


always@(negedge clk)                 //IRB_D
begin
	if(!IRB_RW)
		IRB_D <= buffer_in [counter] ;
end


always@(negedge clk)
begin
	if(IRB_A==6'd63)
	done <= 1 ;
	else
	done <= 0 ;
end


endmodule

