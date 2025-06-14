module timing_generator(

    input             clk,
    input             rst_n,

    input  [11:0]     h_total,
    input  [11:0]     h_size,
    input  [10:0]     h_sync,
    input  [10:0]     h_start,
    input  [10:0]     v_total,
    input  [10:0]     v_size,
    input  [ 9:0]     v_sync,
    input  [ 9:0]     v_start,
    input  [22:0]     vs_reset,

    output reg [26:24]    Synco
  );

  // Internal counters
  reg [11:0] h_cnt;
  reg [10:0] v_cnt;

  // Horizontal counter
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 12'd0;
    end
    else
    begin
      if (h_cnt >= h_total - 1)
      begin
        h_cnt <= 12'd0;
      end
      else
      begin
        h_cnt <= h_cnt + 1'b1;
      end
    end
  end

  // Vertical counter
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      v_cnt <= 11'd0;
    end
    else
    begin
      if (h_cnt >= h_total - 1)
      begin
        if (v_cnt >= v_total - 1)
        begin
          v_cnt <= 11'd0;
        end
        else
        begin
          v_cnt <= v_cnt + 1'b1;
        end
      end
    end
  end

  // Generate timing signals
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      Synco <= 3'b000;
    end
    else
    begin
      // VSync (bit 26)
      if (v_cnt < v_sync)
      begin
        Synco[2] <= 1'b1;
      end
      else
      begin
        Synco[2] <= 1'b0;
      end

      // HSync (bit 25)
      if (h_cnt < h_sync)
      begin
        Synco[1] <= 1'b1;
      end
      else
      begin
        Synco[1] <= 1'b0;
      end

      // Data Enable (bit 24)
      if ((h_cnt >= h_start && h_cnt < h_start + h_size) &&
          (v_cnt >= v_start && v_cnt < v_start + v_size))
      begin
        Synco[0] <= 1'b1;
      end
      else
      begin
        Synco[0] <= 1'b0;
      end
    end
  end

endmodule

