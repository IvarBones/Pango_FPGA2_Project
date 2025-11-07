module binarization(
    input               clk             ,   
    input               rst_n           ,   

    input               vsync_in        ,   // 输入场同步
    input               hsync_in        ,   // 输入行同步
    input               de_in           ,   // 输入数据有效
    input   [7:0]       y_in            ,   // 输入亮度数据
    input   [7:0]       bin_threshold   ,   // 新增：二值化动态阈值（来自按键控制）

    output              vsync_out       ,   // 输出场同步（延迟1拍）
    output              hsync_out       ,   // 输出行同步（延迟1拍）
    output              de_out          ,   // 输出数据有效（延迟1拍）
    output   reg        pix                // 二值化结果
);

// 寄存器定义（同步信号用）
reg    vsync_in_d;
reg    hsync_in_d;
reg    de_in_d   ;

// 输出同步信号（与二值化结果对齐，延迟1拍）
assign  vsync_out = vsync_in_d  ;
assign  hsync_out = hsync_in_d  ;
assign  de_out    = de_in_d     ;

// 二值化逻辑（使用动态阈值）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        pix <= 1'b0;
    else if(de_in)  // 仅在数据有效时处理
        pix <= (y_in > bin_threshold) ? 1'b1 : 1'b0;  // 动态阈值判断
    else
        pix <= 1'b0;  // 无效数据输出0
end

// 同步信号延迟1拍（与二值化结果时序对齐）
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vsync_in_d <= 1'd0;
        hsync_in_d <= 1'd0;
        de_in_d    <= 1'd0;
    end
    else begin
        vsync_in_d <= vsync_in;
        hsync_in_d <= hsync_in;
        de_in_d    <= de_in   ;
    end
end

endmodule