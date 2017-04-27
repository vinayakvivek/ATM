/* 
 * Copyright (C) 2012-2014 Chris McClelland
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <makestuff.h>
#include <libfpgalink.h>
#include <libbuffer.h>
#include <liberror.h>
#include <libdump.h>
#include <argtable2.h>
#include <readline/readline.h>
#include <readline/history.h>
#ifdef WIN32
#include <Windows.h>
#else
#include <sys/time.h>
#endif



bool sigIsRaised(void);
void sigRegisterHandler(void);

static const char *const errMessages[] = {
	NULL,
	NULL,
	"Unparseable hex number",
	"Channel out of range",
	"Conduit out of range",
	"Illegal character",
	"Unterminated string",
	"No memory",
	"Empty string",
	"Odd number of digits",
	"Cannot load file",
	"Cannot save file",
	"Bad arguments"
};

typedef enum {
	FLP_SUCCESS,
	FLP_LIBERR,
	FLP_BAD_HEX,
	FLP_CHAN_RANGE,
	FLP_CONDUIT_RANGE,
	FLP_ILL_CHAR,
	FLP_UNTERM_STRING,
	FLP_NO_MEMORY,
	FLP_EMPTY_STRING,
	FLP_ODD_DIGITS,
	FLP_CANNOT_LOAD,
	FLP_CANNOT_SAVE,
	FLP_ARGS
} ReturnCode;


// TEA encryption
void encrypt(uint32 *v0_ref, uint32 *v1_ref) {
	uint32 v0 = *v0_ref, v1 = *v1_ref;
	uint32 delta = 0x9e3779b9, sum = 0, n = 32; 
	uint32 k0 = 0x2927c18c, k1 = 0x75f8c48f, k2 = 0x43fd99f7, k3 = 0xff0f7457;

	while (n-- > 0) {
		sum += delta;
		v0 += ((v1 << 4) + k0) ^ (v1 + sum) ^ ((v1 >> 5) + k1);
		v1 += ((v0 << 4) + k2) ^ (v0 + sum) ^ ((v0 >> 5) + k3);
	}

	*v0_ref = v0;
	*v1_ref = v1;
}

void decrypt(uint32 *v0_ref, uint32 *v1_ref) {
	uint32 v0 = *v0_ref, v1 = *v1_ref;
	uint32 delta = 0x9e3779b9, sum = 0xC6EF3720, n = 32;; 
	uint32 k0 = 0x2927c18c, k1 = 0x75f8c48f, k2 = 0x43fd99f7, k3 = 0xff0f7457;
	
	while (n-- > 0) {
		v1 -= ((v0 << 4) + k2) ^ (v0 + sum) ^ ((v0 >> 5) + k3);
		v0 -= ((v1 << 4) + k0) ^ (v1 + sum) ^ ((v1 >> 5) + k1);
		sum -= delta;
	}

	*v0_ref = v0;
	*v1_ref = v1;
}


// return 	0 - if user is invalid
//			1 - if user is valid and not admin and has enough balance
//			2 - if user is valid and not admin and do not have enough balance
//			3 - if user is valid and is an admin
// 			4 - if user is valid and not admin, but not enough money in the atm 
int doTransaction(uint16 user_id, uint16 user_pin, uint32 amount_requested, uint8 status) {
	
	FILE* stream = fopen("SampleBackEndDatabase.csv", "r");

	// temp file to copy data (in case we need to update balance)
	FILE* temp = fopen("temp.csv", "w");

	fprintf(temp, "%s\n", "\"User ID (decimal)\",\"PIN Hash (decimal)\",\"Admin\",\"Balance (decimal)\"");

	const int N = 100;
	int return_code = 0;
	char line[N];

	// ignore first of the file
    fgets(line, N, stream);

    int id, pin, admin, balance;

    bool userFound = false;

    // read each line as process it
 	while (fscanf(stream, "%d,%d,%d,%d", &id, &pin, &admin, &balance) != EOF) {

		if (id ==  user_id && pin == user_pin) {
			printf("%s\n", "Valid user found");
			userFound = true;
			if (admin) {
				printf("%s\n", "User has admin privileges");
				return_code = 3;
			} else {
				if ((uint32)balance >= amount_requested) {
					if (status == 1) {
						balance -= amount_requested;
						printf("%s\n", "Requested amout has been deducted from your account");
					} else {
						printf("%s\n", "Not enough money in the ATM");
					}
					return_code = 1;
				} else {
					return_code = 2;
				}
			}
		}
		fprintf(temp, "%d,%d,%d,%d\n", id, pin, admin, balance);
    }

    if (!userFound) {
		printf("%s\n", "Invalid credentials");
	}

	
	fclose(stream);
    fclose(temp);

    remove("SampleBackEndDatabase.csv");
    rename("temp.csv", "SampleBackEndDatabase.csv");
	
    return return_code;
}

int main(int argc, char *argv[]) {
	ReturnCode retVal = FLP_SUCCESS;
	
	struct arg_str *ivpOpt = arg_str0("i", "ivp", "<VID:PID>", "            vendor ID and product ID (e.g 04B4:8613)");
	struct arg_str *vpOpt = arg_str1("v", "vp", "<VID:PID[:DID]>", "       VID, PID and opt. dev ID (e.g 1D50:602B:0001)");
	struct arg_str *fwOpt = arg_str0("f", "fw", "<firmware.hex>", "        firmware to RAM-load (or use std fw)");
	struct arg_str *progOpt = arg_str0("p", "program", "<config>", "         program a device");
	struct arg_lit *helpOpt  = arg_lit0("h", "help", "                     print this help and exit");
	
	struct arg_end *endOpt   = arg_end(20);
	

	void *argTable[] = {
		ivpOpt, vpOpt, fwOpt, progOpt, helpOpt, endOpt
	};

	const char *progName = "flcli";
	int numErrors;
	struct FLContext *handle = NULL;
	FLStatus fStatus;
	const char *error = NULL;
	const char *ivp = NULL;
	const char *vp = NULL;
	bool isNeroCapable;
	bool isCommCapable;
	// uint32 numDevices, scanChain[16], i;
	const char *line = NULL;
	uint8 conduit = 0x01;

	if ( arg_nullcheck(argTable) != 0 ) {
		fprintf(stderr, "%s: insufficient memory\n", progName);
		FAIL(1, cleanup);
	}

	numErrors = arg_parse(argc, argv, argTable);

	if ( helpOpt->count > 0 ) {
		printf("FPGALink Command-Line Interface Copyright (C) 2012-2014 Chris McClelland\n\nUsage: %s", progName);
		arg_print_syntax(stdout, argTable, "\n");
		printf("\nInteract with an FPGALink device.\n\n");
		arg_print_glossary(stdout, argTable,"  %-10s %s\n");

		printf("\n******* Modified for CS254 Lab projects *******\n");
				
		FAIL(FLP_SUCCESS, cleanup);
	}


	if ( numErrors > 0 ) {
		arg_print_errors(stdout, endOpt, progName);
		fprintf(stderr, "Try '%s --help' for more information.\n", progName);
		FAIL(FLP_ARGS, cleanup);
	}

	fStatus = flInitialise(0, &error);
	CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);

	vp = vpOpt->sval[0];

	printf("Attempting to open connection to FPGALink device %s...\n", vp);
	fStatus = flOpen(vp, &handle, NULL);
	if ( fStatus ) {
		if ( ivpOpt->count ) {
			int count = 60;
			uint8 flag;
			ivp = ivpOpt->sval[0];
			printf("Loading firmware into %s...\n", ivp);
			if ( fwOpt->count ) {
				fStatus = flLoadCustomFirmware(ivp, fwOpt->sval[0], &error);
			} else {
				fStatus = flLoadStandardFirmware(ivp, vp, &error);
			}
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
			
			printf("Awaiting renumeration");
			flSleep(1000);
			do {
				printf(".");
				fflush(stdout);
				fStatus = flIsDeviceAvailable(vp, &flag, &error);
				CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
				flSleep(250);
				count--;
			} while ( !flag && count );
			printf("\n");
			if ( !flag ) {
				fprintf(stderr, "FPGALink device did not renumerate properly as %s\n", vp);
				FAIL(FLP_LIBERR, cleanup);
			}

			printf("Attempting to open connection to FPGLink device %s again...\n", vp);
			fStatus = flOpen(vp, &handle, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
		} else {
			fprintf(stderr, "Could not open FPGALink device at %s and no initial VID:PID was supplied\n", vp);
			FAIL(FLP_ARGS, cleanup);
		}
	}

	printf(
		"Connected to FPGALink device %s (firmwareID: 0x%04X, firmwareVersion: 0x%08X)\n",
		vp, flGetFirmwareID(handle), flGetFirmwareVersion(handle)
	);

	isNeroCapable = flIsNeroCapable(handle);
	isCommCapable = flIsCommCapable(handle, conduit);

	if ( progOpt->count ) {
		printf("Programming device...\n");
		if ( isNeroCapable ) {
			fStatus = flSelectConduit(handle, 0x00, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
			fStatus = flProgram(handle, progOpt->sval[0], NULL, &error);
			CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
		} else {
			fprintf(stderr, "Program operation requested but device at %s does not support NeroProg\n", vp);
			FAIL(FLP_ARGS, cleanup);
		}
	}

	
	// ATM PART

	if ( isCommCapable ) {
		uint8 isRunning;
		fStatus = flSelectConduit(handle, conduit, &error);
		CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
		fStatus = flIsFPGARunning(handle, &isRunning, &error);
		CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
		if ( isRunning ) {

			printf("%s\n", "starting...");

			// inf loop
			while (true) {

				int count = 0;
				uint8 byte = 0, prevByte = 4;

				// printf("%s\n", "inside loop");

				while (true) {
					// read from channel 0					
					fStatus = flReadChannel(handle, 0, 1, &byte, &error);
					CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);

					// sleep for 1 sec
					flSleep(1000);

					// printf("%d\n", byte);

					if (byte == 0x01 || byte == 0x02) {
						if (prevByte == byte) {
							count++;
							if (count == 3)
								break;
						} else {
							prevByte = byte;
							count = 0;
						}
					} else {
						count = 0;
					}
				}


				// check not required, but just to assure
				if (count == 3) {
					uint8 bytes[8];
					for (int i = 0; i < 8; ++i) {
						fStatus = flReadChannel(handle, (uint8)(i + 1), 1, &bytes[i], &error);
						CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
					}


					// ==> bytes[7] -> 100 Rs notes
					// ==> bytes[6] -> 500 
					// ==> bytes[5] -> 1000
					// ==> bytes[4] -> 2000

					// ==> bytes[2] . bytes[3] -> PIN
					// ==> bytes[0] . bytes[1] -> ID

					uint32 v0 = (bytes[3] << 24) + (bytes[2] << 16) + (bytes[1] << 8) + (bytes[0]);
					uint32 v1 = (bytes[7] << 24) + (bytes[6] << 16) + (bytes[5] << 8) + (bytes[4]);

					decrypt(&v0, &v1);

					uint16 ID = ((v0 & 0x000000ff) << 8) + ((v0 & 0x0000ff00) >> 8);	// first two bytes ==> ID
					uint16 PIN = (((v0 & 0x00ff0000) << 8) + ((v0 & 0xff000000) >> 8)) >> 16; // bytes 3 & 4 ==> PIN


					// NOTE hashing
					PIN = (PIN << 11) + (PIN >> (16 - 11));
					// printf("%s\n", "PIN not hashed");

					uint8 n2000 = (v1 & 0x000000ff);
					uint8 n1000 = (v1 & 0x0000ff00) >> 8;
					uint8 n500 = (v1 & 0x00ff0000) >> 16;
					uint8 n100 = (v1 & 0xff000000) >> 24;

					
					uint32 amount = ((uint32)n2000) * 2000 + ((uint32)n1000) * 1000 + ((uint32)n500) * 500 + ((uint32)n100) * 100;
					// uint32 balance = 0;

					int userStatus = doTransaction(ID, PIN, amount, byte);

					uint8 b;	// status code 

					if (userStatus == 0) {
						// invalid user
						b = 0x04;
					} else if (userStatus == 1) {
						// valid non admin, enough balance
						b = 0x01;	

						uint32 newV0 = 0;
						uint32 newV1 = v1;

						encrypt(&newV0, &newV1);

						bytes[0] = (newV0 & 0x000000ff);
						bytes[1] = (newV0 & 0x0000ff00) >> 8;
						bytes[2] = (newV0 & 0x00ff0000) >> 16;
						bytes[3] = (newV0 & 0xff000000) >> 24;
						
						bytes[4] = (newV1 & 0x000000ff);
						bytes[5] = (newV1 & 0x0000ff00) >> 8;
						bytes[6] = (newV1 & 0x00ff0000) >> 16;
						bytes[7] = (newV1 & 0xff000000) >> 24;

						// write on channels 10 - 17
						for (int i = 0; i < 8; ++i) {
							fStatus = flWriteChannel(handle, (uint8)(i + 10), 1, &bytes[i], &error);
							CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
						}

					} else if (userStatus == 2) {
						// valid non admin, not enough balance
						b = 0x02;
						
						// write 0 on channels 10 - 17
						for (int i = 0; i < 8; ++i) {
							bytes[i] = 0;
							fStatus = flWriteChannel(handle, (uint8)(i + 10), 1, &bytes[i], &error);
							CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
						}
					} else if (userStatus == 3) {
						// valid admin
						b = 0x03;

						uint32 newV0 = 0;
						uint32 newV1 = v1;
						encrypt(&newV0, &newV1);

						bytes[0] = (newV0 & 0x000000ff);
						bytes[1] = (newV0 & 0x0000ff00) >> 8;
						bytes[2] = (newV0 & 0x00ff0000) >> 16;
						bytes[3] = (newV0 & 0xff000000) >> 24;
						
						bytes[4] = (newV1 & 0x000000ff);
						bytes[5] = (newV1 & 0x0000ff00) >> 8;
						bytes[6] = (newV1 & 0x00ff0000) >> 16;
						bytes[7] = (newV1 & 0xff000000) >> 24;

						// write on channels 10 - 17
						for (int i = 0; i < 8; ++i) {
							fStatus = flWriteChannel(handle, (uint8)(i + 10), 1, &bytes[i], &error);
							CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
						}		
					}

					// write status to channel 9
					fStatus = flWriteChannel(handle, (uint8)9, 1, &b, &error);
					CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);

					printf("%s : %s - %d\n", "communication over", "status", b);

					flSleep(5000);
				}
			}
			
		} else {
			fprintf(stderr, "The FPGALink device at %s is not ready to talk - did you forget --program?\n", vp);
			FAIL(FLP_ARGS, cleanup);
		}
	} else {
		fprintf(stderr, "Action requested but device at %s does not support CommFPGA\n", vp);
		FAIL(FLP_ARGS, cleanup);
	}


cleanup:
	free((void*)line);
	flClose(handle);
	if ( error ) {
		fprintf(stderr, "%s\n", error);
		flFreeError(error);
	}
	return retVal;
}
