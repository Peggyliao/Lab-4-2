/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// This include is relative to $CARAVEL_PATH (see Makefile)
#include <defs.h>
#include <stub.c>

// ap control
#define reg_ctrl (*(volatile uint32_t*)0x30000000)

// data length
#define reg_len (*(volatile uint32_t*)0x30000010)

// tap address
#define reg_tap_00 (*(volatile uint32_t*)0x30000040)
#define reg_tap_01 (*(volatile uint32_t*)0x30000044)
#define reg_tap_02 (*(volatile uint32_t*)0x30000048)
#define reg_tap_03 (*(volatile uint32_t*)0x3000004c)
#define reg_tap_04 (*(volatile uint32_t*)0x30000050)
#define reg_tap_05 (*(volatile uint32_t*)0x30000054)
#define reg_tap_06 (*(volatile uint32_t*)0x30000058)
#define reg_tap_07 (*(volatile uint32_t*)0x3000005c)
#define reg_tap_08 (*(volatile uint32_t*)0x30000060)
#define reg_tap_09 (*(volatile uint32_t*)0x30000064)
#define reg_tap_10 (*(volatile uint32_t*)0x30000068)

// X[n] address

#define reg_x (*(volatile uint32_t*)0x30000080)

// Y[n] address

#define reg_y (*(volatile uint32_t*)0x30000084)

// void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir();
// int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir();

// extern int* fir();

// --------------------------------------------------------

/*
	MPRJ Logic Analyzer Test:
		- Observes counter value through LA probes [31:0] 
		- Sets counter initial value through LA probes [63:32]
		- Flags when counter value exceeds 500 through the management SoC gpio
		- Outputs message to the UART when the test concludes successfuly
*/

void main()
{
	int j;

	/* Set up the housekeeping SPI to be connected internally so	*/
	/* that external pin changes don't affect it.			*/

	// reg_spi_enable = 1;
	// reg_spimaster_cs = 0x00000;

	// reg_spimaster_control = 0x0801;

	// reg_spimaster_control = 0xa002;	// Enable, prescaler = 2,
                                        // connect to housekeeping SPI

	// Connect the housekeeping SPI to the SPI master
	// so that the CSB line is not left floating.  This allows
	// all of the GPIO pins to be used for user functions.

	// The upper GPIO pins are configured to be output
	// and accessble to the management SoC.
	// Used to flad the start/end of a test 
	// The lower GPIO pins are configured to be output
	// and accessible to the user project.  They show
	// the project count value, although this test is
	// designed to read the project count through the
	// logic analyzer probes.
	// I/O 6 is configured for the UART Tx line

        reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

        reg_mprj_io_15 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_14 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_13 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_12 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_11 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_10 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_9  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_8  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_7  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_5  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_4  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_3  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_2  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_1  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_0  = GPIO_MODE_USER_STD_OUTPUT;

        reg_mprj_io_6  = GPIO_MODE_MGMT_STD_OUTPUT;

	// Set UART clock to 64 kbaud (enable before I/O configuration)
	// reg_uart_clkdiv = 625;
	reg_uart_enable = 1;
	
	// Now, apply the configuration
	reg_mprj_xfer = 1;
	while (reg_mprj_xfer == 1);

        // Configure LA probes [31:0], [127:64] as inputs to the cpu 
	// Configure LA probes [63:32] as outputs from the cpu
	reg_la0_oenb = reg_la0_iena = 0x00000000;    // [31:0]
	reg_la1_oenb = reg_la1_iena = 0xFFFFFFFF;    // [63:32]
	reg_la2_oenb = reg_la2_iena = 0x00000000;    // [95:64]
	reg_la3_oenb = reg_la3_iena = 0x00000000;    // [127:96]

	// Flag start of the test 
	reg_mprj_datal = 0xAB400000;

	// Set Counter value to zero through LA probes [63:32]
	reg_la1_data = 0x00000000;

	// Configure LA probes from [63:32] as inputs to disable counter write
	reg_la1_oenb = reg_la1_iena = 0x00000000;    

/*
	while (1) {
		if (reg_la0_data_in > 0x1F4) {
			reg_mprj_datal = 0xAB410000;
			break;
		}
	}
*/	


	reg_tap_00 =   0;
	reg_tap_01 = -10;
	reg_tap_02 =  -9;
	reg_tap_03 =  23;
	reg_tap_04 =  56;
	reg_tap_05 =  63;
	reg_tap_06 =  56;
	reg_tap_07 =  23;
	reg_tap_08 =  -9;
	reg_tap_09 = -10;
	reg_tap_10 =   0;

	reg_len = 64;

	reg_ctrl = 1;

	for (int i = 0; i < 64; i++)
	{
		// ready to accept x
		
		while ((reg_ctrl >> 3 & 1) != 1) {}
		reg_x = i + 1;
		// // ready to accept y
		while ((reg_ctrl >> 4 & 1) != 1) {}
		reg_mprj_datal = reg_y << 16;
	}
	// int* tmp = fir();
	// reg_mprj_datal = *(tmp + 0) << 16;
	// for (int i = 0; i < 1; i++)
	// {
	// 	int* tmp = fir();
	// 	for (int j = 0; j < 64; j++)
	// 	{
	// 		reg_mprj_datal = *(tmp + j) << 16;
	// 	}
	// }

	//print("\n");
	//print("Monitor: Test 1 Passed\n\n");	// Makes simulation very long!
	reg_mprj_datal = 0xAB510000;
}