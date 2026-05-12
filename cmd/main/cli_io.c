#include <moonbit.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void html_parser_cli_fail(const char *message, const char *path) {
  if (path) {
    fprintf(stderr, "%s: %s: %s\n", message, path, strerror(errno));
  } else {
    fprintf(stderr, "%s: %s\n", message, strerror(errno));
  }
  exit(2);
}

static moonbit_bytes_t html_parser_cli_make_bytes(
  const unsigned char *buffer,
  size_t len
) {
  if (len > INT32_MAX) {
    errno = EOVERFLOW;
    html_parser_cli_fail("input is too large", NULL);
  }
  moonbit_bytes_t out = moonbit_make_bytes_raw((int32_t)len);
  if (len > 0) {
    memcpy(out, buffer, len);
  }
  return out;
}

static moonbit_bytes_t html_parser_cli_read_stream(
  FILE *stream,
  const char *label
) {
  size_t capacity = 8192;
  size_t len = 0;
  unsigned char *buffer = (unsigned char *)malloc(capacity);
  if (!buffer) {
    html_parser_cli_fail("failed to allocate input buffer", NULL);
  }

  for (;;) {
    if (len == capacity) {
      if (capacity > SIZE_MAX / 2) {
        free(buffer);
        errno = EOVERFLOW;
        html_parser_cli_fail("input is too large", label);
      }
      size_t next_capacity = capacity * 2;
      unsigned char *next = (unsigned char *)realloc(buffer, next_capacity);
      if (!next) {
        free(buffer);
        html_parser_cli_fail("failed to allocate input buffer", NULL);
      }
      buffer = next;
      capacity = next_capacity;
    }

    size_t read = fread(buffer + len, 1, capacity - len, stream);
    len += read;
    if (read == 0) {
      if (ferror(stream)) {
        free(buffer);
        html_parser_cli_fail("failed to read input", label);
      }
      break;
    }
  }

  moonbit_bytes_t out = html_parser_cli_make_bytes(buffer, len);
  free(buffer);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t html_parser_cli_read_stdin(void) {
  return html_parser_cli_read_stream(stdin, "stdin");
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t html_parser_cli_read_file(moonbit_bytes_t path) {
  FILE *file = fopen((const char *)path, "rb");
  if (!file) {
    html_parser_cli_fail("failed to read input", (const char *)path);
  }
  moonbit_bytes_t out = html_parser_cli_read_stream(file, (const char *)path);
  if (fclose(file) != 0) {
    html_parser_cli_fail("failed to close input", (const char *)path);
  }
  return out;
}

static void html_parser_cli_write_stream(
  FILE *stream,
  moonbit_bytes_t data,
  const char *message
) {
  int32_t len = Moonbit_array_length(data);
  if (len > 0 && fwrite(data, 1, (size_t)len, stream) != (size_t)len) {
    html_parser_cli_fail(message, NULL);
  }
  if (fflush(stream) != 0) {
    html_parser_cli_fail(message, NULL);
  }
}

MOONBIT_FFI_EXPORT
void html_parser_cli_write_stdout(moonbit_bytes_t data) {
  html_parser_cli_write_stream(stdout, data, "failed to write stdout");
}

MOONBIT_FFI_EXPORT
void html_parser_cli_write_stderr(moonbit_bytes_t data) {
  html_parser_cli_write_stream(stderr, data, "failed to write stderr");
}

MOONBIT_FFI_EXPORT
void html_parser_cli_write_file(moonbit_bytes_t path, moonbit_bytes_t data) {
  FILE *file = fopen((const char *)path, "wb");
  if (!file) {
    html_parser_cli_fail("failed to write output", (const char *)path);
  }
  int32_t len = Moonbit_array_length(data);
  if (len > 0 && fwrite(data, 1, (size_t)len, file) != (size_t)len) {
    html_parser_cli_fail("failed to write output", (const char *)path);
  }
  if (fclose(file) != 0) {
    html_parser_cli_fail("failed to close output", (const char *)path);
  }
}

MOONBIT_FFI_EXPORT
void html_parser_cli_exit(int32_t code) {
  exit(code);
}
