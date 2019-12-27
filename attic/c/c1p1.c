#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[])
{
    int sum = 0;
    while (1) {
        char line[256];
        if (!fgets(line, 256, stdin)) {
            break;
        }
        int value = atoi(line);
        sum += value;
    }
    printf("%d\n", sum);
    return 0;
}
