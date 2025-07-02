LIBRARY IEEE; -- THU VIEN CHUAN IEEE
USE IEEE.STD_LOGIC_1164.ALL; -- SU DUNG GOI THU VIEN HO TRO CAC PHEP TOAN LOGIC

ENTITY UART IS
GENERIC(
	CLK_FREG : INTEGER	:= 50_000_000;
	BAUDRATE : INTEGER	:= 115_200; -- BIT/S
	OV_RATE	 : INTEGER	:= 16;
	D_WIDTH	 : INTEGER	:= 8;
	PARITY	 : INTEGER	:= 0; -- 0: ko co ktra , 1: co kiem tra 
	EO	 : STD_LOGIC	:='0'); -- 0: chan , 1: le.
PORT(
	CLK	 : IN  STD_LOGIC:='0';
	RST_N	 : IN  STD_LOGIC;
	TX_ENA	 : IN  STD_LOGIC;
	TX_DATA	 : IN  STD_LOGIC_VECTOR(D_WIDTH-1 DOWNTO 0);
	TX	 : OUT STD_LOGIC:='1';
	TX_BUSY	 : OUT STD_LOGIC;
	TX_DONE	 : OUT STD_LOGIC;
	RX	 : IN  STD_LOGIC;
	RX_BUSY	 : OUT STD_LOGIC;
	RX_ERROR : OUT STD_LOGIC;
	RX_DATA	 : BUFFER STD_LOGIC_VECTOR(D_WIDTH-1 DOWNTO 0));
END UART;

ARCHITECTURE UART_ARCH OF UART IS
CONSTANT BAUD_PEAK 	: INTEGER := CLK_FREG/BAUDRATE;
CONSTANT OV_PEAK   	: INTEGER := BAUD_PEAK/OV_RATE;
TYPE TX_MACHINE IS ( IDLE,STAR,TRANSMIT,STOP);
TYPE RX_MACHINE IS ( IDLE,STAR,RECEIVE,STOP);
SIGNAL TX_STATE 	: TX_MACHINE:=IDLE;
SIGNAL RX_STATE 	: RX_MACHINE:=IDLE;
SIGNAL BAUD_PULSE 	: STD_LOGIC:='0';
SIGNAL OV_PULSE	  	: STD_LOGIC:='0';
SIGNAL T,R	  	: STD_LOGIC:='0';
SIGNAL TX_PA		: STD_LOGIC_VECTOR(D_WIDTH DOWNTO 0);
SIGNAL RX_PA		: STD_LOGIC_VECTOR(D_WIDTH DOWNTO 0);
SIGNAL TX_BUFFER	: STD_LOGIC_VECTOR(D_WIDTH + PARITY - 1 DOWNTO 0); -- THANH GHI TAM CHUA DATA TRUYEN O TRANG THAI TRANSMIT ( 8 HOAC 9 BIT)
SIGNAL RX_BUFFER	: STD_LOGIC_VECTOR(D_WIDTH + PARITY - 1 DOWNTO 0); -- THANH GHI TAM CHUA DATA NHAN O TRANG THAI RECEIVE ( 8 HOAC 9 BIT)
BEGIN

PULSE_GEN : PROCESS(CLK,RST_N)
  VARIABLE CNT_BAUD : INTEGER RANGE 0 TO BAUD_PEAK - 1 := 0;
  VARIABLE CNT_OV   : INTEGER RANGE 0 TO OV_PEAK - 1 := 0;
  BEGIN
	IF RST_N = '0' THEN
		BAUD_PULSE <= '0';
		OV_PULSE   <= '0';
		CNT_BAUD   := 0;
		CNT_OV     := 0;	
	ELSIF CLK = '1' AND CLK'EVENT THEN
		IF CNT_BAUD < (BAUD_PEAK -1) THEN
			CNT_BAUD := CNT_BAUD +1;
			BAUD_PULSE <= '0';
		ELSE
			CNT_BAUD := 0;
			BAUD_PULSE <= '1';
			CNT_OV 	 := 0;
		END IF;
		IF CNT_OV < OV_PEAK -1 THEN
			CNT_OV := CNT_OV +1;
			OV_PULSE <= '0';
		ELSE
			CNT_OV := 0;
			OV_PULSE <= '1';
		END IF;
	END IF;
END PROCESS;

TRANSMIT_GEN : PROCESS(CLK,RST_N)
 VARIABLE CNT_TX :  INTEGER RANGE 0 TO PARITY + D_WIDTH := 0;
BEGIN
	IF RST_N = '0' THEN
		CNT_TX := 0;
		TX <= '1';
		TX_BUSY <= '0';
		TX_STATE <= IDLE;
		TX_DONE <= '0';
		T <= '0';
	ELSIF 	CLK = '1' AND CLK'EVENT THEN
	    CASE TX_STATE IS
	      WHEN IDLE =>
		TX <= '1';
		TX_DONE <= '0';
		TX_BUSY <= '0';
		IF TX_ENA = '1' THEN
			IF PARITY = 1 THEN
			   IF T = '0' THEN
			   	TX_PA(0) <= EO;
			 	  FOR i IN 0 TO D_WIDTH - 1 LOOP
					TX_PA(i+1) <= TX_PA(i) XOR TX_DATA(i);
			  	  END LOOP;
			   	TX_BUFFER <= TX_PA(D_WIDTH) & TX_DATA;
			  	T <= '1';
			   END IF;
			ELSE
			   TX_BUFFER <= TX_DATA;
			END IF;
			IF BAUD_PULSE = '1' THEN
			TX_STATE <= STAR;
			ELSE
				TX_STATE <= IDLE;
			END IF;
		ELSE
			TX <= '1';
			TX_STATE <= IDLE;
		END IF;
	      WHEN STAR =>
		TX <= '0';
		TX_BUSY <= '1';
		CNT_TX := 0;
		  IF BAUD_PULSE = '1' THEN
			TX_STATE <= TRANSMIT;
		  ELSE
			TX_STATE <= STAR;
		  END IF;			
	      WHEN TRANSMIT =>
		TX <= TX_BUFFER(0);
		TX_BUSY <= '1';
		  IF BAUD_PULSE = '1' THEN
			CNT_TX := CNT_TX +1;
			TX_BUFFER <= '1'&TX_BUFFER(D_WIDTH + PARITY - 1 DOWNTO 1);
		  END IF;		
		  IF CNT_TX < (D_WIDTH + PARITY) THEN
			TX_STATE <= TRANSMIT;
		  ELSE
			TX_STATE <= STOP;
		  END IF;
	      WHEN STOP => 
		TX <= '1';
		TX_BUSY <= '1';
		CNT_TX := 0;
		T <= '0';
		  IF BAUD_PULSE = '1' THEN
			TX_STATE <= IDLE;
			TX_DONE <= '1';
		  ELSE
			TX_STATE <= STOP;
		  END IF;
	   END CASE;
	END IF;
END PROCESS;

RECEIVE_GEN : PROCESS(CLK, RST_N)
 VARIABLE CNT_RX :  INTEGER RANGE 0 TO PARITY + D_WIDTH +1 := 0;
 VARIABLE CNT_OV :  INTEGER RANGE 0 TO OV_RATE-1+OV_RATE/2  := 0;
BEGIN
	IF RST_N = '0' THEN
		CNT_RX := 0;
		CNT_OV := 0;
		RX_DATA <= X"00";
		RX_STATE <= IDLE;
	ELSIF  CLK'EVENT AND CLK = '1' AND OV_PULSE = '1' THEN
	   CASE RX_STATE IS
		WHEN IDLE =>
			RX_BUSY <= '0';
			IF RX = '0' THEN
		 	   IF CNT_OV < 8 THEN
			    CNT_OV := CNT_OV +1;
			    RX_STATE <= IDLE;
		      	   ELSE
			     RX_BUSY <= '1';
			     CNT_OV := 0;
			     RX_STATE <= STAR;
		     	   END IF;
			ELSE
			     CNT_OV := 0;
			     RX_STATE <= IDLE;
			END IF;
		WHEN STAR =>
			RX_BUSY <= '1';
			CNT_RX := 0;
		 	   IF CNT_OV < OV_RATE-1 THEN
			    CNT_OV := CNT_OV +1;
			    RX_STATE <= STAR;
		      	   ELSE
			     CNT_OV := 0;
			     CNT_RX := CNT_RX +1;
			     RX_BUFFER <= RX& RX_BUFFER(PARITY + D_WIDTH-1 DOWNTO 1);
			     RX_STATE <= RECEIVE;
		     	   END IF;			
		WHEN RECEIVE =>
			RX_BUSY <= '1';
		 	   IF CNT_OV < OV_RATE-1 THEN
			    CNT_OV := CNT_OV +1;
			    RX_STATE <= RECEIVE;
		      	   ELSE
			     CNT_OV := 0;
			     CNT_RX := CNT_RX +1;
			     RX_BUFFER <= RX& RX_BUFFER(PARITY + D_WIDTH-1 DOWNTO 1);
			     IF (CNT_RX < PARITY + D_WIDTH) THEN
			       RX_STATE <= RECEIVE;
			     ELSE 	
			       CNT_RX:= 0;
			       RX_STATE <= STOP;
			       CNT_OV := 0;
			     END IF;
		     	   END IF;	
		WHEN STOP =>
			RX_BUSY <= '1';	
			IF PARITY = 1 THEN
			   RX_DATA <= RX_BUFFER(PARITY+D_WIDTH-2 DOWNTO 1);
			   IF R = '0' THEN
			      RX_PA(0) <= EO;
			      FOR i IN 0 TO D_WIDTH - 1 LOOP
			      	RX_PA(i+1) <= RX_PA(i) XOR RX_DATA(i);
			      END LOOP;
			   	RX_ERROR <= RX_PA(D_WIDTH);
			        R <= '1';
			   END IF;
			ELSIF PARITY = 0 THEN
			     	RX_DATA <= RX_BUFFER;
				RX_ERROR <= '0';
			END IF;
		 	IF CNT_OV < OV_RATE-1+OV_RATE/2 THEN
			    CNT_OV := CNT_OV + 1;
			    RX_STATE <= STOP;
		        ELSE
			     CNT_OV := 0;
			     R <= '0';
			     IF RX = '1' THEN
			     RX_STATE <= IDLE;
			     END IF;
	       	        END IF;	
	       END CASE;
	    END IF;
END PROCESS;

END UART_ARCH;
