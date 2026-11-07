#include <stdint.h>
#include <unistd.h>

// Extern declaration matching uhttp exports
extern void http_start_server(void (*handler)(void *req, char *wire_buf,
                                              int client_fd));
extern void http_send_response(int fd, const char *h_buf, uint64_t h_len,
                               const char *b_buf, uint64_t b_len);

static const char response_headers[] = "HTTP/1.1 200 OK\r\n"
                                       "Server: uhttp-c\r\n"
                                       "Content-Type: text/plain\r\n"
                                       "Content-Length: 13\r\n\r\n";

static const char response_body[] = "Hello from C\n";

void handle_request(void *req, char *wire_buf, int client_fd) {
  http_send_response(client_fd, response_headers, sizeof(response_headers) - 1,
                     response_body, sizeof(response_body) - 1);
}

int main(void) {
  http_start_server(handle_request);
  return 0;
}
