`timescale 1ns/1ns
module defect_four_points_no_error_tb();

// -------------------------- 信号定义 --------------------------
reg                     pixclk_in;       // 像素时钟
reg                     rst_n;           // 复位（低有效）
reg                     bin2_vs;         // 场同步信号
reg                     bin2_de;         // 数据有效信号
reg                     bin2_data;       // 二值化输入数据（1=瑕疵，0=背景）
reg [7:0]               cnt;             // 计数器，用于控制时序

// 模块输出信号
wire [10:0]             defect_p1_x;     // 顶点1-X（x_min）
wire [10:0]             defect_p1_y;     // 顶点1-Y
wire [10:0]             defect_p2_x;     // 顶点2-X（x_max）
wire [10:0]             defect_p2_y;     // 顶点2-Y
wire [10:0]             defect_p3_x;     // 顶点3-X
wire [10:0]             defect_p3_y;     // 顶点3-Y（y_min）
wire [10:0]             defect_p4_x;     // 顶点4-X
wire [10:0]             defect_p4_y;     // 顶点4-Y（y_max）
wire                    defect_valid;    // 瑕疵有效标志
wire                    point_vs;        // 延迟场同步
wire                    point_de;        // 延迟数据有效

// -------------------------- 初始化与时钟生成 --------------------------
initial begin
    pixclk_in    <= 1'd0;
    rst_n        <= 1'd0;
    bin2_vs      <= 1'd0;
    bin2_de      <= 1'd0;
    bin2_data    <= 1'd0;
    cnt          <= 8'd0;

    #20  // 复位20ns后释放
    rst_n <= 1'd1;
end

// 50MHz像素时钟（周期10ns），与matrix_tb保持一致
always #10 pixclk_in = ~pixclk_in;

// -------------------------- 计数器控制时序 --------------------------
// 计数器循环计数（0~19），用于生成数据有效和场同步信号
always @(posedge pixclk_in or negedge rst_n) begin
    if (!rst_n)
        cnt <= 8'd0;
    else if (cnt >= 8'd19)  // 计数到19后清零，周期20*10ns=200ns
        cnt <= 8'd0;
    else
        cnt <= cnt + 1'b1;
end

// -------------------------- 生成输入信号 --------------------------
// 1. 场同步信号bin2_vs：每帧开始时（cnt=0）拉高1个时钟周期
always @(posedge pixclk_in or negedge rst_n) begin
    if (!rst_n)
        bin2_vs <= 1'd0;
    else
        bin2_vs <= (cnt == 8'd0) ? 1'd1 : 1'd0;  // 帧起始标记
end

// 2. 数据有效信号bin2_de：cnt=1~15期间有效（模拟有效图像区域）
always @(posedge pixclk_in or negedge rst_n) begin
    if (!rst_n)
        bin2_de <= 1'd0;
    else if (cnt >= 8'd1 && cnt <= 8'd15)  // 有效数据窗口
        bin2_de <= 1'd1;
    else
        bin2_de <= 1'd0;
end

// 3. 二值化瑕疵数据bin2_data：模拟一个矩形瑕疵区域
// 瑕疵位置：在有效数据窗口内，cnt=3~10（列方向）且行计数器（低3位）=1~3（行方向）
reg [2:0] row_cnt;  // 行计数器（0~7循环，模拟图像行）
always @(posedge pixclk_in or negedge rst_n) begin
    if (!rst_n) begin
        row_cnt <= 3'd0;
        bin2_data <= 1'd0;
    end else begin
        // 行计数器：每帧（20个时钟）循环一次
        row_cnt <= (cnt == 8'd19) ? row_cnt + 1'b1 : row_cnt;

        // 瑕疵区域：行1~3，列3~10（bin2_data=1）
        if (bin2_de) begin  // 仅数据有效时生成瑕疵
            bin2_data <= (row_cnt >= 3'd1 && row_cnt <= 3'd3) 
                      && (cnt >= 8'd3 && cnt <= 8'd10) ? 1'd1 : 1'd0;
        end else begin
            bin2_data <= 1'd0;
        end
    end
end

// -------------------------- 实例化被测试模块 --------------------------
// 仿真用小尺寸图像（5x5），加快仿真速度
defect_four_points_no_error#(
    .IMG_WIDTH    (11'd5),    // 图像宽度5（列0~4）
    .IMG_HEIGHT   (11'd5),    // 图像高度5（行0~4）
    .COORD_WID    (11),       // 坐标位宽11
    .DELAY_CYCLES (1)         // 延迟周期1
) u_defect_four_points_no_error (
    .pixclk_in    (pixclk_in),
    .rstn_out     (rst_n),
    .bin2_vs      (bin2_vs),
    .bin2_de      (bin2_de),
    .bin2_data    (bin2_data),
    .defect_p1_x  (defect_p1_x),
    .defect_p1_y  (defect_p1_y),
    .defect_p2_x  (defect_p2_x),
    .defect_p2_y  (defect_p2_y),
    .defect_p3_x  (defect_p3_x),
    .defect_p3_y  (defect_p3_y),
    .defect_p4_x  (defect_p4_x),
    .defect_p4_y  (defect_p4_y),
    .defect_valid (defect_valid),
    .point_vs     (point_vs),
    .point_de     (point_de)
);

endmodule