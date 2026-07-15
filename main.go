package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"ok","time":"%s"}`, time.Now().Format(time.RFC3339))
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "Xin chao! Day la ung dung Golang demo cho Bai tap 15 - Multi-stage Build.")
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/healthz", healthHandler)

	log.Printf("Server dang chay tai cong :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
