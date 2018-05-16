package logger

import (
	"fmt"
	"io"
	"log"
	"os"
	"time"
)

type logWriter struct {
	stream io.Writer
}

func NewLogWriter(stream io.Writer) io.Writer {
	return logWriter{
		stream: stream,
	}
}

func (l logWriter) Write(bytes []byte) (int, error) {
	return fmt.Fprint(l.stream, time.Now().UTC().Format(time.RFC3339)+": "+string(bytes))
}

var Out = log.New(NewLogWriter(os.Stdout), "", 0)
var Err = log.New(NewLogWriter(os.Stderr), "", 0)
