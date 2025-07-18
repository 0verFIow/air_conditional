`timescale 1ns / 1ps

// 새로운 All-in-One DHT11 코어를 적용한 최상위 모듈
module dht11_top(
    // 시스템 입력
    input clk,               // 100MHz 클럭
    input reset,             // 리셋 (btnU, Active-high)
    input [2:0] btn,         // 버튼 [2:R, 1:C, 0:L]
    input [7:0] sw,          // 스위치 (미사용)
    
    // UART
    input RsRx,
    output RsTx,
    
    // DHT11 센서
    inout dht_data,
    
    // 디스플레이
    output [7:0] seg,
    output [3:0] an,
    output [15:0] led
);

    // --- 내부 신호 선언 ---
    wire [2:0] btn_debounced;
    wire [7:0] temperature;      // DHT11 모듈에서 직접 출력
    wire [7:0] humidity;         // DHT11 모듈에서 직접 출력
    wire data_ready;         // DHT11 모듈의 done 신호와 연결
    
    reg [1:0] display_mode;      // 표시 모드 (top 모듈에서 직접 제어)
    reg [1:0] prev_btn;
    
    wire [7:0] uart_rx_data;
    wire uart_rx_done;

    // --- 모듈 인스턴스화 ---

    // 1. 버튼 디바운싱 (기존과 동일)
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : btn_debounce
            my_button_debounce u_btn_debounce(
                .i_clk(clk),
                .i_reset(reset),
                .i_btn(btn[i]),
                .o_btn_stable(btn_debounced[i]),
                .o_btn_pulse()
            );
        end
    endgenerate
    
    // 2. 새로운 All-in-One DHT11 코어 모듈
    //    이 모듈이 5초마다 자동으로 온습도를 측정합니다.
    dht11_sensor u_dht11_sensor (
        .clk(clk),
        .rst_n(~reset),      // top의 reset은 active-high이므로 반전시켜 연결
        .dht11_data(dht_data),
        .humidity(humidity),
        .temperature(temperature),
        .DHT11_done(data_ready) // done 신호를 data_ready로 사용
    );

    // 3. 디스플레이 제어 모듈 (FND 표시 담당)
    display_controller u_display_controller(
        .clk(clk),
        .reset(reset),
        .temperature(temperature),
        .humidity(humidity),
        .display_mode(display_mode), // top에서 제어하는 표시 모드 전달
        .status_led_in(16'h0),   // LED는 아래에서 직접 제어하므로 더미값 전달
        .seg(seg),
        .an(an),
        .led() // led 출력은 아래 로직에서 직접 제어
    );
    
    // 4. UART 관리 모듈
    uart_manager u_uart_manager(
        .clk(clk),
        .reset(reset),
        .temperature(temperature),
        .humidity(humidity),
        .data_ready(data_ready), // DHT11 코어의 done 신호를 전달
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done)
    );

    // --- 표시 모드 및 LED 제어 로직 (top 모듈에 직접 구현) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            display_mode <= 2; // 초기 모드는 동시 표시
            prev_btn <= 0;
        end else begin
            prev_btn <= btn_debounced;

            // 버튼 0: 모드 변경
            if (btn_debounced[0] && !prev_btn[0]) begin
                display_mode <= (display_mode == 2) ? 0 : display_mode + 1;
            end
            
            // UART 명령 처리
            if (uart_rx_done) begin
                case (uart_rx_data)
                    8'h54, 8'h74: display_mode <= 0; // 'T'
                    8'h48, 8'h68: display_mode <= 1; // 'H'
                    8'h41, 8'h61: display_mode <= 2; // 'A'
                endcase
            end
        end
    end
    
    // LED 출력 직접 제어
    assign led[15:14] = display_mode;
    assign led[13] = 0; // 번갈아 표시 기능 없으므로 끔
    assign led[12] = data_ready; // 측정 완료 시 깜빡임
    assign led[11] = 0; // 새로운 코어에는 에러 출력이 없음
    assign led[10] = 0; // 새로운 코어에는 busy 출력이 없음
    // 나머지 LED는 0으로 유지 (필요시 추가 가능)
    assign led[9:0] = 0;



    

endmodule
