package main
import (
  "database/sql"
  "fmt"
  "log"
  "net/http"
  "os"
  _ "modernc.org/sqlite"
)
func main() {
  dbPath := os.Getenv("DB_PATH")
  if dbPath == "" { dbPath = "/app/app.db" }
  log.Printf("DB_PATH=%s", dbPath)
  db, err := sql.Open("sqlite", dbPath)
  if err != nil { log.Fatal(err) }
  defer db.Close()
  _, _ = db.Exec(`CREATE TABLE IF NOT EXISTS hits (id INTEGER PRIMARY KEY, ts DATETIME DEFAULT CURRENT_TIMESTAMP);`)
  http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
    _, err := db.Exec(`INSERT INTO hits DEFAULT VALUES;`)
    if err != nil { http.Error(w, err.Error(), 500); return }
    var c int; _ = db.QueryRow(`SELECT COUNT(*) FROM hits;`).Scan(&c)
    fmt.Fprintf(w, "hello from microVM + sqlite!\nhits=%d\n", c)
  })
  log.Fatal(http.ListenAndServe(":8080", nil))
}