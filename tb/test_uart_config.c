#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "uart_config.h"
int main(void) {
    unsigned rates[]={2400,4800,9600,19200}; char cmd[80], value[16]; uint8_t cfg;
    for(unsigned b=0;b<4;b++) for(unsigned d=5;d<=8;d++) for(unsigned p=0;p<3;p++) for(unsigned s=1;s<=2;s++) {
        char parity="NEO"[p];
        snprintf(cmd,sizeof(cmd),"config %u %u%c%u",rates[b],d,parity,s);
        assert(uart_config_parse(cmd,0x43,&cfg)==1);
        assert(cfg==((b<<5)|(d-5)|((s-1)<<2)|(p ? 8:0)|(p==2 ? 16:0)));
        uart_config_format(cfg,value);assert(!strcmp(value,cmd+7));
    }
    assert(uart_config_parse("baud 19200",0x4F,&cfg)==1 && cfg==0x6F);
    assert(uart_config_parse("config",0x43,&cfg)==2 && cfg==0x43);
    const char *bad[]={"config 115200 8N1","config 9600 9N1","config 9600 8X1","config 9600 8N3","config 9600 8N1 extra","baud 9600junk","config 9600","baud 4800 8N1"};
    for(unsigned i=0;i<sizeof(bad)/sizeof(*bad);i++) assert(uart_config_parse(bad[i],0x43,&cfg)==-1);
    assert(uart_config_parse("hello",0x43,&cfg)==0);
    char long_message[128]; memset(long_message,'x',127);long_message[127]=0;
    assert(uart_config_parse(long_message,0x43,&cfg)==0);
    assert(uart_config_parse("configbad",0x43,&cfg)==0);
    assert(uart_config_parse("config 19200 8e2",0x43,&cfg)==1 && cfg==0x6F);
    puts("PASS: all 96 UART formats, baud preserves frame, query, strict rejection of invalid commands");
}
