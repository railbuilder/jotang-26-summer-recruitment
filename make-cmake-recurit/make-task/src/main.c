#include <stdio.h>
#include "calculator.h"
#include "logger.h"

int main(void) {
    log_message("Calculator started");
    printf("10 + 5 = %d\n", add(10, 5));
    printf("10 - 5 = %d\n", sub(10, 5));
    return 0;
}
