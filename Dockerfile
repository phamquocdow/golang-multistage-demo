# =========================================================
# STAGE 1 - BUILD
# Dùng image Golang đầy đủ (chứa toolchain, compiler...)
# để tải dependency và biên dịch ra file binary.
# =========================================================
FROM golang:1.22-alpine AS builder

# Cài các gói cần thiết để build (git dùng cho go mod, ca-certificates cho HTTPS)
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go.mod/go.sum trước để tận dụng cache layer khi chỉ code thay đổi
COPY go.mod ./
# Nếu có go.sum thì copy thêm: COPY go.sum ./
RUN go mod download || true

# Copy toàn bộ mã nguồn
COPY . .

# Biên dịch ra binary tĩnh (static binary), tắt CGO để chạy được trên scratch/alpine
# -ldflags "-s -w": loại bỏ debug symbol để giảm dung lượng binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o app main.go

# =========================================================
# STAGE 2 - RUNTIME
# Dùng image siêu nhẹ (alpine) chỉ để CHẠY binary,
# không mang theo toolchain/compiler -> giảm dung lượng đáng kể.
# =========================================================
FROM alpine:3.20 AS runner

# Cài ca-certificates để ứng dụng có thể gọi HTTPS ra ngoài nếu cần
RUN apk add --no-cache ca-certificates && \
    adduser -D -g '' appuser

WORKDIR /app

# Chỉ copy file binary đã build từ stage 1, không mang theo source code hay Go toolchain
COPY --from=builder /app/app .

# Chạy với user không phải root để tăng bảo mật
USER appuser

EXPOSE 8080

ENTRYPOINT ["./app"]

# =========================================================
# Ghi chú: Nếu muốn tối ưu tối đa dung lượng (gần như 0 lớp phụ),
# có thể thay FROM alpine:3.20 bằng FROM scratch, nhưng khi đó
# cần tự copy ca-certificates thủ công vì scratch không có gì cả:
#
# FROM scratch AS runner
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# COPY --from=builder /app/app /app
# ENTRYPOINT ["/app"]
# =========================================================
