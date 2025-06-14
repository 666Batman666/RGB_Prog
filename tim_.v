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

    output reg [2:0]    Synco
  );

  // Internal counters
  reg [11:0] h_counter;
  reg [10:0] v_counter;

  // Timing signals
  wire hsync, vsync, de;

  // Horizontal counter
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_counter <= 0;
    end
    else
    begin
      if (h_counter == h_total - 1)
      begin
        h_counter <= 0;
      end
      else
      begin
        h_counter <= h_counter + 1;
      end
    end
  end

  // Vertical counter
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      v_counter <= 0;
    end
    else
    begin
      if (h_counter == h_total - 1)
      begin
        if (v_counter == v_total - 1)
        begin
          v_counter <= 0;
        end
        else
        begin
          v_counter <= v_counter + 1;
        end
      end
    end
  end

  // Generate timing signals
  assign hsync = (h_counter < h_sync) ? 1'b0 : 1'b1;
  assign vsync = (v_counter < v_sync) ? 1'b0 : 1'b1;
  assign de = ((h_counter >= h_start) && (h_counter < (h_start + h_size))) &&
         ((v_counter >= v_start) && (v_counter < (v_start + v_size)));

  // Output assignment
  always @(*)
  begin
    Synco[2] = hsync;  // Hsync
    Synco[1] = vsync;  // Vsync
    Synco[0] = de;     // Data Enable
  end

endmodule

