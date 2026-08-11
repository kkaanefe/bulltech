module bull_scheduler_control_unit_v2 #(

parameter int CYCLE_CNT_BITS = 48,
parameter int PREBUFFER_CYCLES = 6445,
parameter int SHIFT = 9

)(

    input logic clk,
    input logic rst,

    taxi_axis.if.snk s_axis, // TS_FIFO dan gelen axi stream
    taxi_axis.if.snk mon_axis, // parser ve frame_FIFO arasındaki axi stream

    output logic fire,
    output logic [CYCLE_CNT_BITS-1:0] late_cnt,


);

/* 

BULL_REPLAYER CONTROLLER

*/

logic [CYCLE_CNT_BITS-1:0] cycle_cnt ; //   resetten itibaren her cycle değeri bir artar

always_ff@(posedge clk) begin 

    if(rst) begin
        cycle_cnt <= '0; end

    else begin
        cycle_cnt <= cycle_cnt + 1; end
end

logic [4:0] state;

localparam IDLE = 5'b00001, // daha hiç bir veri gelmeden önce resetten sonraki state
           PREP = 5'b00010, // prebuffer süresince beklenen state
           WAIT = 5'b00100, // frame'in çıkış vaktinin beklendiği state
           SEND = 5'b01000, // frame'in gönderildiği state
           STOP = 5'b10000, // ts fifonun boşaldığı state


logic [CYCLE_CNT_BITS-1:0] due_time_reg; // fraemin ne zaman gönderileceğini tutan register
logic [CYCLE_CNT_BITS-1:0] ref_cyc_cnt; // prebuffer süresi bittikten sonraki cycle_count yani 0 noktası
logic [CYCLE_CNT_BITS-1:0] prebuf_cyc_cnt; // prebuffer süresinin dolmasını beklerken tutulan sayaç
logic [63:0] ref_ts; // ilk frame'in time stampi

logic s_axis_handshake;
assign s_axis_handshake = s_axis.tvalid && s_axis.tready;

logic mon_axis_handshake;
assign mon_axis_handshake = mon_axis.tvalid && mon_axis.tready;

always_ff@(posedge clk) begin 

    if(rst) begin 

        fire <= 1'b0;
        due_time_reg <= '0; 
        ref_cyc_cnt <= '0;
        prebuf_cyc_cnt <= '0;
        ref_ts <= 64'd0;
        state <= IDLE;

    end

    else begin

        case(state)

        IDLE: begin  // IDLE statinde TS_FIFO ya ilk veri gelene kadar beklenir ardından PREP state'e geçilir
            
            if(s_axis_handshake) begin // bu anda tready'i 1 e çekmek lazım

                ref_ts <= s_axis.tdata; // referans time stampi burada registerladık tready lojiğini yazarken burada tready 1 olmalı
                state <= PREP;

            end


            else begin 

                state <= IDLE; // ts fifodan tvalid gelmezse IDLE state kal

            end
        end

        PREP:begin  

            if(prebuf_cyc_cnt >= PREBUFFER_CYCLES) begin 

                ref_cyc_cnt <= cycle_cnt; //  BURAYA +1 EKLENEBİLİR AKLINDA OLSUN
                state <= SEND;
            end

            else begin 

                prebuf_cyc_cnt <= prebuf_cyc_cnt + 1;
                state <= PREP;

            end
        end

        WAIT:begin 
        end

        SEND:begin 

            if(mon_axis_handshake && mon_axis.tlast) begin 

                fire <= 1'b0;

                if(due_next_valid) begin
                    due_time_reg <= due_next;
                    state <= WAIT;
                end

                else begin 

                    state <= STOP;
                end

            end

            else begin 

                fire <= 1'b1;
                state <= SEND;

            end
        end

        STOP:begin 

            if(due_next_valid) begin 

                due_time_reg <= due_next;
                state <= WAIT;
            
            else begin 

                state <= STOP;
            end
            end
                

        end

        default:begin
        end
        endcase
    end
end

logic [CYCLE_CNT_BITS-1:0] due_next; // bir sonraki framein ne zaman çıkacağının hesabı
logic due_next_valid; // due_next geçerli bir değerde mi 
logic [63:0] ts_next; // bir frame gönderilirken diğerinin gönderileceği zaman hesaplanacak yani bi sonraki framein time stampi
logic ts_next_valid;


always_ff@(posedge clk) begin 

    if(rst) begin

        due_next <= '0;
        ts_next <= 64'd0;
    
    end
    
    else if((state == IDLE) && s_axis_handshake)
        ts_next <= s_axis.tdata; // normalde ts_next WAIT state de bir sonraki frame için yazılır ama ilk frame için böyle bir seçenek olmadığından prepte yazıldı bu anda tready 1 olmalı
    
    else if((state == SEND) && s_axis_handshake) // burada treadyi açıp handshake gerçekleştikten sonra kapatılmalı
        ts_next <= s_axis.tdata;
        ts_next_valid <= 1'b1;
    
    else if((state == SEND) && ts_next_valid)
        due_next <= ref_cyc_cnt + ((ts_next - ref_ts) * 165 + (72'd1 << (SHIFT-1))) >> SHIFT;
        due_next_valid <= 1'b1;
        ts_next_valid <= 1'b0;
    
    else if((state == WAIT))
        due_next_valid <= 1'b0;
    
    else if((state == STOP) && s_axis_handshake) // tvalid 1 e çekilirse treadyini 1 e çekiceksin  
        ts_next <= s_axis.tdata;
        ts_next_valid <= 1'b1;

    else if((state == STOP ) && ts_next_valid)
        due_next <= ref_cyc_cnt + ((ts_next - ref_ts) * 165 + (72'd1 << (SHIFT-1))) >> SHIFT;
        due_next_valid <= 1'b1;
        ts_next_valid <= 1'b0;

    
end


always_ff@(posedge clk) begin 
end
endmodule                                                                                                                
