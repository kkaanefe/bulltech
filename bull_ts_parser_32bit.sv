module bull_ts_parser # (

    DATA_W = 32,
    KEEP_W = ((DATA_W+7)/8),
    TS_W = 64,
    MAX_BYTE = 9218, 
    BYTE_PER_BEAT = DATA_W/8, // bir beatteki byte sayısı
    MAX_BEAT_COUNT = MAX_BYTE/BYTE_PER_BEAT, // bir frameden gelebilecek max beat sayısı
    BEAT_CONTER_B = $clog2(MAX_BEAT_COUNT) // beat acounter tutacak beat sayısı hesaplaması
    
     ) (

input logic clk,
input logic rst, // acitve high belki low a döneriz kodun diğer kısımlarına da bakmak lazım belki de farketmiyorudur bile

// AXI-STREAM
taxi_axis_if.snk m_axis,

// KONTROL SİNYALLERİ
output logic valid_ts, // ts parse işlemi başarıyla bittikten sonra bir olur
output logic valid_frame,
output logic error, // bozuk frame gelirse bir olur farklı always bloğu içinde handle edilecek şimdilik kalabilir 

// PARSED TİME STAMP
output logic time_stamp [TS_W-1:0],

//time stamp parse edildikten sonra frame in kalanı aynen geçirilir
output logic rest_of_the_frame 

);

logic [BEAT_COUNTER_B-1 : 0] beat_counter;

logic [DATA_W-1:0] tdata;
logic [KEEP_W-1:0] tkeep;
logic tlast;
logic tvalid;
logic tready

logic [DATA_W-1:0] swapped_ts; // time stampin sağdaki bitinin lsb olması için kullanılacak ara değişken
assign swapped_ts = {tdata[7:0], tdata[15:8], tdata[23:16], tdata[31:24]};


logic [TS_W-1:0] buffer; // time stampin tüm byteları gelen kadar bytler burada tutulur

assign m_axis.tready = 1'b1;

assign tdata  = m_axis.tdata;
assign tkeep  = m_axis.tkeep;
assign tlast  = m_axis.tlast;
assign tvalid = m_axis.tvalid;
assign tready = m_axis.tready;

logic [2:0] state;

localparam IDLE    = 3'b001,
           COLLECT = 3'b010,
           DRAIN   = 3'b100;

assign time_stamp = buffer;



always_ff@(posedge clk or posedge rst) begin

if(rst) begin 

    valid <= 1'b0;
    beat_counter <= '0;
    state <= IDLE;

end

else begin 

    case(state)

    IDLE: begin 

        if(tvalid && tready) begin 

            valid_ts <= 1'b0;
            valid_frame <= 1'b0;
            beat_counter <= beat_counter + 1;
            state <= COLLECT;
            buffer[TS_W-1:TS_W-DATA_W] <= swapped;


        end

        else begin 
            valid <= 1'b0;
            beat_counter <= '0;
            state <= IDLE;           
        end
    end

    COLLECT:begin

        if(tvalid && tready) begin 
            valid_ts <= 1'b1;
            beat_counter <= beat_counter + 1;
            state <= DRAIN;
            buffer[TS_W-DATA_W-1:TS_W-DATA_W-DATA_W];
        end

        else begin 
            valid <= 1'b0;
            beat_counter <= beat_counter;
            state <= COLLECT;
        end
    end

    DRAIN:begin 

        if(tvalid && tready) begin

            if(tlast) begin 
                state <= IDLE;
                valid
                
            end

            else begin 
            end
        end

        else begin 
        end
    end
    endcase
end

end

endmodule