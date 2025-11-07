module holes_filler(clk,rst,datavalid,pix_in_current,pix_in_previous,left,pix_out);

input clk,rst,datavalid,pix_in_current,pix_in_previous;
output reg left;
output pix_out;

reg top,x,right;


//window
always@(posedge clk or posedge rst) begin
	if(rst)begin
		top<=0;left<=0;
		x<=0;right<=0;
	end
	else if(datavalid)begin
		top<=pix_in_previous;
		left<=x;x<=right;right<=pix_in_current;
	end
end
assign pix_out=(top&(left|right))?1'd1:x;


endmodule
