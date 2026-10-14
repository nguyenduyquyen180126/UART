#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#define PC_LINE_BUF_SIZE 128

typedef struct {
    char buf[PC_LINE_BUF_SIZE];
    int  idx;
    bool echo_enabled;
    char last_committed_line[PC_LINE_BUF_SIZE];
    int  commit_count;
    uint8_t last_hex_val;
    int  echo_out_idx;
    char echo_out[1024];
} line_buffer_context_t;

void line_buffer_init(line_buffer_context_t *ctx) {
    memset(ctx, 0, sizeof(*ctx));
    ctx->echo_enabled = true;
}

// Hàm mô phỏng chính xác logic trong [LUỒNG 2] của main.c
void line_buffer_feed_char(line_buffer_context_t *ctx, char pc_char) {
    // 1. Cập nhật mã ASCII lên LED 7 đoạn
    ctx->last_hex_val = (uint8_t)pc_char;

    // 2. Xử lý kết thúc dòng (Enter: \r hoặc \n)
    if (pc_char == '\r' || pc_char == '\n') {
        if (ctx->echo_enabled) {
            strcat(ctx->echo_out, "\r\n");
        }

        if (ctx->idx > 0) {
            ctx->buf[ctx->idx] = '\0';
            strcpy(ctx->last_committed_line, ctx->buf);
            ctx->commit_count++;
            ctx->idx = 0; // Reset cho câu tiếp theo
        }
    }
    // 3. Xử lý phím Backspace (\b hoặc 127)
    else if (pc_char == '\b' || pc_char == 127) {
        if (ctx->idx > 0) {
            ctx->idx--;
            if (ctx->echo_enabled) {
                strcat(ctx->echo_out, "\b \b");
            }
        }
    }
    // 4. Gom ký tự thường vào bộ đệm dòng (chống tràn bộ đệm)
    else if (ctx->idx < PC_LINE_BUF_SIZE - 1) {
        ctx->buf[ctx->idx++] = pc_char;
        if (ctx->echo_enabled) {
            int len = strlen(ctx->echo_out);
            ctx->echo_out[len] = pc_char;
            ctx->echo_out[len + 1] = '\0';
        }
    }
}

void line_buffer_feed_string(line_buffer_context_t *ctx, const char *str) {
    while (*str) {
        line_buffer_feed_char(ctx, *str++);
    }
}

int main(void) {
    printf("====================================================================\n");
    printf("    UNIT TEST: LOGIC BỘ ĐỆM DÒNG ĐỐI XỨNG CỦA FIRMWARE (CÁCH B)    \n");
    printf("====================================================================\n");

    line_buffer_context_t ctx;
    int tests_passed = 0;
    int total_tests = 7;

    // TEST 1: Truyền chuỗi thông thường kết thúc bằng \r
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "Hello DE2-115 from PC\r");
        assert(ctx.commit_count == 1);
        assert(strcmp(ctx.last_committed_line, "Hello DE2-115 from PC") == 0);
        assert(ctx.idx == 0);
        printf("  [PASS] Test 1: Chuoi thong thuong nhan duoc chinh xac ('Hello DE2-115 from PC')\n");
        tests_passed++;
    }

    // TEST 2: Xử lý CRLF (\r\n) không sinh thông điệp rỗng lặp lại
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "Dual CPU APB Bridge\r\n");
        assert(ctx.commit_count == 1); // Chỉ commit đúng 1 lần duy nhất!
        assert(strcmp(ctx.last_committed_line, "Dual CPU APB Bridge") == 0);
        assert(ctx.idx == 0);
        printf("  [PASS] Test 2: Chon loc CRLF (\\r\\n) hoat dong chuan, khong sinh thong diep rong\n");
        tests_passed++;
    }

    // TEST 3: Xử lý phím Backspace sửa lỗi chính tả
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "Helko\b\blo\r");
        assert(ctx.commit_count == 1);
        assert(strcmp(ctx.last_committed_line, "Hello") == 0);
        printf("  [PASS] Test 3: Phim Backspace sua ky tu dung ('Helko' + 2 Backspace + 'lo' -> 'Hello')\n");
        tests_passed++;
    }

    // TEST 4: Chống tràn dưới bộ đệm (Backspace khi chưa gõ ký tự nào)
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "\b\b\b\bValidMessage\r");
        assert(ctx.commit_count == 1);
        assert(strcmp(ctx.last_committed_line, "ValidMessage") == 0);
        assert(ctx.idx == 0);
        printf("  [PASS] Test 4: Chon loc Backspace tren bo dem rong, khong bi underflow\n");
        tests_passed++;
    }

    // TEST 5: Chống tràn bộ đệm khi chuỗi vượt quá 128 bytes
    {
        line_buffer_init(&ctx);
        for (int i = 0; i < 200; i++) {
            line_buffer_feed_char(&ctx, 'A');
        }
        line_buffer_feed_char(&ctx, '\r');
        assert(ctx.commit_count == 1);
        assert(strlen(ctx.last_committed_line) == PC_LINE_BUF_SIZE - 1);
        printf("  [PASS] Test 5: Bao ve tran bo dem (Buffer Overflow Protection: cat tai 127 bytes)\n");
        tests_passed++;
    }

    // TEST 6: Nhấn Enter khi dòng rỗng
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "\r\n\r\n");
        assert(ctx.commit_count == 0); // Không commit thông điệp rác nào
        printf("  [PASS] Test 6: Enter tren dong rong duoc bo qua sach se (Khong spam tin nhan)\n");
        tests_passed++;
    }

    // TEST 7: Truyền liên tiếp nhiều câu
    {
        line_buffer_init(&ctx);
        line_buffer_feed_string(&ctx, "Cau thu nhat\r");
        assert(ctx.commit_count == 1);
        assert(strcmp(ctx.last_committed_line, "Cau thu nhat") == 0);

        line_buffer_feed_string(&ctx, "Cau thu hai\n");
        assert(ctx.commit_count == 2);
        assert(strcmp(ctx.last_committed_line, "Cau thu hai") == 0);
        printf("  [PASS] Test 7: Truyen lien tiep nhieu cau thanh cong ('Cau 1' va 'Cau 2')\n");
        tests_passed++;
    }

    printf("====================================================================\n");
    printf("   KET QUA UNIT TEST: %d / %d PASSED (100%%)\n", tests_passed, total_tests);
    printf("   >>> XAC NHAN: LOGIC BO DEM DONG (CACH B) HOAN TOAN DUNG DAN! <<<\n");
    printf("====================================================================\n");

    return 0;
}
