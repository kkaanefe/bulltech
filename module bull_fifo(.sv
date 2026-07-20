module bull_fifo #(

    parameter DATA_WIDTH = 32,
    parameter DEPTH  = 64
    
    )(

    input logic clk, 
    input logic rstn,

    input logic [DATA_WIDTH-1:0] data_in,
    input logic read_enable, // 1 oldu?unda read_counter?n gösterdi?i registerdan veri okunur
    input logic write_enable,// data_in sinyalinin anlaml? olup olmad???n? bildiren sinyal

    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty, // FIFO bo? ise 1 basar
    output logic full, // FIFO registerlar? doldu?u zaman bunu d??ar?ya 1 olarak bildiren sinyal
    output logic error
);

localparam counter_bits = $clog2(DEPTH);

logic [DATA_WIDTH-1:0] registers [0:DEPTH-1];

logic [counter_bits-1:0] read_counter;
logic read_lap_counter;

logic [counter_bits-1:0] write_counter;
logic write_lap_counter;

logic high;

logic [2:0] state;

localparam EMPTY =3'b001,
           LOAD = 3'b010,
           FULL = 3'b100;



assign high = write_lap_counter ^ read_lap_counter;

always_ff@(posedge clk or negedge rstn) begin // COUNTER LOG?CLER? 

    if(!rstn) begin 

        write_counter <= '0;
        write_lap_counter <= 1'b0;
        read_counter <= '0;
        read_lap_counter <= 1'b0;
    end

    else begin

        if(write_enable && ~full) begin 

            if(read_enable && ~empty) begin // OKUNUR VE YAZILIR
                
                if(write_counter == DEPTH-1) begin // WR?TE COUNTER MAX DE?ER?NE ULA?TI?INDA SIFIRLA VE LAP COUNTU DE???
                    
                    write_counter <= '0;
                    write_lap_counter <= ~write_lap_counter;
                    
                    if(read_counter == DEPTH-1) begin // READ MAX DE?ER?NE ULA?TI?INDA SIFIRLA VE LAP COUNTU DE???

                        read_counter <= '0;
                        read_lap_counter <= ~read_lap_counter;
                    end

                    else begin // SINIRDA DE??LSE B?R ARTTIR

                        read_counter <= read_counter + 1;
                    end
                end

                else begin // SINIRDA DE??LSE B?R ARTTIR

                    write_counter <= write_counter + 1;

                    if(read_counter == DEPTH-1) begin // READ MAX DE?ER?NE ULA?TI?INDA SIFIRLA VE LAP COUNT DE???

                        read_counter <= '0;
                        read_lap_counter <= ~read_lap_counter;
                    end

                    else begin // SINIRDA DE??LSE B?R ARTTIR

                        read_counter <= read_counter + 1;
                    end
                end
            end

            else begin // OKUNMAZ VE YAZILIR
                
                if(write_counter == DEPTH-1) begin // WR?TE SINIRDA ?SE SIFIRLA VE LAP COUNT DE???

                    write_counter <= '0;
                    write_lap_counter <= ~write_lap_counter;
                end

                else begin // SINIRDA DE??L ?SE B?R ARTTIR

                    write_counter <= write_counter + 1;
                end
            end

        end

        else begin 

            if(read_enable && ~empty) begin // OKUNUR VE YAZILMAZ
                
                if(read_counter == DEPTH-1) begin //READ SINIRDA ?SE SIFIRLA VE LAP COUTN DE???

                    read_counter <= '0;
                    read_lap_counter <= ~read_lap_counter;
                end

                else begin // SINIRDA DE??L ?SE B?R ARTTIR

                    read_counter <= read_counter + 1;
                end
            end

            else begin // OKUNMAZ VE YAZILMAZ
                
                read_counter <= read_counter;
                write_counter <= write_counter;
            end
        end

        


    end


end

always_ff@(posedge clk or negedge rstn) begin

    if(!rstn) begin 

        full <= 1'b0;
        empty <= 1'b1;

        state <= EMPTY;
        error <= 0;
    end 

    else begin 

        case(state)

        EMPTY: begin 

            if(write_enable && ~full) begin 
                registers[write_counter] <= data_in;
                empty <= 1'b0;
                full <= 1'b0;
                state <= LOAD;

            end
            

            else begin 

                empty <= 1;
                full <= 0;
                state <= EMPTY;

            end
        end

        LOAD: begin 

            if(write_enable && ~full) begin 

                if(read_enable && ~empty) begin  // YAZILIR VE OKUNUR 
                    
                    data_out <= registers[read_counter] ;
                    registers[write_counter] <= data_in;
                    state <= LOAD;
                    empty <= 0;
                    full <= 0;
                    
                end

                else begin // YAZILIR VE OKUNMAZ

                    if(high) begin // WR?TE_LAP_COUNTER READ_LAP_COUNTERDAN BÜYÜK ?SE
                        
                        if(write_lap_counter) begin //GÖRÜNÜRDE DE WR?TE_LAP READ_LAP TEN BÜYÜK ?SE
                            
                            if(((write_lap_counter*DEPTH + write_counter) - read_counter) == DEPTH-1) begin //READ_COUNTER WR?TE_COUNTER A YET??MEK ÜZERE BU DALDA YAZILIR VE OKUNMAZ OLDU?U ?Ç?N 
                                                                                                  //FULL E GEÇECEK
                                
                                state <= FULL;
                                registers[write_counter] <= data_in;
                                empty <= 0;
                                full <= 1;

                            end

                            else begin // DOLMAYA YAKIN DE??L LOADDAN DEVAM
                                
                                state <= LOAD;
                                registers[write_counter] <= data_in;
                                empty <= 0;
                                full <= 0;
                            end
                        end

                        else begin // GÖRÜNÜRDE READ_LAP WR?TE_LAP'DEN BÜYÜK ?SE

                            if(((read_lap_counter*DEPTH + write_counter) - read_counter) == DEPTH-1) begin //READ_COUNTER WR?TE_COUNTER A YET??MEK ÜZERE BU DALDA YAZILIR VE OKUNMAZ OLDU?U ?Ç?N 
                                                                                                  //FULL E GEÇECEK

                                state <= FULL;
                                registers[write_counter] <= data_in;
                                empty <= 0;
                                full <= 1;
                            end

                            else begin // DOLMAYA YAKIN DE??L LOADDAN DEVAM 

                                state <= LOAD;
                                registers[write_counter] <= data_in;
                                empty <= 0;
                                full <= 0;
                            end
                        end
                    end

                    else begin // LAP COUNTLAR E??T ?SE
                        
                        if((write_counter - read_counter) == DEPTH-1) begin  //READ_COUNTER WR?TE_COUNTER A YET??MEK ÜZERE BU DALDA YAZILIR VE OKUNMAZ OLDU?U ?Ç?N FULL E GEÇECEK
                            
                            state <= FULL;
                            registers[write_counter] <= data_in;
                            empty <= 0;
                            full <= 1;
                           
                        end

                        else begin // DOLMAYA YAKIN DE??L LOADDAN DEVAM 
                            
                            state <= LOAD;
                            registers[write_counter] <= data_in;
                            empty <= 0;
                            full <= 0;
                        end
                    end
                
                end
            end

            else begin 

                if(read_enable && ~empty) begin // YAZILMAZ VE OKUNUR
                    
                    if(high) begin // WR?TE LAP COUNT READ LAP COUNTTA BÜYÜK ?SE
                        
                        if(write_lap_counter) begin // WR?TE LAP COUNT GÖRÜNÜRDE DE DAHA BÜYÜK ?SE
                            
                            if(((write_lap_counter * DEPTH + write_counter) - read_counter )== 1) begin // SON B?R VER? KALDI DEMEKT?R EMPTYE STATE E GEÇ

                                data_out <= registers[read_counter];
                                state <= EMPTY;
                                empty <= 1;
                                full <= 0;
                            end

                            else begin //DAHA ?ÇER?DE VER? VAR LOAD'DAN DEVAM

                                data_out <= registers[read_counter];
                                state <= LOAD;
                                empty <= 0;
                                full <= 0;
                            end
                        end
                        
                        else begin // GÖRÜNÜRDE READ LAP COUNT DAHA BÜYÜK ?SE

                            if(((read_lap_counter*DEPTH + write_counter) - read_counter) == 1) begin // SON B?R VER? KALDI DEMEKT?R EMPTYE STATE E GEÇ

                                data_out <= registers[read_counter];
                                state <= EMPTY;
                                empty <= 1;
                                full <= 0;
                            end

                            else begin //DAHA ?ÇER?DE VER? VAR LOAD'DAN DEVAM

                                data_out <= registers[read_counter];
                                state <= LOAD;
                                empty <= 0;
                                full <= 0;
                            end
                        end
                    end

                    else begin // WR?TE_LAP VE READ_LAP COUNTLARI E??T ?SE
                        
                        if((write_counter - read_counter) == 1) begin // SADECE B?R VER? KALDI EMPTY GEÇ

                            data_out <= registers[read_counter];
                            state <= EMPTY;
                            empty <= 1;
                            full <= 0;
                        end

                        else begin // DAHA VER? VAR LOADDAN DEVAM

                            data_out <=registers[read_counter];
                            state <= LOAD;
                            empty <= 0;
                            full <= 0;
                        end

                    end
                end

                else begin // YAZILMAZ VE OKUNMAZ

                    state <= LOAD;
                    empty <= 0;
                    full <= 0;
                end
            end
        end



        FULL:begin 

            if(write_enable && ~full) begin // FULL= 1 OLDU?U ?Ç?N BURAYA ASLA G?RMEMES? GEREK G?RERSE ERROR VER
                
                error <= 1;



             end

            else begin 

                if(read_enable && ~empty) begin // YAZILMAZ VE OKUNUR
                    
                    data_out <= registers[read_counter];
                    state <= LOAD;
                    empty <= 0;
                    full <= 0;
                end

                else begin 

                    state <= FULL;
                    empty <= 0;
                    full <= 1;

                end
            end


        end

        default: begin

            state <= EMPTY;

        end
        endcase
    end
end


endmodule 