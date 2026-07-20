module bull_fifo_tb;

parameter DATA_WIDTH = 32;
parameter DEPTH  = 64;

logic        clk = 0;        
logic        rstn;
logic [DATA_WIDTH-1:0] data_in;
logic        write_enable, read_enable;
logic [DATA_WIDTH-1:0] data_out;
logic        empty, full;
logic error;


bull_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut(
.clk(clk), .rstn(rstn),
.data_in(data_in),
.write_enable(write_enable), .read_enable(read_enable),
.data_out(data_out), .empty(empty), .full(full) , .error(error)
);

logic [DATA_WIDTH-1:0] model [$]; 
logic [DATA_WIDTH-1:0] exp_data;  
bit          exp_valid; 


always #5 clk = ~clk;

initial begin                
    #500_000;
    $display("!!! TIMEOUT !!!");
    $finish;
end

task automatic drive(input bit w, input bit r, input logic [DATA_WIDTH-1:0] d);
    @(negedge clk);
    write_enable = w;
    read_enable  = r;
    data_in      = d;
endtask

int errors = 0;
task automatic check(input string what, input logic [DATA_WIDTH-1:0] got, input logic [DATA_WIDTH-1:0] exp);
    if (got !== exp) begin
        $display("  ** HATA ** %s: beklenen=%h geldi=%h", what, exp, got);
        errors++;
    end
endtask

task automatic check_flag(input string what, input logic got, input logic exp);
    if (got !== exp) begin
        $display("  ** HATA ** %s: beklenen=%b geldi=%b", what, exp, got);
        errors++;
    end
endtask

task automatic reset_dut();
    write_enable = 0;
    read_enable  = 0;
    data_in      = 0;
    #2 rstn = 0;
    repeat (2) @(negedge clk);
    rstn = 1;
endtask


bit wr_fire, rd_fire;

function automatic string sname(logic [2:0] s);
    case (s)
        3'b001:  return "EMPTY";
        3'b010:  return "LOAD ";
        3'b100:  return "FULL ";
        default: return "?????";
    endcase
endfunction

initial begin
    $timeformat(-9, 0, "ns", 5);
    $display("");
    $display("cyc |     t | rd emp | wr full   data_in  | FIRE  |  data_out | err | rc rlap | wc wlap | high | state");
    $display("----+-------+--------+--------------------+-------+-----------+-----+---------+---------+------+------");
end

int cycle = 0;
always @(posedge clk) begin
    #1;   
    wr_fire = write_enable && !full;     
    rd_fire = read_enable  && !empty;                               
    $display("%3d | %t |  %b   %b  |  %b   %b    %8h |  %b  %b  |  %8h |  %b  | %2d  %b   | %2d  %b   |  %b   | %s",
    cycle, $time,
    read_enable,  empty,
    write_enable, full, data_in,
    rd_fire, wr_fire,
    data_out,
    dut.error,
    dut.read_counter,  dut.read_lap_counter,
    dut.write_counter, dut.write_lap_counter,
    dut.high, sname(dut.state));
  cycle++;
end


always @(posedge clk) begin

  // ---- PARCA 1: GECEN cycle okuma olduysa, DUT'un cevabi artik hazir. Kontrol et. ----
    if (exp_valid) begin
        if (data_out !== exp_data) begin
            $display("  ** HATA ** okuma: beklenen=%h geldi=%h (t=%0t)", exp_data, data_out, $time);
            errors++;
        end
    end

  // ---- PARCA 2: BU cycle okuma fire ettiyse: defterden cek, kenara koy ----
    if (read_enable && !empty) begin
        exp_data  <= model.pop_front();   // defterden cek, kenara koy
        exp_valid <= 1;                   // "gelecek cycle kontrol edilecek"
    end else
        exp_valid <= 0;                   // bu cycle okuma yok, kenar gecersiz

  // ---- PARCA 3: BU cycle yazma fire ettiyse: deftere it ----
    if (write_enable && !full)
        model.push_back(data_in);

end


// PARCA 4: bayrak kontrolu (ayri blok, #1 ile edge sonunda)
always @(posedge clk) begin
    #1;
    if (rstn) begin
        if ((model.size() == 0) !== empty) begin
            $display("  ** HATA ** empty: model=%0d empty=%b (t=%0t)", model.size(), empty, $time);
            errors++;
        end
        if ((model.size() == DEPTH) !== full) begin
            $display("  ** HATA ** full: model=%0d full=%b (t=%0t)", model.size(), full, $time);
            errors++;
        end
  end
end




initial begin
    // ---- baslangic reset ----
    rstn = 0;
    write_enable = 0;
    read_enable  = 0;
    data_in      = 0;
    repeat (3) @(negedge clk);
    rstn = 1;

    // ---- MOD 1: yazma agirlikli (full'e zorlar) ----
    repeat (500) begin
        @(negedge clk);
        write_enable = ($urandom % 100) < 80;
        read_enable  = ($urandom % 100) < 20;
        data_in      = $urandom;
    end

    // ---- MOD 2: okuma agirlikli (empty'ye zorlar) ----
    repeat (500) begin
        @(negedge clk);
        write_enable = ($urandom % 100) < 20;
        read_enable  = ($urandom % 100) < 80;
        data_in      = $urandom;
    end

    // ---- ortada reset: dolu haldeyken temiz toparliyor mu ----
    reset_dut();

    // ---- MOD 3: esit (%50/%50) ----
    repeat (500) begin
        @(negedge clk);
        write_enable = $urandom;
        read_enable  = $urandom;
        data_in      = $urandom;
    end

    // ---- MOD 4: hep ikisi birden (esbzamanli oku-yaz) ----
    repeat (500) begin
        @(negedge clk);
        write_enable = 1;
        read_enable  = 1;
        data_in      = $urandom;
    end

    // ---- sakinlesme ----
    write_enable = 0;
    read_enable  = 0;
    repeat (3) @(negedge clk);

    // ---- ozet ----
    $display("");
    if (errors == 0) $display(">>> PASS  (%0d cycle)", cycle);
    else             $display(">>> FAIL  (%0d hata)", errors);
    $finish;
end



endmodule

