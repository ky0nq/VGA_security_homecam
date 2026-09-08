// Shared testbench definitions.
`define bps #(1_000_000_000 / 9600);
`define bps16 ( 100_000_000 / 9600);
`define UART
`define SPI
`define I2C
`define cpol 0
`define cpha 1
int bps_value = `bps16;
bit [7:0]i_ascii = 8'd0;
int loop;

string mode_sel;

typedef enum {
		TEST_START = 0, TEST_END,  
		RESET,
		BUTTON_PRESS,
		SWITCH_SET,
		CAMERA_FRAME,
		UART_RX, UART_TX,
		SCCB_WRITE, SCCB_READ,
		WRITE, READ, M_SPI, CAMERA,
		M_I2C,
		ALL_SPI,ALL_I2C,ALL
}c_mode;

typedef enum {
		NORM=0, UART=1, SPI=2, I2C=3, AXI=4, APB=5
}c_protocal;

int protocal = 2;
