#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void stop_handler(int signal_number) {
    (void)signal_number;
    running = 0;
}

int main(int argc, char **argv) {
    const char *config_path = NULL;
    FILE *config_file;
    char line[256];
    int valid = 0;
    int delayed_failure = 0;
    int check_delay = 0;
    int silent_check_failure = 0;
    int check_config = 0;
    int index;

    for (index = 1; index + 1 < argc; index++) {
        if (strcmp(argv[index], "-c") == 0) {
            config_path = argv[index + 1];
            break;
        }
    }
    for (index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--check-config") == 0) check_config = 1;
    }
    if (config_path == NULL || (config_file = fopen(config_path, "r")) == NULL) {
        fprintf(stderr, "missing test config\n");
        return 2;
    }
    while (fgets(line, sizeof(line), config_file) != NULL) {
        if (strcmp(line, "valid=true\n") == 0) valid = 1;
        if (strcmp(line, "delayed_failure=true\n") == 0) delayed_failure = 1;
        if (strcmp(line, "check_delay=true\n") == 0) check_delay = 1;
        if (strcmp(line, "silent_check_failure=true\n") == 0) silent_check_failure = 1;
    }
    fclose(config_file);
    if (!valid) {
        if (check_config && silent_check_failure) return 2;
        fprintf(stderr, "invalid test config\n");
        return 2;
    }
    if (check_config) {
        if (check_delay) sleep(2);
        return 0;
    }
    if (delayed_failure) {
        sleep(2);
        fprintf(stderr, "delayed startup failure\n");
        return 3;
    }

    signal(SIGTERM, stop_handler);
    signal(SIGINT, stop_handler);
    while (running) sleep(1);
    return 0;
}
