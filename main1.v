//MEM2048X24.v already include in tb
//you dont have to include here
// v - new - 02:36
// 建議把註解換掉 跟別人的有點太像了
module HDL_final(
    input clk,
    input rst_n,
    input [26:0] DPi,
    input CC,
    input TP,
    input IM,
    input IG,
    input UM,
    input [7:0] Brig,
    input [2:0] Sync_CC,
    input [2:0] Sync_TP,
    input [2:0] Sync_IM,
    input [2:0] Sync_IG,
    input [2:0] Sync_UM,

    output reg[26:0] DPo
  );

  // 內部暫存器和計數器
  reg Den_last, Den_last2;
  reg [11:0] v_cnt;
  reg [11:0] h_cnt;

  // RGB 和 YUV 信號定義
  wire [7:0] R, G, B, Y, U, V, R_temp, G_temp, B_temp, Y_old;
  reg [7:0] r, g, b;
  reg signed [10:0] YY;

  // Y 值飽和處理
  assign Y = (YY > 255) ? 255 : (YY < 0) ? 0 : YY;

  // RGB 輸入信號分配
  assign R = DPi[23:16];
  assign G = DPi[15:8];
  assign B = DPi[7:0];

  // Step1: 影像下半部轉化為負片模式
  assign R_temp = (v_cnt <= 540) ? R : 255 - R;
  assign G_temp = (v_cnt <= 540) ? G : 255 - G;
  assign B_temp = (v_cnt <= 540) ? B : 255 - B;

  // Step2: RGB2YUV 轉換
  wire signed [17:0] y_temp = R_temp * 10'd77 + G_temp * 10'd150 + B_temp * 10'd29;
  wire signed [17:0] u_temp = R_temp * -10'sd43 + G_temp * -10'sd85 + B_temp * 10'sd128 + (128 <<< 8);
  wire signed [17:0] v_temp = R_temp * 10'sd128 + G_temp * -10'sd107 + B_temp * -10'sd21 + (128 <<< 8);

  assign Y_old = (y_temp + 8'd128) >>> 8;
  assign U = (u_temp + 8'd128) >>> 8;
  assign V = (v_temp + 8'd128) >>> 8;

  // YUV2RGB 轉換係數 (Q2.8 格式)
  localparam signed [10:0] C_RV =  11'sd359;   // +1.13983 * 256
  localparam signed [10:0] C_GU = -11'sd88;    // -0.39465 * 256
  localparam signed [10:0] C_GV = -11'sd183;   // -0.58060 * 256
  localparam signed [10:0] C_BU =  11'sd453;   // +2.03211 * 256

  // (U-128) / (V-128) 偏移計算
  wire signed [8:0] U_off = $signed({1'b0, U}) - 9'sd128;   // -128 ~ +127
  wire signed [8:0] V_off = $signed({1'b0, V}) - 9'sd128;   // -128 ~ +127

  // 19-bit 乘法結果
  wire signed [19:0] RV = V_off * C_RV;   // 9+10 → 19b
  wire signed [19:0] GU = U_off * C_GU;
  wire signed [19:0] GV = V_off * C_GV;
  wire signed [19:0] BU = U_off * C_BU;

  // 把 Y 變成 Q8.8 並對齊成 19b
  wire signed [19:0] Y_q88 = {4'b000, Y, 8'd0};   // 0|Y[7:0]|8'b0

  // 三色臨時值 (全部 19b)
  wire signed [19:0] r19 = Y_q88 + RV;
  wire signed [19:0] g19 = Y_q88 + GU + GV;
  wire signed [19:0] b19 = Y_q88 + BU;

  // 飽和 + 四捨五入函數
  function [7:0] q88_to_u8;
    input signed [19:0] v;
    reg [7:0] temp;
    begin
      if (v < 0)
        q88_to_u8 = 8'd0;
      else if (v > 20'sd65280)
        q88_to_u8 = 8'd255;   // 255*256
      else
      begin
        q88_to_u8 = (v + 128) >>> 8; // round-half-up
      end
    end
  endfunction

  // Step3: Y 通道亮度調整
  always @(*)
  begin
    if (!Brig[7])
    begin
      if (h_cnt < 480)
      begin
        YY = Y_old - Brig[6:0];
      end
      else if (h_cnt < 960)
      begin
        YY = Y_old - (Brig[6:0] >> 1);
      end
      else if (h_cnt < 1440)
      begin
        YY = Y_old + (Brig[6:0] >> 1);
      end
      else
      begin
        YY = Y_old + Brig[6:0];
      end
    end
    else
    begin
      if (h_cnt < 480)
      begin
        YY = Y_old + Brig[6:0];
      end
      else if (h_cnt < 960)
      begin
        YY = Y_old + (Brig[6:0] >> 1);
      end
      else if (h_cnt < 1440)
      begin
        YY = Y_old - (Brig[6:0] >> 1);
      end
      else
      begin
        YY = Y_old - Brig[6:0];
      end
    end
  end

  // Den 信號延遲暫存
  always @(posedge clk)
  begin
    Den_last <= DPi[24];
    Den_last2 <= Den_last;
  end

  // 垂直計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      v_cnt <= 11'd0;
    end
    else
    begin
      if (DPi[26])
        v_cnt <= 11'd0;
      else if ({Den_last, DPi[24]} == 2'b10)
        v_cnt <= v_cnt + 1'd1;
    end
  end

  // 水平計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 12'd0;
    end
    else
    begin
      if ({Den_last, DPi[24]} == 2'b10)
        h_cnt <= 12'd0;
      else if (DPi[24])
        h_cnt <= h_cnt + 1'd1;
    end
  end

  // TP 功能相關變數
  wire [7:0] b2 = (h_cnt >> 3);
  wire [7:0] r2 = 255 - (h_cnt >> 3);
  reg [19:0] X2, Y2;
  wire [20:0] D2 = X2 + Y2;
  reg [7:0] value;

  // TP 功能實作
  always @(*)
  begin
    if (h_cnt < 990)
    begin
      X2 = h_cnt * h_cnt;
    end
    else
    begin
      X2 = (1919 - h_cnt) * (1919 - h_cnt);
    end

    if (v_cnt < 540)
    begin
      Y2 = (539 - v_cnt) * (539 - v_cnt);
    end
    else
    begin
      Y2 = (v_cnt - 539) * (v_cnt - 539);
    end

    if (D2 >= 65536)
    begin
      value = 0;
    end
    else
    begin
      value = 255 - (D2 >> 8);
    end
  end

  // IM 功能相關變數
  reg [23:0] Din1_IM, Din2_IM, Dout1_IM, Dout2_IM;
  wire [10:0] W_ADDR1_IM = h_cnt;
  wire [10:0] W_ADDR2_IM = h_cnt;
  reg [11:0] v_out_IM;
  reg [11:0] h_out_IM;
  reg [10:0] x_out_IM;
  wire [10:0] R_ADDR1_IM = x_out_IM;
  wire [10:0] R_ADDR2_IM = x_out_IM;

  // IM 功能實作
  always @(*)
  begin
    if (IM && h_out_IM < 960 && v_out_IM < 540)
    begin
      x_out_IM = 960 - h_out_IM;
    end
    else if (IM && h_out_IM > 960 && v_out_IM > 540)
    begin
      x_out_IM = 1919 - (h_out_IM - 960);
    end
    else
    begin
      x_out_IM = h_out_IM;
    end

    // Din 資料選擇
    if (CC)
    begin
      Din1_IM = {q88_to_u8(r19), q88_to_u8(g19), q88_to_u8(b19)};
      Din2_IM = {q88_to_u8(r19), q88_to_u8(g19), q88_to_u8(b19)};
    end
    else
    begin
      Din1_IM = DPi[23:0];
      Din2_IM = DPi[23:0];
    end
  end

  // IG 功能相關變數
  reg [23:0] Din1_IG, Din2_IG, Dout1_IG, Dout2_IG;
  wire [10:0] W_ADDR1_IG = h_out_IM;
  wire [10:0] W_ADDR2_IG = h_out_IM;
  reg [11:0] v_out_IG;
  reg [11:0] h_out_IG;
  wire [10:0] R_ADDR1_IG = h_out_IG;
  wire [10:0] R_ADDR2_IG = h_out_IG;
  reg [23:0] window [0:3];
  reg [7:0] aver, aveg, aveb;

  // IG 功能 - 視窗暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      window[0] <= 24'd0;
      window[2] <= 24'd0;
    end
    else
    begin
      // shift window
      if (h_out_IG[0])
      begin
        window[0] <= window[1];
        window[2] <= window[3];
      end
    end
  end

  // IG 功能實作
  always @(*)
  begin
    Din1_IG = (!v_out_IM[0]) ? Dout1_IM : Dout2_IM;
    Din2_IG = (!v_out_IM[0]) ? Dout1_IM : Dout2_IM;
    window[1] = Dout1_IG;
    window[3] = Dout2_IG;

    if (h_out_IG[0])
    begin
      aver = (window[0][23:16] + window[1][23:16] + window[2][23:16] + window[3][23:16]) / 4;
      aveg = (window[0][15:8] + window[1][15:8] + window[2][15:8] + window[3][15:8]) / 4;
      aveb = (window[0][7:0] + window[1][7:0] + window[2][7:0] + window[3][7:0]) / 4;
    end
  end

  // IM 輸出計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_out_IM <= 12'd0;
      v_out_IM <= 12'd0;
    end
    else
    begin
      if (Sync_IM[0])
      begin
        if (h_out_IM == 1919)
        begin
          h_out_IM <= 0;
          v_out_IM <= v_out_IM + 1;
        end
        else
        begin
          h_out_IM <= h_out_IM + 1'd1;
        end
      end
    end
  end

  // IG 輸出計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_out_IG <= 12'd0;
      v_out_IG <= 12'd0;
    end
    else
    begin
      if (Sync_IG[0])
      begin
        if (h_out_IG == 1919)
        begin
          h_out_IG <= 0;
          v_out_IG <= v_out_IG + 1;
        end
        else
        begin
          h_out_IG <= h_out_IG + 1'd1;
        end
      end
    end
  end

  // 最終輸出選擇
  always @(*)
  begin
    if (CC && !IM)
    begin
      r = q88_to_u8(r19);
      g = q88_to_u8(g19);
      b = q88_to_u8(b19);
      DPo = {DPi[26:24], r, g, b};
    end
    else if (TP)
    begin
      r = (value > r2) ? value : r2;
      g = value;
      b = (value > b2) ? value : b2;
      DPo = {DPi[26:24], r, g, b};
    end
    else if (IM && !IG)
    begin
      r = (!v_out_IM[0]) ? Dout1_IM[23:16] : Dout2_IM[23:16];
      g = (!v_out_IM[0]) ? Dout1_IM[15:8] : Dout2_IM[15:8];
      b = (!v_out_IM[0]) ? Dout1_IM[7:0] : Dout2_IM[7:0];
      DPo = {Sync_IM, r, g, b};
    end
    else if (IG && !UM)
    begin
      DPo = {Sync_IG, aver, aveg, aveb};
    end
  end

  // UM 功能相關變數 (未完整實作但保留介面)
  wire [10:0] R_ADDR1_UM, W_ADDR1_UM, R_ADDR2_UM, W_ADDR2_UM;
  wire [23:0] Din1_UM, Dout1_UM, Din2_UM, Dout2_UM;

  // 記憶體實例化
  MEM2048X24 mem1IM(
               .CK(clk),
               .CS(1'b1),
               .WEB(!v_cnt[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR1_IM),
               .W_ADDR(W_ADDR1_IM),
               .D_IN(Din1_IM),
               .D_OUT(Dout1_IM)
             );

  MEM2048X24 mem2IM(
               .CK(clk),
               .CS(1'b1),
               .WEB(v_cnt[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR2_IM),
               .W_ADDR(W_ADDR2_IM),
               .D_IN(Din2_IM),
               .D_OUT(Dout2_IM)
             );

  MEM2048X24 mem1IG(
               .CK(clk),
               .CS(1'b1),
               .WEB(!v_out_IM[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR1_IG),
               .W_ADDR(W_ADDR1_IG),
               .D_IN(Din1_IG),
               .D_OUT(Dout1_IG)
             );

  MEM2048X24 mem2IG(
               .CK(clk),
               .CS(1'b1),
               .WEB(v_out_IM[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR2_IG),
               .W_ADDR(W_ADDR2_IG),
               .D_IN(Din2_IG),
               .D_OUT(Dout2_IG)
             );

  MEM2048X24 mem1UM(
               .CK(clk),
               .CS(1'b1),
               .WEB(!v_out_IG[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR1_UM),
               .W_ADDR(W_ADDR1_UM),
               .D_IN(Din1_UM),
               .D_OUT(Dout1_UM)
             );

  MEM2048X24 mem2UM(
               .CK(clk),
               .CS(1'b1),
               .WEB(v_out_IG[0]),
               .RE(1'b1),
               .R_ADDR(R_ADDR2_UM),
               .W_ADDR(W_ADDR2_UM),
               .D_IN(Din2_UM),
               .D_OUT(Dout2_UM)
             );

endmodule
