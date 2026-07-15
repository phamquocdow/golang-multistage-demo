pipeline {
    // Dung "agent any" thay vi "agent none" de tranh loi
    // "No such property: none" do xung dot phien ban plugin Declarative Pipeline.
    // Moi stage ben duoi van tu khai bao lai agent rieng (docker/any) nen khong anh huong logic.
    agent any

    environment {
        // Tên và tag cho image cuối cùng
        IMAGE_NAME = "golang-multistage-demo"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }

    stages {

        /* =========================================================
         * STAGE 1: Checkout mã nguồn
         * ========================================================= */
        stage('Checkout') {
            agent any
            steps {
                checkout scm
            }
        }

        /* =========================================================
         * STAGE 2: Build & test binary Golang bên trong container
         * Dùng agent docker với image Golang chính thức để:
         *  - tải thư viện (go mod download)
         *  - vet/test mã nguồn
         *  - biên dịch ra file thực thi (binary)
         * Mục đích: xác nhận mã nguồn build OK trước khi đóng gói Docker image.
         * ========================================================= */
        stage('Build Go Binary') {
            agent {
                docker {
                    image 'golang:1.22-alpine'
                    // Cache module Go giữa các lần build để tăng tốc.
                    // -e HOME=/tmp: fix loi "mkdir /.cache: permission denied"
                    // vi Jenkins chay container voi user non-root (uid 1000),
                    // nen HOME mac dinh tro ve "/" khong co quyen ghi.
                    args '-v go-mod-cache:/go/pkg/mod -e HOME=/tmp'
                }
            }
            steps {
                sh '''
                    # Fix du phong: du da set HOME=/tmp o args, van tro tuong minc
                    # GOCACHE/GOPATH ve thu muc chac chan co quyen ghi (workspace).
                    export GOCACHE=$WORKSPACE/.gocache
                    export GOPATH=$WORKSPACE/.gopath
                    mkdir -p "$GOCACHE" "$GOPATH"

                    echo "==> Phien ban Go dang su dung:"
                    go version

                    echo "==> Tai thu vien (go mod download)..."
                    go mod download || true

                    echo "==> Kiem tra loi tinh (go vet)..."
                    go vet ./...

                    echo "==> Bien dich ra file thuc thi (binary)..."
                    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
                        go build -ldflags="-s -w" -o app main.go

                    echo "==> Build thanh cong, thong tin file binary:"
                    ls -lh app
                '''
                // Lưu binary lại để dùng ở stage sau nếu cần (optional)
                stash includes: 'app', name: 'go-binary'
            }
        }

        /* =========================================================
         * STAGE 3: Build Docker image theo kỹ thuật multi-stage
         * Stage 1 trong Dockerfile: image golang để build.
         * Stage 2 trong Dockerfile: image alpine/scratch sieu nhe de chay.
         * ========================================================= */
        stage('Build Docker Image (Multi-stage)') {
            agent any
            steps {
                sh """
                    echo "==> Build Docker image bang ky thuat multi-stage..."
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                """
            }
        }

        /* =========================================================
         * STAGE 4: In dung luong image de hoc vien thay ro loi ich
         * cua multi-stage build so voi build 1 stage thong thuong.
         * ========================================================= */
        stage('Report Image Size') {
            agent any
            steps {
                sh """
                    echo "=================================================="
                    echo " DUNG LUONG CAC IMAGE LIEN QUAN"
                    echo "=================================================="

                    echo "--> Image build-stage (golang:1.22-alpine), chi de tham khao:"
                    docker images golang:1.22-alpine --format 'table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}'

                    echo ""
                    echo "--> Image runtime cuoi cung (sau multi-stage, alpine-based):"
                    docker images ${IMAGE_NAME}:${IMAGE_TAG} --format 'table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}'

                    echo ""
                    echo "--> Chi tiet dung luong (byte) bang docker inspect:"
                    SIZE_BYTES=\$(docker inspect -f '{{.Size}}' ${IMAGE_NAME}:${IMAGE_TAG})
                    # Tinh MB voi 2 chu so thap phan bang shell arithmetic thuan tuy,
                    # khong phu thuoc "bc" (co the khong duoc cai san tren agent).
                    SIZE_MB_INT=\$((SIZE_BYTES / 1024 / 1024))
                    SIZE_MB_DEC=\$(( (SIZE_BYTES * 100 / 1024 / 1024) % 100 ))
                    printf "Image ${IMAGE_NAME}:${IMAGE_TAG} = %d.%02d MB (%s bytes)\\n" "\$SIZE_MB_INT" "\$SIZE_MB_DEC" "\$SIZE_BYTES"

                    echo "=================================================="
                    echo " So sanh: neu build 1-stage tu golang:1.22 (~900MB-1GB)"
                    echo " thi image multi-stage nay thuong chi con vai chuc MB."
                    echo "=================================================="
                """
            }
        }

        /* =========================================================
         * STAGE 5 (tuy chon): Chay thu container de kiem tra
         * ========================================================= */
        stage('Smoke Test') {
            agent any
            steps {
                sh """
                    echo "==> Chay thu container de kiem tra healthz..."
                    docker run -d --rm --name ${IMAGE_NAME}-test -p 8081:8080 ${IMAGE_NAME}:${IMAGE_TAG}
                    sleep 3
                    curl -sf http://localhost:8081/healthz || (echo "Healthcheck that bai" && exit 1)
                    docker stop ${IMAGE_NAME}-test
                """
            }
        }
    }

    post {
        always {
            echo "Pipeline ket thuc. Don dep image cu neu can bang 'docker image prune' thu cong."
        }
        success {
            echo "✅ Build va dong goi Docker image multi-stage thanh cong: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "❌ Pipeline that bai, kiem tra log cac stage o tren."
        }
    }
}