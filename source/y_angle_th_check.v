// ------------------------------
// 基于《教程1_硬件实验指导手册》修正：rst_in→rst_n（解决未声明错误）
// 符合开发板低电平复位特性（手册核心板复位电路说明）
// ------------------------------
module y_angle_th_check#(
    parameter Y_DATA_WID    = 11,    // y_data位宽（0~479，匹配480行）
    parameter ANGLE_DATA_WID= 7,     // angle位宽（0~127）
    parameter TH_WID        = 8      // 阈值位宽
)(
    input                               clk             ,
    input                               rst_n           ,
    input           [Y_DATA_WID-1:0]    y_data          ,
    input           [ANGLE_DATA_WID-1:0]angle_data      ,
    input           [TH_WID-1:0]        y_min           ,
    input           [TH_WID-1:0]        y_max           ,
    input           [TH_WID-1:0]        angle_th        ,
    input                               vs_in           ,
    input                               de_in           ,
    output reg                          y_th_flag       ,
    output reg                          angle_th_flag   ,
    output reg                          vs_out          ,
    output reg                          de_out
);

// 扩展位宽保持一致性
reg [23:0] y_data_ext;
reg [23:0] y_min_ext;
reg [23:0] y_max_ext;
reg [23:0] angle_data_ext;
reg [23:0] angle_th_ext;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_data_ext     <= 24'd0;
        y_min_ext      <= 24'd0;
        y_max_ext      <= 24'd0;
        angle_data_ext <= 24'd0;
        angle_th_ext   <= 24'd0;
    end else begin
        y_data_ext     <= {{24-Y_DATA_WID{1'b0}}, y_data};
        y_min_ext      <= {{24-TH_WID{1'b0}}, y_min};
        y_max_ext      <= {{24-TH_WID{1'b0}}, y_max};
        angle_data_ext <= {{24-ANGLE_DATA_WID{1'b0}}, angle_data};
        angle_th_ext   <= {{24-TH_WID{1'b0}}, angle_th};
    end
end

// 阈值判断（关键修正：de_in=0 时清零标志）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_th_flag     <= 1'b0;
        angle_th_flag <= 1'b0;
    end else begin
        if (de_in) begin
            y_th_flag     <= (y_data_ext < y_min_ext) || (y_data_ext > y_max_ext);
            angle_th_flag <= (angle_data_ext > angle_th_ext) || (angle_data_ext == 90);
        end else begin
            y_th_flag     <= 1'b0;  // ★ 修正点：无效区域清零，避免误触发
            angle_th_flag <= 1'b0;
        end
    end
end

// 同步输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vs_out <= 1'b0;
        de_out <= 1'b0;
    end else begin
        vs_out <= vs_in;
        de_out <= de_in;
    end
end

endmodule
