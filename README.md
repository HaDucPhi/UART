# UART
Thiết kế bộ UART trên nền tảng FPGA với ngôn ngữ VHDL được sử dụng.
Bộ giao thức UART này bao gồm :
- Một quá trình điều chế xung phục vụ cho việc truyền nhận dữ liệu ứng với tốc độ Baudrate xác định.
- Một bộ truyền dữ liệu với đầu vào thường là 8 bit.
- Một bộ nhận dữ liệu.
# Mô phỏng
- Dự án bao gồm một file UART.vdh mô tả hành vi của bộ truyền nhận UART, file TRANSFER.vhd giúp kiểm tra quá trình truyền nhận một chuỗi ký tự yêu cầu.
- Bạn có thể mô phỏng kiểm tra trực tiếp trên modelSim hoặc thông qua Matlab/Simulink với file UART.slx có tính trực quan hơn.
