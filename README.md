# firecracker-lite-stack

Enable N instances:
```bash
sudo install -Dm644 systemd/microvm@.service /etc/systemd/system/microvm@.service
sudo install -Dm644 systemd/microvm.env /etc/microvm/microvm.env
sudo systemctl daemon-reload
sudo systemctl start microvm@1 microvm@2
sudo systemctl enable microvm@1 microvm@2

```
Build simple autoscaler & run:
```bash
cd scaler && go build -o ../bin/scaler ./scaler.go
sudo ./bin/scaler
```

Build and run Prometheus autoscaler:
```bash
cd scaler && go build -o ../bin/scaler-prom ./scaler_prom.go
PROM_URL=http://localhost:9090 \
PROM_EXPR='sum(rate(http_requests_total[1m]))' \
TARGET_PER_VM=60 MIN_VMS=2 MAX_VMS=50 COOLDOWN_SEC=20 \
sudo ./bin/scaler-prom
```
