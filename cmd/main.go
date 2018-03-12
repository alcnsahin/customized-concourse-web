package main

import (
	"net/http"
	"os"

	"code.cloudfoundry.org/lager"
	"github.com/concourse/web"
	"github.com/concourse/web/proxyhandler"
)

func NewLogger() lager.Logger {
	logger := lager.NewLogger("web")
	logger.RegisterSink(lager.NewReconfigurableSink(lager.NewWriterSink(os.Stdout, lager.DEBUG), lager.DEBUG))
	return logger
}

func main() {

	logger := NewLogger()

	proxyHandler, err := proxyhandler.NewHandler(logger, "https://ci.concourse.ci")
	if err != nil {
		panic(err)
	}

	webHandler, err := web.NewHandler(logger)
	if err != nil {
		panic(err)
	}

	http.Handle("/api/", proxyHandler)
	http.Handle("/auth/", proxyHandler)
	http.Handle("/oauth/", proxyHandler)
	http.Handle("/", webHandler)

	if err = http.ListenAndServe(":8081", nil); err != nil {
		logger.Error("server-error", err)
	}
}
