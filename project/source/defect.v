
module defect#(
    parameter IMG_WIDTH  = 11'd640,   // 图像宽度
    parameter IMG_HEIGHT = 11'd480,   // 图像高度
    parameter COORD_WID  = 11,        // 坐标位宽
    parameter DELAY_CYCLES = 1        // 同步信号延迟周期数（通常为1，与输出锁存同步）
)(
    // 输入信号
    input                     pixclk_in,
    input                     rstn_out,
    input                     bin2_vs,
    input                     bin2_de,
    input                     bin2_data,

    // 输出信号：瑕疵顶点坐标
    output reg [COORD_WID-1:0] defect_p1_x,
    output reg [COORD_WID-1:0] defect_p1_y,
    output reg [COORD_WID-1:0] defect_p2_x,
    output reg [COORD_WID-1:0] defect_p2_y,
    output reg [COORD_WID-1:0] defect_p3_x,
    output reg [COORD_WID-1:0] defect_p3_y,
    output reg [COORD_WID-1:0] defect_p4_x,
    output reg [COORD_WID-1:0] defect_p4_y,
    output reg                 defect_valid,

    // 新增：延迟后的同步信号输出
    output reg                 point_vs,  // 延迟后的场同步
    output reg                 point_de    // 延迟后的数据有效
);

// -------------------------- 1. 内置行列计数器 ---------------------------
reg [COORD_WID-1:0] x_cnt;
reg [COORD_WID-1:0] y_cnt;

always@(posedge pixclk_in or negedge rstn_out) begin
    if(!rstn_out)
        x_cnt <= {COORD_WID{1'b0}};
    else if(x_cnt == IMG_WIDTH - 1'b1)
        x_cnt <= {COORD_WID{1'b0}};
    else if(bin2_de)
        x_cnt <= x_cnt + 1'b1;
    else
        x_cnt <= x_cnt;
end

always@(posedge pixclk_in or negedge rstn_out) begin
    if(!rstn_out)
        y_cnt <= {COORD_WID{1'b0}};
    else if(y_cnt == IMG_HEIGHT - 1'b1 && x_cnt == IMG_WIDTH - 1'b1)
        y_cnt <= {COORD_WID{1'b0}};
    else if(x_cnt == IMG_WIDTH - 1'b1)
        y_cnt <= y_cnt + 1'b1;
    else
        y_cnt <= y_cnt;
end

// -------------------------- 2. 极值检测逻辑 ---------------------------
reg [COORD_WID-1:0] x_min_reg, x_min_y_reg, x_max_reg, x_max_y_reg;
reg [COORD_WID-1:0] y_min_reg, y_min_x_reg, y_max_reg, y_max_x_reg;

always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out || bin2_vs) begin
        x_min_reg    <= IMG_WIDTH - 1'b1;
        x_min_y_reg  <= {COORD_WID{1'b0}};
        x_max_reg    <= {COORD_WID{1'b0}};
        x_max_y_reg  <= {COORD_WID{1'b0}};
        y_min_reg    <= IMG_HEIGHT - 1'b1;
        y_min_x_reg  <= {COORD_WID{1'b0}};
        y_max_reg    <= {COORD_WID{1'b0}};
        y_max_x_reg  <= {COORD_WID{1'b0}};
    end else if (bin2_de && bin2_data == 1'b1) begin
        if (x_cnt < x_min_reg) begin
            x_min_reg   <= x_cnt;
            x_min_y_reg <= y_cnt;
        end
        if (x_cnt > x_max_reg) begin
            x_max_reg   <= x_cnt;
            x_max_y_reg <= y_cnt;
        end
        if (y_cnt < y_min_reg) begin
            y_min_reg   <= y_cnt;
            y_min_x_reg <= x_cnt;
        end
        if (y_cnt > y_max_reg) begin
            y_max_reg   <= y_cnt;
            y_max_x_reg <= x_cnt;
        end
    end
end

// -------------------------- 3. 帧结束锁存与同步信号延迟 ---------------------------
wire frame_end_flag = (x_cnt == IMG_WIDTH - 1'b1) && (y_cnt == IMG_HEIGHT - 1'b1);
wire frame_has_defect = (x_min_reg != IMG_WIDTH - 1'b1) || (x_max_reg != 1'b0);

// 顶点坐标输出寄存器
reg [COORD_WID-1:0] p1_x_reg, p1_y_reg, p2_x_reg, p2_y_reg;
reg [COORD_WID-1:0] p3_x_reg, p3_y_reg, p4_x_reg, p4_y_reg;
reg valid_reg;

// 输出数据锁存（延迟1周期）
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        {p1_x_reg, p1_y_reg, p2_x_reg, p2_y_reg} <= 0;
        {p3_x_reg, p3_y_reg, p4_x_reg, p4_y_reg} <= 0;
        valid_reg <= 0;
    end else if (frame_end_flag) begin
        p1_x_reg <= x_min_reg; p1_y_reg <= x_min_y_reg;
        p2_x_reg <= x_max_reg; p2_y_reg <= x_max_y_reg;
        p3_x_reg <= y_min_x_reg; p3_y_reg <= y_min_reg;
        p4_x_reg <= y_max_x_reg; p4_y_reg <= y_max_reg;
        valid_reg <= frame_has_defect;
    end
end

// 关键新增：同步信号延迟链（使用移位寄存器实现）[3](@ref)
reg [DELAY_CYCLES:0] vs_delay_chain; // 位宽为DELAY_CYCLES+1，便于索引
reg [DELAY_CYCLES:0] de_delay_chain;

always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        vs_delay_chain <= 0;
        de_delay_chain <= 0;
    end else begin
        // 移位寄存器，每个时钟周期将新信号移入，最旧信号移出
        vs_delay_chain <= {vs_delay_chain[DELAY_CYCLES-1:0], bin2_vs};
        de_delay_chain <= {de_delay_chain[DELAY_CYCLES-1:0], bin2_de};
    end
end

// 最终输出赋值（所有信号同步输出）
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out) begin
        {defect_p1_x, defect_p1_y} <= 0;
        {defect_p2_x, defect_p2_y} <= 0;
        {defect_p3_x, defect_p3_y} <= 0;
        {defect_p4_x, defect_p4_y} <= 0;
        defect_valid <= 0;
        point_vs <= 0;
        point_de <= 0;
    end else begin
        // 顶点坐标和有效标志输出
        {defect_p1_x, defect_p1_y} <= {p1_x_reg, p1_y_reg};
        {defect_p2_x, defect_p2_y} <= {p2_x_reg, p2_y_reg};
        {defect_p3_x, defect_p3_y} <= {p3_x_reg, p3_y_reg};
        {defect_p4_x, defect_p4_y} <= {p4_x_reg, p4_y_reg};
        defect_valid <= valid_reg;

        // 同步信号输出（从延迟链的末端取出延迟后的信号）
        point_vs <= vs_delay_chain[DELAY_CYCLES];
        point_de <= de_delay_chain[DELAY_CYCLES];
    end
end

endmodule