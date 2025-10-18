package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// CONFIG
const (
	PollEvery      = 5 * time.Second
	TargetRPSPerVM = 50.0
	MinVMs         = 1
	MaxVMs         = 20
)

func getRPSFromNginx(url string) (float64, error) {
	// expects NGINX stub_status and derives req/s via two samples
	r1, err := http.Get(url)
	if err != nil {
		return 0, err
	}
	b1, _ := ioutil.ReadAll(r1.Body)
	r1.Body.Close()
	c1 := parseActive(b1) // we’ll approximate via active conns delta over time
	time.Sleep(1 * time.Second)
	r2, err := http.Get(url)
	if err != nil {
		return 0, err
	}
	b2, _ := ioutil.ReadAll(r2.Body)
	r2.Body.Close()
	c2 := parseActive(b2)
	if c2 >= c1 {
		return float64(c2 - c1), nil
	}
	return 0, nil
}

func parseActive(b []byte) int {
	// very naive: look for "Active connections: N"
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "Active connections:") {
			f := strings.Fields(line)
			if len(f) >= 3 {
				n, _ := strconv.Atoi(f[2])
				return n
			}
		}
	}
	return 0
}

func setInstances(n int) {
	if n < MinVMs {
		n = MinVMs
	}
	if n > MaxVMs {
		n = MaxVMs
	}
	for i := 1; i <= n; i++ {
		exec.Command("sudo", "systemctl", "start", fmt.Sprintf("microvm@%d", i)).Run()
	}
	for i := n + 1; i <= MaxVMs; i++ {
		exec.Command("sudo", "systemctl", "stop", fmt.Sprintf("microvm@%d", i)).Run()
	}
	log.Printf("scaled to %d instances", n)
}

func main() {
	backendStatus := "http://127.0.0.1:8080/status" // replace with your metric endpoint
	cur := 0
	for {
		rps, err := getRPSFromNginx(backendStatus)
		if err != nil {
			log.Println("metric err:", err)
			time.Sleep(PollEvery)
			continue
		}
		desired := int(math.Ceil(rps / TargetRPSPerVM))
		if desired != cur {
			setInstances(desired)
			cur = desired
		}
		time.Sleep(PollEvery)
	}
}
func getenv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
func getenvI(k string, d int) int {
	if v := os.Getenv(k); v != "" {
		var i int
		fmt.Sscanf(v, "%d", &i)
		return i
	}
	return d
}
func getenvF(k string, d float64) float64 {
	if v := os.Getenv(k); v != "" {
		var f float64
		fmt.Sscanf(v, "%f", &f)
		return f
	}
	return d
}
