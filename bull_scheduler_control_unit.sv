module bull_scheduler_controller_unit #(

    parameter int  CYCLE_CNT_BITS = 48,
    parameter int PREBUFFER_CYCLES = 6445,   // 20us 322.265625MHz
    parameter TS_FRAC_BITS = 0,
    parameter SHIFT = 9 + TS_FRAC_BITS,
    parameter LATENCY = 0


)(

    input logic clk,
    input logic rst,

    taxi_axis_if.snk s_axis,
    taxi_axis_if.mon mon_axis, // sadece tlast değil handshake de izle

    output logic fire,
    output logic done,
    output logic empty_fifo_alarm_reg,
    output logic [CYCLE_CNT_BITS-1:0] late_cnt

);



logic [CYCLE_CNT_BITS-1:0] cycle_cnt ;


always_ff@(posedge clk) begin 

    if(rst) begin
        cycle_cnt <= '0; end

    else begin
        cycle_cnt <= cycle_cnt + 1; end
end



//due_next = t_go + (ts[i] - ts_0) *165 >> (9+F)

logic [4:0] state ;


localparam IDLE = 5'b00001,
           PREP = 5'b00010,
           WAIT = 5'b00100,
           SEND = 5'b01000,
           DONE = 5'b10000;


logic [2:0] pipe_cnt;
logic [71:0] mult_product;
logic [71:0] shift_product;
logic [CYCLE_CNT_BITS-1:0] due_next;

always_ff@(posedge clk) begin 

    if(rst) begin 

        pipe_cnt <= 3'b000;
        mult_product <= 72'd0;
        shift_product <= 72'd0;
        due_next <= '0;
    end

    else begin 

        if(state == SEND) begin 

            case(pipe_cnt) 
        
            3'b000: begin 

                pipe_cnt <= 3'b001;
            end
           
            3'b001: begin 

                mult_product <= (ts_reg - ts_0) * 165;
                pipe_cnt <= 3'b010;

            end

            3'b010: begin 

                shift_product <= (mult_product + (72'd1 << (SHIFT-1))) >> SHIFT;
                pipe_cnt <= 3'b011;

            end

            3'b011: begin
                due_next <= t_go + shift_product[47:0]; 
                pipe_cnt <= 3'b100;
            end

            3'b100: begin

                due_next <= due_next;
            end

            default: begin

                pipe_cnt <= 3'b000;
                mult_product <= 72'd0;
                shift_product <= 72'd0;
                due_next <= '0; 
            end
            endcase


        end

        else begin 

                pipe_cnt <= 3'b000;
                mult_product <= 72'd0;
                shift_product <= 72'd0;
                due_next <= '0;
        end
    end
end

logic [CYCLE_CNT_BITS-1:0] due_reg;
logic [CYCLE_CNT_BITS-1:0] t_go; // prebuffer bittiği andaki cycle_cnt değeri 
logic [CYCLE_CNT_BITS-1:0] prebuf_cyc_cnt;
logic [63:0] ts_0; // çekilen ilk ts referans 
logic [63:0] ts_reg;



always_ff@(posedge clk) begin 

    if(rst) begin 

        fire <= 1'b0;   
        prebuf_cyc_cnt <= '0;
        due_reg <= '0;
        done <= 1'b0;
        late_cnt <= '0;
        state <= IDLE;
    end

    else begin 

        case(state)

        IDLE:begin 

            if(s_axis.tvalid) begin 

                fire <= 1'b0;
                ts_reg <= s_axis.tdata;
                ts_0 <= s_axis.tdata;
                state <= PREP;
            end

            else begin 

                fire <= 1'b0;
                state <= IDLE;
            end
        end

        PREP:begin 

            if(prebuf_cyc_cnt >= PREBUFFER_CYCLES) begin 

                due_reg + 1 <= cycle_cnt; //BURASI SIKINTILI OLABİLİR ZAMANLAMA AÇISINDAN AKLINDA TUT
                t_go <= cycle_cnt;
                fire <= 1'b0;
                state <= WAIT;
            end

            else begin 

                fire <= 1'b0;
                prebuf_cyc_cnt <= prebuf_cyc_cnt + 1;
                state <= PREP;
            end
        end

        WAIT:begin

            if(cycle_cnt >= due_reg) begin 

                fire <= 1'b1;
                ts_reg <= s_axis.tdata;
                state <= SEND;

                if(cycle_cnt > due_reg)
                    late_cnt <= late_cnt+1;
                else
                    late_cnt <= late_cnt;
            end

            else begin

                fire <= 1'b0;
                state <= WAIT; 
            end
        end

        SEND:begin

            if(mon_axis.tready && mon_axis.tvalid && mon_axis.tlast) begin 

                fire <= 1'b0;
                due_reg <= due_next;

                if(s_axis.tvalid)
                    state <= WAIT;
                else
                    done <= 1'b1;
                    state <= DONE;
            end

            else begin 

                fire <= 1'b1;
                state <= SEND;
            end
        end

        DONE:begin 

            done <= 1'b0;
            state <= IDLE;
        end
        endcase
    end
end

logic empty_fifo_alarm;
assign empty_fifo_alarm = (state == SEND || state == WAIT || state == PREP) && (!s_axis.tvalid || !mon_axis.tvalid);

always_ff@(posedge clk) begin 

    if(rst)
        empty_fifo_alarm_reg <= 1'b0;
    else if(empty_fifo_alarm)
        empty_fifo_alarm_reg <= 1'b1;
        
end

always_comb begin 

    if(rst)
        s_axis.tready = 1'b0;
    
    else if((state == IDLE) && (s_axis.tvalid == 1))
        s_axis.tready = 1'b1;

    else if((state == WAIT) && (cycle_cnt >= due_reg))
        s_axis.tready = 1'b1;

    else
        s_axis.tready = 1'b0;
end

endmodule